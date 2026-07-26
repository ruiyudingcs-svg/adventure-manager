extends RefCounted

const ContractResolver = preload("res://game/domain/simulation/contract_resolver.gd")
const ContractResolverFixtures = preload("res://tests/fixtures/contract_resolver_fixtures.gd")
const BaselineContractFixtures = preload("res://tests/fixtures/baseline_contract_fixtures.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_golden(
		"north-road complete golden",
		BaselineContractFixtures.create_north_request(),
		[48, 66, 55, 65],
		&"success",
		&"success",
		&"success",
		242,
		9,
		12
	))
	results.append(_golden(
		"binding-towers complete golden",
		BaselineContractFixtures.create_binding_request(),
		[68, 54, 74, 57],
		&"exceptional",
		&"exceptional",
		&"exceptional",
		390,
		13,
		14
	))
	results.append(_golden(
		"corpse-recovery complete golden",
		BaselineContractFixtures.create_corpse_request(),
		[67, 51, 71, 32],
		&"exceptional",
		&"exceptional",
		&"partial",
		234,
		2,
		16
	))
	results.append(_corpse_clause_cap_trace())
	results.append(_determinism())
	return results


func _golden(
	name: String,
	request: Dictionary,
	expected_scores: Array[int],
	expected_initial: StringName,
	expected_operational: StringName,
	expected_final: StringName,
	expected_reward: int,
	expected_relation: int,
	expected_fatigue: int
) -> Dictionary:
	var resolved = ContractResolver.resolve(
		request["contract"],
		request["plan"],
		request["seed"],
		request["guild_base_cohesion"]
	)
	if not resolved.is_success():
		return _result(name, false, "Validation failed: %s" % resolved.errors)
	var scores: Array[int] = []
	for phase_result in resolved.resolution.phase_results:
		scores.append(phase_result.check_result.score)
	var fatigue_matches: bool = true
	var no_heavy_injuries: bool = true
	for member_outcome in resolved.resolution.member_outcomes:
		fatigue_matches = fatigue_matches and member_outcome.fatigue_delta == expected_fatigue
		no_heavy_injuries = no_heavy_injuries and member_outcome.injury_result != &"heavy"
	var reason_ledgers_match: bool = true
	for phase_result in resolved.resolution.phase_results:
		var reason_total: float = 0.0
		for reason in phase_result.reason_entries:
			reason_total += reason.amount
		reason_ledgers_match = reason_ledgers_match \
			and absf(reason_total - phase_result.check_result.score) < 0.000001
	var passed: bool = scores == expected_scores \
		and resolved.resolution.initial_result_tier == expected_initial \
		and resolved.resolution.operational_result_tier == expected_operational \
		and resolved.resolution.result_tier == expected_final \
		and resolved.resolution.reward == expected_reward \
		and resolved.resolution.sponsor_relation_delta == expected_relation \
		and fatigue_matches \
		and (no_heavy_injuries or not name.begins_with("north-road")) \
		and reason_ledgers_match
	return _result(
		name,
		passed,
		"Got scores=%s tiers=%s/%s/%s reward=%d relation=%d fatigue=%s"
		% [
			scores,
			resolved.resolution.initial_result_tier,
			resolved.resolution.operational_result_tier,
			resolved.resolution.result_tier,
			resolved.resolution.reward,
			resolved.resolution.sponsor_relation_delta,
			_fatigues(resolved.resolution.member_outcomes),
		]
	)


func _determinism() -> Dictionary:
	var requests: Array[Dictionary] = [
		BaselineContractFixtures.create_north_request(),
		BaselineContractFixtures.create_binding_request(),
		BaselineContractFixtures.create_corpse_request(),
	]
	for request: Dictionary in requests:
		var baseline = ContractResolver.resolve(
			request["contract"], request["plan"], request["seed"],
			request["guild_base_cohesion"]
		)
		if not baseline.is_success():
			return _result(
				"all full resolutions repeat 100 times",
				false,
				"Baseline failed for %s." % request["contract"].definition_id
			)
		var signature: String = _signature(baseline.resolution)
		for index: int in range(100):
			var repeated = ContractResolver.resolve(
				request["contract"], request["plan"], request["seed"],
				request["guild_base_cohesion"]
			)
			if not repeated.is_success() \
				or _signature(repeated.resolution) != signature:
				return _result(
					"all full resolutions repeat 100 times",
					false,
					"Mismatch for %s at %d." % [
						request["contract"].definition_id, index,
					]
				)
	return _result("all full resolutions repeat 100 times", true, "")


func _corpse_clause_cap_trace() -> Dictionary:
	var request: Dictionary = BaselineContractFixtures.create_corpse_request()
	var resolved = ContractResolver.resolve(
		request["contract"], request["plan"], request["seed"],
		request["guild_base_cohesion"]
	)
	if not resolved.is_success():
		return _result(
			"corpse mandatory clause cap reason chain",
			false,
			"Resolution failed."
		)
	var trace = resolved.trace
	var extraction = resolved.resolution.phase_results[3].check_result
	var unsatisfied_partial_caps: int = 0
	for clause_result in resolved.resolution.clause_results:
		if not clause_result.satisfied and clause_result.result_cap == &"partial":
			unsatisfied_partial_caps += 1
	var passed: bool = extraction.check_id == &"corpse_smuggle_cargo" \
		and extraction.result_tier == &"partial" \
		and trace.check_caps.is_empty() \
		and trace.strictest_check_cap.is_empty() \
		and trace.initial_result_tier == &"exceptional" \
		and resolved.resolution.operational_result_tier == &"exceptional" \
		and unsatisfied_partial_caps == 1 \
		and resolved.resolution.result_tier == &"partial"
	return _result(
		"corpse mandatory clause cap reason chain",
		passed,
		"Expected Partial extraction, no check cap, then one Mandatory Partial cap."
	)


func _signature(resolution) -> String:
	var parts := PackedStringArray([
		String(resolution.initial_result_tier),
		String(resolution.operational_result_tier),
		String(resolution.result_tier),
		str(resolution.reward),
		str(resolution.sponsor_relation_delta),
	])
	for phase_result in resolution.phase_results:
		parts.append("%s:%d:%d" % [
			phase_result.check_result.check_id,
			phase_result.check_result.score,
			phase_result.check_result.seed,
		])
	for member_outcome in resolution.member_outcomes:
		parts.append("%s:%d:%d:%s:%d:%d" % [
			member_outcome.member_id,
			member_outcome.injury_seed,
			member_outcome.injury_roll,
			member_outcome.injury_result,
			member_outcome.fatigue_delta,
			member_outcome.morale_delta,
		])
	for clause_result in resolution.clause_results:
		parts.append("%s:%s" % [clause_result.clause_id, clause_result.satisfied])
	return "|".join(parts)


func _fatigues(outcomes: Array) -> Array[int]:
	var values: Array[int] = []
	for outcome in outcomes:
		values.append(outcome.fatigue_delta)
	return values


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else message}
