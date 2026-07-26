extends RefCounted

const ContractPlanValidator = preload("res://game/domain/simulation/contract_plan_validator.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")
const ContractResolverFixtures = preload("res://tests/fixtures/contract_resolver_fixtures.gd")
const BaselineContractFixtures = preload("res://tests/fixtures/baseline_contract_fixtures.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var request: Dictionary = BaselineContractFixtures.create_north_request()
	var valid = ContractPlanValidator.validate(request["contract"], request["plan"])
	results.append(_result("valid four-member typed plan passes", valid.errors.is_empty()))

	var duplicate_plan: ContractPlan = (request["plan"] as ContractPlan).duplicate_value()
	duplicate_plan.members[1] = duplicate_plan.members[0].duplicate_value()
	results.append(_result(
		"duplicate member IDs are rejected",
		not ContractPlanValidator.validate(request["contract"], duplicate_plan).errors.is_empty()
	))
	var short_members = ContractResolverFixtures.create_team()
	short_members.pop_back()
	var no_supplies: Array[SupplyDefinition] = []
	var short_plan := ContractPlan.create(short_members, no_supplies, &"balanced")
	results.append(_result(
		"plans require exactly four members",
		not ContractPlanValidator.validate(request["contract"], short_plan).errors.is_empty()
	))
	var unknown: ContractPlan = (request["plan"] as ContractPlan).duplicate_value()
	unknown.approach = &"reckless"
	results.append(_result(
		"approach whitelist rejects unknown values",
		not ContractPlanValidator.validate(request["contract"], unknown).errors.is_empty()
	))
	var too_many: ContractPlan = (request["plan"] as ContractPlan).duplicate_value()
	too_many.selected_supplies.append(too_many.selected_supplies[0].duplicate_value())
	results.append(_result(
		"supply count and duplicate IDs are rejected",
		not ContractPlanValidator.validate(request["contract"], too_many).errors.is_empty()
	))
	return results


func _result(name: String, passed: bool) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else "Validation mismatch."}
