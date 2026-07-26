extends RefCounted

const ContractResolver = preload("res://game/domain/simulation/contract_resolver.gd")
const ContractResolverFixtures = preload("res://tests/fixtures/contract_resolver_fixtures.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var balanced_request: Dictionary = ContractResolverFixtures.create_baseline_request()
	var cautious_request: Dictionary = ContractResolverFixtures.create_baseline_request()
	cautious_request["plan"].approach = &"cautious"
	var aggressive_request: Dictionary = ContractResolverFixtures.create_baseline_request()
	aggressive_request["plan"].approach = &"aggressive"
	var balanced = _resolve(balanced_request)
	var cautious = _resolve(cautious_request)
	var aggressive = _resolve(aggressive_request)
	results.append(_result(
		"careful checks receive cautious +3 and aggressive -3",
		cautious.trace.phase_results[0].check_result.score \
			== balanced.trace.phase_results[0].check_result.score + 3 \
			and aggressive.trace.phase_results[0].check_result.score \
			== balanced.trace.phase_results[0].check_result.score - 3
	))
	results.append(_result(
		"approach contract context is applied once before the first check",
		cautious.trace.phase_results[0].check_result.context_before.get_value(&"time_pressure") == 1 \
			and aggressive.trace.phase_results[0].check_result.context_before.get_value(&"alert_level") == 1 \
			and aggressive.trace.phase_results[0].check_result.context_before.get_value(&"team_strain") == 1 \
			and aggressive.trace.phase_results[0].check_result.context_before.get_value(&"collateral_pressure") == 1
	))
	return results


func _resolve(request: Dictionary):
	return ContractResolver.resolve(
		request["contract"], request["plan"], request["seed"], request["guild_base_cohesion"]
	)


func _result(name: String, passed: bool) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else "Approach mismatch."}
