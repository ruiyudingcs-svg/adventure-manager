extends RefCounted

const MemberOutcomeCalculator = preload("res://game/domain/simulation/member_outcome_calculator.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	results.append(_result(
		"current fatigue risk bands are exact",
		MemberOutcomeCalculator.fatigue_risk_for(29) == 0 \
			and MemberOutcomeCalculator.fatigue_risk_for(30) == 3 \
			and MemberOutcomeCalculator.fatigue_risk_for(60) == 7 \
			and MemberOutcomeCalculator.fatigue_risk_for(80) == 12
	))
	results.append(_result(
		"frontline and support protection bands are exact",
		MemberOutcomeCalculator.protection_band(39) == 0 \
			and MemberOutcomeCalculator.protection_band(40) == 1 \
			and MemberOutcomeCalculator.protection_band(60) == 2 \
			and MemberOutcomeCalculator.protection_band(80) == 3
	))
	results.append(_result(
		"post-mission morale thresholds are exact",
		MemberOutcomeCalculator.morale_delta_for(20) == 3 \
			and MemberOutcomeCalculator.morale_delta_for(5) == 1 \
			and MemberOutcomeCalculator.morale_delta_for(4) == 0 \
			and MemberOutcomeCalculator.morale_delta_for(-5) == -1 \
			and MemberOutcomeCalculator.morale_delta_for(-20) == -3
	))
	return results


func _result(name: String, passed: bool) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else "Member outcome mismatch."}
