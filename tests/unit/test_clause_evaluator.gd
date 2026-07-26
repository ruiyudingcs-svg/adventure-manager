extends RefCounted

const ContractResolver = preload("res://game/domain/simulation/contract_resolver.gd")
const ClauseEvaluator = preload("res://game/domain/simulation/clause_evaluator.gd")
const ContractEffect = preload("res://game/domain/contracts/contract_effect.gd")
const ContractResolverFixtures = preload("res://tests/fixtures/contract_resolver_fixtures.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var request: Dictionary = ContractResolverFixtures.create_baseline_request()
	var resolved = ContractResolver.resolve(
		request["contract"], request["plan"], request["seed"], request["guild_base_cohesion"]
	)
	var ids: Array[StringName] = []
	for clause_result in resolved.resolution.clause_results:
		ids.append(clause_result.clause_id)
	var results: Array[Dictionary] = []
	results.append(_result(
		"clauses evaluate once in priority then stable-ID order",
		ids == [&"evac_no_wounded_abandoned", &"evac_collateral_limit", &"evac_no_heavy_injury"]
	))
	var invalid = request["contract"].duplicate_value()
	invalid.clauses[2].failure_effects.append(
		ContractEffect.create(&"modify_reward_percent", -10)
	)
	results.append(_result(
		"bonus clauses reject failure consequences",
		not ClauseEvaluator.validate_definitions(invalid).is_empty()
	))
	var effect_reason_keys_valid := true
	for clause_result in resolved.resolution.clause_results:
		for reason in clause_result.reason_entries:
			if reason.category == &"clause_effect":
				effect_reason_keys_valid = effect_reason_keys_valid \
					and String(reason.localization_key).begins_with(
						"contract_effect."
					)
	results.append(_result(
		"clause effects use fixed localization keys",
		effect_reason_keys_valid
	))
	return results


func _result(name: String, passed: bool) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else "Clause mismatch."}
