extends RefCounted

const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")
const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")
const ContractStageDefinition = preload("res://game/domain/contracts/contract_stage_definition.gd")
const MissionModifier = preload("res://game/domain/contracts/mission_modifier.gd")
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const ResolutionTrace = preload("res://game/domain/contracts/resolution_trace.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const CheckScoreCalculator = preload("res://game/domain/simulation/check_score_calculator.gd")
const ContractResolver = preload("res://game/domain/simulation/contract_resolver.gd")
const ContractResolverFixtures = preload("res://tests/fixtures/contract_resolver_fixtures.gd")
const AdventurerFixtures = preload("res://tests/fixtures/adventurer_fixtures.gd")

const FLOAT_EPSILON: float = 0.000001


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var request: Dictionary = ContractResolverFixtures.create_baseline_request()
	var resolve_result: RefCounted = _resolve_request(request)
	if not resolve_result.is_success():
		results.append(_result(
			"baseline request resolves",
			false,
			"Unexpected validation errors: %s" % resolve_result.errors
		))
		return results

	var trace: ResolutionTrace = resolve_result.trace
	var summary_parts := PackedStringArray()
	for phase_result in trace.phase_results:
		summary_parts.append(
			"%s:%s=%d(%s)"
			% [
				phase_result.phase,
				phase_result.check_result.check_id,
				phase_result.check_result.score,
				phase_result.check_result.result_tier,
			]
		)
	print("Task003 four-phase trace: %s" % " | ".join(summary_parts))

	results.append(_baseline_trace_test(trace))
	results.append(_context_propagation_test(trace))
	results.append(_reason_ledger_test(trace))
	results.append(_deferred_effect_test(trace))
	results.append(_determinism_test(request, trace))
	results.append(_seed_component_isolation_test(request))
	results.append(_check_id_seed_isolation_test(request, trace))
	results.append(_cohesion_pair_rules_test())
	results.append(_cohesion_boundaries_test())
	results.append(_penalty_boundaries_test())
	results.append(_member_penalty_reason_test(request))
	results.append(_rounding_and_tier_boundaries_test(request))
	results.append(_failure_cap_test())
	results.append(_structure_validation_test(request))
	results.append(_task004_policy_enabled_test())
	results.append(_input_purity_test(request))
	return results


func _baseline_trace_test(trace: ResolutionTrace) -> Dictionary:
	var scores: Array[int] = []
	var tiers: Array[StringName] = []
	var phases: Array[StringName] = []
	for phase_result in trace.phase_results:
		phases.append(phase_result.phase)
		scores.append(phase_result.check_result.score)
		tiers.append(phase_result.check_result.result_tier)
	var passed: bool = phases == ContractStageDefinition.PHASES \
		and scores == [48, 66, 55, 65] \
		and tiers == [&"partial", &"success", &"success", &"success"] \
		and absf(trace.contract_score - 71.25) < FLOAT_EPSILON \
		and trace.initial_result_tier == &"success" \
		and trace.check_caps.is_empty()
	return _result(
		"north-road hand trace and weighted tier match",
		passed,
		"Expected 48/66/55/65, contract score 71.25, and initial Success."
	)


func _context_propagation_test(trace: ResolutionTrace) -> Dictionary:
	var first_before: MissionContext = trace.phase_results[0].check_result.context_before
	var main_before: MissionContext = trace.phase_results[1].check_result.context_before
	var special_before: MissionContext = trace.phase_results[2].check_result.context_before
	var extraction_before: MissionContext = trace.phase_results[3].check_result.context_before
	var expected_tags: Array[StringName] = [
		&"route_uncertain",
		&"column_protected",
		&"all_stragglers_recovered",
		&"evacuation_success",
	]
	var expected_methods: Array[StringName] = [
		&"scouting",
		&"rescue",
		&"protection",
		&"nonlethal",
		&"medical",
		&"evacuation",
	]
	var passed: bool = first_before.get_value(&"route_safety") == 0 \
		and main_before.get_value(&"route_safety") == 1 \
		and special_before.get_value(&"protected_civilians") == 2 \
		and special_before.get_value(&"time_pressure") == 1 \
		and extraction_before.get_value(&"protected_civilians") == 5 \
		and extraction_before.get_value(&"time_pressure") == 2 \
		and trace.final_context.outcome_tags == expected_tags \
		and trace.final_context.used_method_tags == expected_methods
	return _result(
		"phase context propagates immediately with stable tags",
		passed,
		"Expected each context_before snapshot to contain only prior phase changes."
	)


func _reason_ledger_test(trace: ResolutionTrace) -> Dictionary:
	var all_sums_match: bool = true
	var context_source_preserved: bool = false
	var fixed_order_starts_correctly: bool = true
	var expected_component_codes_found: bool = false
	for phase_result in trace.phase_results:
		var reasons: Array[ReasonEntry] = phase_result.check_result.reason_entries
		var reason_sum: float = 0.0
		var codes: Array[StringName] = []
		for reason: ReasonEntry in reasons:
			reason_sum += reason.amount
			codes.append(reason.code)
			if reason.code == &"context_modifier" \
				and reason.source_id == phase_result.check_result.check_id \
				and not reason.target_id.is_empty():
				context_source_preserved = true
		if phase_result.phase == &"main_action":
			expected_component_codes_found = codes.has(&"capability_match") \
				and codes.has(&"context_modifier") \
				and codes.has(&"check_difficulty") \
				and codes.has(&"seeded_variance") \
				and codes.has(&"score_rounding")
		all_sums_match = all_sums_match \
			and absf(reason_sum - phase_result.check_result.score) < FLOAT_EPSILON
		fixed_order_starts_correctly = fixed_order_starts_correctly \
			and reasons[0].code == &"capability_match"
	return _result(
		"reason entries are ordered, sourced, and sum to score",
		all_sums_match \
			and context_source_preserved \
			and fixed_order_starts_correctly \
			and expected_component_codes_found,
		"Expected exact score ledgers and source check/context key on context reasons."
	)


func _deferred_effect_test(trace: ResolutionTrace) -> Dictionary:
	var passed: bool = trace.pending_member_effects.size() == 3 \
		and trace.pending_campaign_effects.size() == 7 \
		and trace.final_context.get_value(&"protected_civilians") == 5 \
		and trace.final_context.get_value(&"collateral_pressure") == 0 \
		and trace.ideology_impact.protect_life == 5
	return _result(
		"member and campaign effects remain deferred",
		passed,
		"Expected 3 injury-risk and 7 world effects without applying them to context."
	)


func _determinism_test(
	request: Dictionary,
	baseline_trace: ResolutionTrace
) -> Dictionary:
	var expected_signature: String = _trace_signature(baseline_trace)
	for iteration: int in range(100):
		var repeated: RefCounted = _resolve_request(request)
		if not repeated.is_success() \
			or _trace_signature(repeated.trace) != expected_signature:
			return _result(
				"same request and seed repeat 100 times",
				false,
				"Trace differed at repetition %d." % iteration
			)
	return _result(
		"same request and seed repeat 100 times",
		true,
		""
	)


func _seed_component_isolation_test(request: Dictionary) -> Dictionary:
	var plan: ContractPlan = request["plan"]
	var contract: EffectiveContract = request["contract"]
	var check = contract.stages[0].check
	var first: RefCounted = CheckScoreCalculator.calculate(
		check,
		&"approach",
		plan.members,
		MissionContext.create_default(),
		&"",
		[],
		plan.approach,
		request["guild_base_cohesion"],
		request["seed"]
	)
	var changed: RefCounted = CheckScoreCalculator.calculate(
		check,
		&"approach",
		plan.members,
		MissionContext.create_default(),
		&"",
		[],
		plan.approach,
		request["guild_base_cohesion"],
		int(request["seed"]) + 1
	)
	var passed: bool = first.variance != changed.variance \
		and absf(first.capability_match - changed.capability_match) < FLOAT_EPSILON \
		and first.cohesion_modifier == changed.cohesion_modifier \
		and first.fatigue_penalty == changed.fatigue_penalty \
		and first.injury_penalty == changed.injury_penalty \
		and first.context_modifier == changed.context_modifier
	return _result(
		"changing seed changes only the random score component",
		passed,
		"Expected identical non-random components and a different variance."
	)


func _check_id_seed_isolation_test(
	request: Dictionary,
	baseline_trace: ResolutionTrace
) -> Dictionary:
	var changed_contract: EffectiveContract = (
		request["contract"] as EffectiveContract
	).duplicate_value()
	changed_contract.stages[1].check.id = &"evac_secure_column_renamed"
	var changed_result: RefCounted = ContractResolver.resolve(
		changed_contract,
		request["plan"],
		request["seed"],
		request["guild_base_cohesion"]
	)
	if not changed_result.is_success():
		return _result(
			"renaming one check isolates its derived seed",
			false,
			"Renamed contract unexpectedly failed validation."
		)
	var passed: bool = true
	for index: int in range(4):
		var baseline_seed: int = baseline_trace.phase_results[index].check_result.seed
		var changed_seed: int = changed_result.trace.phase_results[index].check_result.seed
		passed = passed and ((baseline_seed != changed_seed) if index == 1 else (
			baseline_seed == changed_seed
		))
	return _result(
		"renaming one check isolates its derived seed",
		passed,
		"Expected only the renamed check seed to change."
	)


func _cohesion_pair_rules_test() -> Dictionary:
	var no_relationships: Array[AdventurerSnapshot] = ContractResolverFixtures.create_team(
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		{},
		CapabilityBlock.create(50, 50, 50, 50, 50, 50)
	)
	var one_way_values: Dictionary = {
		&"resolver_alpha": {&"resolver_bravo": 30},
	}
	var two_way_values: Dictionary = {
		&"resolver_alpha": {&"resolver_bravo": 30},
		&"resolver_bravo": {&"resolver_alpha": 10},
	}
	var conflict_values: Dictionary = {
		&"resolver_alpha": {&"resolver_bravo": -50},
		&"resolver_bravo": {&"resolver_alpha": 100},
	}
	var zero = CheckScoreCalculator.calculate_cohesion(no_relationships, 50)
	var one_way = CheckScoreCalculator.calculate_cohesion(
		ContractResolverFixtures.create_team(
			[0, 0, 0, 0],
			[0, 0, 0, 0],
			one_way_values,
			CapabilityBlock.create(50, 50, 50, 50, 50, 50)
		),
		50
	)
	var two_way = CheckScoreCalculator.calculate_cohesion(
		ContractResolverFixtures.create_team(
			[0, 0, 0, 0],
			[0, 0, 0, 0],
			two_way_values,
			CapabilityBlock.create(50, 50, 50, 50, 50, 50)
		),
		50
	)
	var conflict = CheckScoreCalculator.calculate_cohesion(
		ContractResolverFixtures.create_team(
			[0, 0, 0, 0],
			[0, 0, 0, 0],
			conflict_values,
			CapabilityBlock.create(50, 50, 50, 50, 50, 50)
		),
		50
	)
	var passed: bool = zero.average_pair_relationship == 0 \
		and one_way.average_pair_relationship == 1 \
		and two_way.average_pair_relationship == 1 \
		and conflict.average_pair_relationship == 1 \
		and conflict.active_conflict_count == 1 \
		and conflict.modifier == -1
	return _result(
		"six-pair cohesion handles none, one-way, two-way, and conflict",
		passed,
		"Expected one-way hostility to count as conflict despite reverse goodwill."
	)


func _cohesion_boundaries_test() -> Dictionary:
	var members: Array[AdventurerSnapshot] = ContractResolverFixtures.create_team(
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		{},
		CapabilityBlock.create(50, 50, 50, 50, 50, 50)
	)
	var passed: bool = CheckScoreCalculator.calculate_cohesion(members, 0).modifier == -10 \
		and CheckScoreCalculator.calculate_cohesion(members, 50).modifier == 0 \
		and CheckScoreCalculator.calculate_cohesion(members, 100).modifier == 10
	var invalid_relationships: Dictionary = {
		&"resolver_alpha": {&"resolver_bravo": 101},
	}
	var invalid_members: Array[AdventurerSnapshot] = ContractResolverFixtures.create_team(
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		invalid_relationships,
		CapabilityBlock.create(50, 50, 50, 50, 50, 50)
	)
	passed = passed \
		and not CheckScoreCalculator.validate_relationships(invalid_members).is_empty()
	return _result(
		"cohesion 0/50/100 boundaries and relationship range validate",
		passed,
		"Expected modifiers -10/0/10 and rejection of relationship 101."
	)


func _penalty_boundaries_test() -> Dictionary:
	var passed: bool = CheckScoreCalculator.fatigue_penalty_for(29) == 0 \
		and CheckScoreCalculator.fatigue_penalty_for(30) == 1 \
		and CheckScoreCalculator.fatigue_penalty_for(59) == 1 \
		and CheckScoreCalculator.fatigue_penalty_for(60) == 3 \
		and CheckScoreCalculator.fatigue_penalty_for(79) == 3 \
		and CheckScoreCalculator.fatigue_penalty_for(80) == 5 \
		and CheckScoreCalculator.injury_penalty_for(0) == 0 \
		and CheckScoreCalculator.injury_penalty_for(1) == 1 \
		and CheckScoreCalculator.injury_penalty_for(20) == 1 \
		and CheckScoreCalculator.injury_penalty_for(21) == 2 \
		and CheckScoreCalculator.injury_penalty_for(100) == 5
	return _result(
		"fatigue and injury penalty boundaries match accepted rules",
		passed,
		"One or more 29/30, 59/60, 79/80 or injury boundaries differed."
	)


func _member_penalty_reason_test(request: Dictionary) -> Dictionary:
	var members: Array[AdventurerSnapshot] = ContractResolverFixtures.create_team(
		[29, 30, 60, 80],
		[0, 1, 21, 100]
	)
	var contract: EffectiveContract = request["contract"]
	var calculation: RefCounted = CheckScoreCalculator.calculate(
		contract.stages[0].check,
		&"approach",
		members,
		MissionContext.create_default(),
		&"",
		[],
		&"balanced",
		request["guild_base_cohesion"],
		request["seed"]
	)
	var fatigue_targets: Array[StringName] = []
	var injury_targets: Array[StringName] = []
	for reason: ReasonEntry in calculation.reason_entries:
		if reason.code == &"fatigue_penalty":
			fatigue_targets.append(reason.target_id)
		elif reason.code == &"injury_penalty":
			injury_targets.append(reason.target_id)
	var expected_targets: Array[StringName] = [
		&"resolver_bravo",
		&"resolver_charlie",
		&"resolver_delta",
	]
	var passed: bool = calculation.fatigue_penalty == 9 \
		and calculation.injury_penalty == 8 \
		and fatigue_targets == expected_targets \
		and injury_targets == expected_targets
	return _result(
		"member penalties emit one stable-ID-sorted reason each",
		passed,
		"Expected fatigue 9/injury 8/sorted targets; got %d/%d, %s, %s."
		% [
			calculation.fatigue_penalty,
			calculation.injury_penalty,
			fatigue_targets,
			injury_targets,
		]
	)


func _rounding_and_tier_boundaries_test(request: Dictionary) -> Dictionary:
	var standard_bundles: Array[Dictionary] = AdventurerFixtures.create_standard_team_bundles()
	var standard_team: Array[AdventurerSnapshot] = AdventurerFixtures.snapshots_from_bundles(
		standard_bundles
	)
	var contract: EffectiveContract = request["contract"]
	var calculation: RefCounted = CheckScoreCalculator.calculate(
		contract.stages[0].check,
		&"approach",
		standard_team,
		MissionContext.create_default(),
		&"",
		[],
		&"balanced",
		50,
		request["seed"]
	)
	var rounding_reason_found: bool = false
	for reason: ReasonEntry in calculation.reason_entries:
		if reason.code == &"score_rounding" \
			and reason.visibility == ReasonEntry.VISIBILITY_DEBUG:
			rounding_reason_found = true
	var high_check = contract.stages[0].check.duplicate_value()
	high_check.difficulty = -50
	var high_team: Array[AdventurerSnapshot] = ContractResolverFixtures.create_team(
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		{},
		CapabilityBlock.create(100, 100, 100, 100, 100, 100)
	)
	var high_calculation: RefCounted = CheckScoreCalculator.calculate(
		high_check,
		&"approach",
		high_team,
		MissionContext.create_default(),
		&"",
		[],
		&"balanced",
		45,
		request["seed"]
	)
	var passed: bool = absf(fmod(absf(calculation.raw_score), 1.0) - 0.5) < FLOAT_EPSILON \
		and calculation.score == roundi(calculation.raw_score) \
		and rounding_reason_found \
		and high_calculation.score > 100 \
		and roundi(19.5) == 20 \
		and roundi(-19.5) == -20 \
		and ContractResolver.tier_for_score(9) == &"severe" \
		and ContractResolver.tier_for_score(10) == &"failure" \
		and ContractResolver.tier_for_score(29) == &"failure" \
		and ContractResolver.tier_for_score(30) == &"partial" \
		and ContractResolver.tier_for_score(49) == &"partial" \
		and ContractResolver.tier_for_score(50) == &"success" \
		and ContractResolver.tier_for_score(69) == &"success" \
		and ContractResolver.tier_for_score(70) == &"exceptional"
	return _result(
		"raw .5 rounds away once and all five tier edges hold",
		passed,
		"Expected debug rounding reason and 9/10, 29/30, 49/50, 69/70 edges."
	)


func _failure_cap_test() -> Dictionary:
	var low_team: Array[AdventurerSnapshot] = ContractResolverFixtures.create_team(
		[79, 79, 79, 79],
		[79, 79, 79, 79],
		{},
		CapabilityBlock.create(0, 0, 0, 0, 0, 0)
	)
	var supplies: Array[SupplyDefinition] = []
	var low_plan: ContractPlan = ContractPlan.create(
		low_team,
		supplies,
		&"balanced"
	)
	var low_result: RefCounted = ContractResolver.resolve(
		ContractResolverFixtures.create_north_road_contract(),
		low_plan,
		ContractResolverFixtures.BASELINE_SEED,
		50
	)
	var passed: bool = low_result.is_success() \
		and low_result.trace.check_caps.size() == 4 \
		and low_result.trace.strictest_check_cap == &"failure" \
		and low_result.trace.initial_result_tier == &"severe" \
		and low_result.trace.phase_results[0].check_result.score < 0
	return _result(
		"failure and severe checks collect the strictest cap",
		passed,
		"Expected four caps with Failure stricter than Partial."
	)


func _structure_validation_test(request: Dictionary) -> Dictionary:
	var invalid_contract: EffectiveContract = (
		request["contract"] as EffectiveContract
	).duplicate_value()
	invalid_contract.stages[0].phase = &"main_action"
	invalid_contract.stages[1].id = invalid_contract.stages[0].id
	invalid_contract.stages[1].check.id = invalid_contract.stages[0].check.id
	invalid_contract.stages[0].check.result_weight = 0.0
	invalid_contract.stages[2].check.check_type = &"unsupported_type"
	invalid_contract.stages[3].check.context_modifiers.append(
		MissionModifier.create(&"executable_string", &"intel", 1, 2)
	)
	var invalid_result: RefCounted = ContractResolver.resolve(
		invalid_contract,
		request["plan"],
		request["seed"],
		request["guild_base_cohesion"]
	)
	return _result(
		"invalid phase, IDs, weights, type, and modifier are rejected atomically",
		not invalid_result.is_success() \
			and invalid_result.trace == null \
			and invalid_result.errors.size() >= 6,
		"Expected multiple structural validation errors and no partial trace."
	)


func _task004_policy_enabled_test() -> Dictionary:
	var cautious_request: Dictionary = ContractResolverFixtures.create_baseline_request()
	(cautious_request["plan"] as ContractPlan).approach = &"cautious"
	var cautious: RefCounted = _resolve_request(cautious_request)

	var invalid_request: Dictionary = ContractResolverFixtures.create_baseline_request()
	(invalid_request["plan"] as ContractPlan).approach = &"unsupported"
	var invalid: RefCounted = _resolve_request(invalid_request)
	var passed: bool = cautious.is_success() \
		and cautious.resolution != null \
		and cautious.resolution.clause_results.size() == 3 \
		and not invalid.is_success() \
		and invalid.resolution == null
	return _result(
		"Task004 approaches and typed clauses are enabled",
		passed,
		"Expected cautious resolution to succeed and an unknown approach to fail."
	)


func _input_purity_test(request: Dictionary) -> Dictionary:
	var contract: EffectiveContract = request["contract"]
	var plan: ContractPlan = request["plan"]
	var first_difficulty: int = contract.stages[0].check.difficulty
	var first_delta: int = contract.stages[0].check.outcome_table.get_outcome(
		&"partial"
	).context_deltas[0]["amount"]
	var first_member: AdventurerSnapshot = plan.members[0]
	var member_fatigue: int = first_member.fatigue
	var member_relationships: Dictionary[StringName, int] = first_member.relationship_values
	var resolved: RefCounted = _resolve_request(request)
	if not resolved.is_success():
		return _result("resolver leaves every input unchanged", false, "Resolve failed.")
	var first_before: MissionContext = resolved.trace.phase_results[0].check_result.context_before
	var passed: bool = contract.stages[0].check.difficulty == first_difficulty \
		and contract.stages[0].check.outcome_table.get_outcome(
			&"partial"
		).context_deltas[0]["amount"] == first_delta \
		and plan.members[0].fatigue == member_fatigue \
		and plan.members[0].relationship_values == member_relationships \
		and first_before.get_value(&"route_safety") == 0 \
		and first_before != resolved.trace.final_context
	return _result(
		"resolver leaves every input unchanged and snapshots do not alias",
		passed,
		"Expected definitions, plan, snapshots, outcomes, and context_before unchanged."
	)


func _resolve_request(request: Dictionary) -> RefCounted:
	return ContractResolver.resolve(
		request["contract"],
		request["plan"],
		request["seed"],
		request["guild_base_cohesion"]
	)


func _trace_signature(trace: ResolutionTrace) -> String:
	var parts := PackedStringArray()
	for phase_result in trace.phase_results:
		var check_result = phase_result.check_result
		parts.append("%s:%s:%d:%s:%d:%.6f" % [
			phase_result.phase,
			check_result.check_id,
			check_result.score,
			check_result.result_tier,
			check_result.seed,
			check_result.raw_score,
		])
		for reason: ReasonEntry in check_result.reason_entries:
			parts.append("%s:%s:%.6f" % [
				reason.code,
				reason.target_id,
				reason.amount,
			])
	for key: StringName in MissionContext.CONTEXT_KEYS:
		parts.append("%s=%d" % [key, trace.final_context.get_value(key)])
	parts.append("score=%.6f" % trace.contract_score)
	parts.append("tier=%s" % trace.initial_result_tier)
	parts.append("tags=%s" % [trace.outcome_tags])
	return "|".join(parts)


func _result(test_name: String, passed: bool, failure_message: String) -> Dictionary:
	return {
		"name": test_name,
		"passed": passed,
		"message": "" if passed else failure_message,
	}
