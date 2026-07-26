class_name ContractPlanValidator
extends RefCounted

const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const AttitudeResult = preload("res://game/domain/contracts/attitude_result.gd")
const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")
const ConditionalModifier = preload("res://game/domain/contracts/conditional_modifier.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const AttitudeCalculator = preload("res://game/domain/simulation/attitude_calculator.gd")

const APPROACHES: Array[StringName] = [&"cautious", &"balanced", &"aggressive"]
const SUPPLY_TAGS: Array[StringName] = [
	&"scouting",
	&"medical",
	&"protection",
	&"arcane_binding",
	&"rations",
]


class ValidationResult extends RefCounted:
	var errors: PackedStringArray
	var attitude_results: Array[AttitudeResult]
	var reason_entries: Array[ReasonEntry]


static func validate(
	contract: EffectiveContract,
	plan: ContractPlan
) -> ValidationResult:
	var result := ValidationResult.new()
	if contract == null:
		result.errors.append("EffectiveContract is required.")
	if plan == null:
		result.errors.append("ContractPlan is required.")
	if contract == null or plan == null:
		return result

	result.errors.append_array(AttitudeCalculator.validate_content(contract))
	if plan.members.size() != 4:
		result.errors.append("ContractPlan must contain exactly four members.")
	var member_ids: Dictionary[StringName, bool] = {}
	for member in plan.members:
		if member == null:
			result.errors.append("ContractPlan member cannot be null.")
			continue
		if member.id.is_empty():
			result.errors.append("ContractPlan member ID cannot be empty.")
		elif member_ids.has(member.id):
			result.errors.append("ContractPlan member IDs must be unique.")
		member_ids[member.id] = true
		if not member.is_available:
			result.errors.append("Member %s is unavailable." % member.id)
		if member.injury_severity >= 80:
			result.errors.append("Member %s has a dispatch-blocking heavy injury." % member.id)
		if member.wage <= 0:
			result.errors.append("Member %s wage must be greater than zero." % member.id)
		result.errors.append_array(AttitudeCalculator.validate_member_traits(member))

	if not APPROACHES.has(plan.approach):
		result.errors.append("Unknown ContractPlan approach: %s." % plan.approach)
	result.errors.append_array(_validate_supplies(contract, plan))

	if result.errors.is_empty():
		for member in plan.members:
			var attitude: AttitudeResult = AttitudeCalculator.calculate_planning(contract, member)
			result.attitude_results.append(attitude)
			for reason: ReasonEntry in attitude.reason_entries:
				result.reason_entries.append(reason.duplicate_value())
			if attitude.status == &"opposed" and member.morale <= 20:
				result.errors.append(
					"Member %s refuses assignment while opposed with morale %d."
					% [member.id, member.morale]
				)
	return result


static func _validate_supplies(
	contract: EffectiveContract,
	plan: ContractPlan
) -> PackedStringArray:
	var errors := PackedStringArray()
	if plan.selected_supplies.size() > 2:
		errors.append("ContractPlan may select at most two supplies.")
	var ids: Dictionary[StringName, bool] = {}
	for supply: SupplyDefinition in plan.selected_supplies:
		if supply == null:
			errors.append("Selected SupplyDefinition cannot be null.")
			continue
		if supply.id.is_empty():
			errors.append("Selected supply ID cannot be empty.")
		elif ids.has(supply.id):
			errors.append("Selected supply IDs must be unique.")
		ids[supply.id] = true
		var fixed_tags: Array[StringName] = []
		for tag: StringName in supply.tags:
			if SUPPLY_TAGS.has(tag):
				fixed_tags.append(tag)
			else:
				errors.append("Unknown supply tag %s on %s." % [tag, supply.id])
		if fixed_tags.size() != 1:
			errors.append("Supply %s must have exactly one fixed V0.1 supply tag." % supply.id)
			continue
		var supply_tag: StringName = fixed_tags[0]
		if not contract.allowed_supply_tags.has(supply_tag):
			errors.append(
				"Supply %s tag %s is not allowed by this contract."
				% [supply.id, supply_tag]
			)
		errors.append_array(_validate_fixed_modifiers(supply, supply_tag))
	return errors


static func _validate_fixed_modifiers(
	supply: SupplyDefinition,
	supply_tag: StringName
) -> PackedStringArray:
	var errors := PackedStringArray()
	var expected: Array[Dictionary] = []
	match supply_tag:
		&"scouting":
			expected = [{"target": &"check", "match": &"navigation", "amount": 5}]
		&"medical":
			expected = [
				{"target": &"check", "match": &"rescue", "amount": 5},
				{"target": &"injury_any", "match": &"", "amount": -5},
				{"target": &"injury_heavy", "match": &"", "amount": -2},
			]
		&"protection":
			expected = [
				{"target": &"check", "match": &"protection", "amount": 5},
				{"target": &"injury_any", "match": &"", "amount": -3},
				{"target": &"injury_heavy", "match": &"", "amount": -4},
			]
		&"rations":
			expected = [{"target": &"fatigue", "match": &"", "amount": -4}]
	if supply.modifiers.size() != expected.size():
		errors.append("Supply %s has an invalid modifier count." % supply.id)
		return errors
	for index: int in range(expected.size()):
		var modifier: ConditionalModifier = supply.modifiers[index]
		var fixed: Dictionary = expected[index]
		if modifier == null \
			or modifier.target_type != fixed["target"] \
			or modifier.match_tag != fixed["match"] \
			or modifier.amount != fixed["amount"]:
			errors.append("Supply %s modifier %d does not match the fixed V0.1 rule." % [
				supply.id,
				index,
			])
	return errors
