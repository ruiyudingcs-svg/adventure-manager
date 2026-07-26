class_name ContractPlanState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

const APPROACHES: Array[StringName] = [&"cautious", &"balanced", &"aggressive"]

var contract_instance_id: StringName
var selected_member_ids: Array[StringName]
var selected_supply_ids: Array[StringName]
var approach: StringName


static func create(
	p_contract_instance_id: StringName,
	p_selected_member_ids: Array[StringName],
	p_selected_supply_ids: Array[StringName],
	p_approach: StringName
) -> ContractPlanState:
	var plan := ContractPlanState.new(
		p_contract_instance_id,
		p_selected_member_ids,
		p_selected_supply_ids,
		p_approach
	)
	if not plan.validate().is_empty():
		return null
	return plan


func _init(
	p_contract_instance_id: StringName,
	p_selected_member_ids: Array[StringName],
	p_selected_supply_ids: Array[StringName],
	p_approach: StringName
) -> void:
	contract_instance_id = p_contract_instance_id
	selected_member_ids.append_array(p_selected_member_ids)
	selected_supply_ids.append_array(p_selected_supply_ids)
	approach = p_approach


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(contract_instance_id):
		errors.append(StableId.validation_error(
			contract_instance_id,
			"ContractPlanState.contract_instance_id"
		))
	if selected_member_ids.size() != 4:
		errors.append("ContractPlanState must contain exactly four member IDs.")
	_append_unique_ids(errors, selected_member_ids, "selected_member_ids")
	if selected_supply_ids.size() > 2:
		errors.append("ContractPlanState may contain at most two supply IDs.")
	_append_unique_ids(errors, selected_supply_ids, "selected_supply_ids")
	if not APPROACHES.has(approach):
		errors.append("Unknown ContractPlanState approach: %s." % approach)
	return errors


func duplicate_state() -> ContractPlanState:
	return ContractPlanState.new(
		contract_instance_id,
		selected_member_ids,
		selected_supply_ids,
		approach
	)


func duplicate_value() -> ContractPlanState:
	return duplicate_state()


func content_signature() -> String:
	return "%s|%s|%s|%s" % [
		contract_instance_id,
		selected_member_ids,
		selected_supply_ids,
		approach,
	]


static func _append_unique_ids(
	errors: PackedStringArray,
	values: Array[StringName],
	field_name: String
) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for value: StringName in values:
		if not StableId.is_valid(value):
			errors.append(StableId.validation_error(
				value,
				"ContractPlanState.%s item" % field_name
			))
		elif seen.has(value):
			errors.append("ContractPlanState.%s contains duplicate %s." % [
				field_name,
				value,
			])
		seen[value] = true
