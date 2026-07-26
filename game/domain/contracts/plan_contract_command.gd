class_name PlanContractCommand
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

const APPROACHES: Array[StringName] = [&"cautious", &"balanced", &"aggressive"]

var contract_offer_id: StringName
var selected_member_ids: Array[StringName]
var selected_supply_ids: Array[StringName]
var approach: StringName


static func create(
	p_contract_offer_id: StringName,
	p_selected_member_ids: Array[StringName],
	p_selected_supply_ids: Array[StringName],
	p_approach: StringName
) -> PlanContractCommand:
	return PlanContractCommand.new(
		p_contract_offer_id,
		p_selected_member_ids,
		p_selected_supply_ids,
		p_approach
	)


func _init(
	p_contract_offer_id: StringName,
	p_selected_member_ids: Array[StringName],
	p_selected_supply_ids: Array[StringName],
	p_approach: StringName
) -> void:
	contract_offer_id = p_contract_offer_id
	selected_member_ids.append_array(p_selected_member_ids)
	selected_supply_ids.append_array(p_selected_supply_ids)
	approach = p_approach


## Commands remain constructible when invalid so the application service can
## report all input issues without mutating CampaignState.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(contract_offer_id):
		errors.append(StableId.validation_error(
			contract_offer_id,
			"PlanContractCommand.contract_offer_id"
		))
	if selected_member_ids.size() != 4:
		errors.append("PlanContractCommand must contain exactly four member IDs.")
	_append_unique_ids(errors, selected_member_ids, "selected_member_ids")
	if selected_supply_ids.size() > 2:
		errors.append("PlanContractCommand may contain at most two supply IDs.")
	_append_unique_ids(errors, selected_supply_ids, "selected_supply_ids")
	if not APPROACHES.has(approach):
		errors.append("Unknown PlanContractCommand approach: %s." % approach)
	return errors


func duplicate_value() -> PlanContractCommand:
	return PlanContractCommand.new(
		contract_offer_id,
		selected_member_ids,
		selected_supply_ids,
		approach
	)


func content_signature() -> String:
	return "%s|%s|%s|%s" % [
		contract_offer_id,
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
				"PlanContractCommand.%s item" % field_name
			))
		elif seen.has(value):
			errors.append("PlanContractCommand.%s contains duplicate %s." % [
				field_name,
				value,
			])
		seen[value] = true
