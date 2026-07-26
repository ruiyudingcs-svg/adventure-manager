extends RefCounted

const AttitudeCalculator = preload("res://game/domain/simulation/attitude_calculator.gd")
const AttitudeResult = preload("res://game/domain/contracts/attitude_result.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const ContractResolverFixtures = preload("res://tests/fixtures/contract_resolver_fixtures.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var statuses: bool = AttitudeCalculator.status_for(40) == &"enthusiastic" \
		and AttitudeCalculator.status_for(10) == &"supportive" \
		and AttitudeCalculator.status_for(-9) == &"neutral" \
		and AttitudeCalculator.status_for(-10) == &"reluctant" \
		and AttitudeCalculator.status_for(-40) == &"opposed"
	results.append(_result("attitude status boundaries are exact", statuses))
	var reasons: Array[ReasonEntry] = []
	var attitudes: Array[AttitudeResult] = [
		AttitudeResult.create(&"a", 0, 0, 0, 40, &"enthusiastic", false, reasons),
		AttitudeResult.create(&"b", 0, 0, 0, 10, &"supportive", false, reasons),
		AttitudeResult.create(&"c", 0, 0, 0, -10, &"reluctant", false, reasons),
		AttitudeResult.create(&"d", 0, 0, 0, -40, &"opposed", true, reasons),
	]
	results.append(_result(
		"four-person check attitude preserves quarter precision",
		absf(AttitudeCalculator.check_modifier(attitudes) - (-1.75)) < 0.000001
	))
	var expected = AttitudeCalculator.expected_ideology(
		ContractResolverFixtures.create_north_road_contract()
	)
	results.append(_result(
		"planning ideology uses strongest public success signals only",
		expected.protect_life == 4 \
			and expected.respect_authority == 1 \
			and expected.taboo_tolerance == -1
	))
	return results


func _result(name: String, passed: bool) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else "Boundary mismatch."}
