class_name PlanningDraft
extends RefCounted

const PlanContractCommand = preload(
	"res://game/domain/contracts/plan_contract_command.gd"
)

var offer_instance_id: StringName
var selected_member_ids: Array[StringName]
var selected_supply_ids: Array[StringName]
var approach: StringName = &"balanced"
var content_signature: String:
	get:
		return _content_signature()


func select_offer(value: StringName) -> void:
	if offer_instance_id == value:
		return
	offer_instance_id = value
	# A different effective contract can invalidate every preparation choice.
	selected_member_ids.clear()
	selected_supply_ids.clear()
	approach = &"balanced"


func toggle_member(member_id: StringName) -> bool:
	if selected_member_ids.has(member_id):
		selected_member_ids.erase(member_id)
		return true
	if selected_member_ids.size() >= 4:
		return false
	selected_member_ids.append(member_id)
	return true


func toggle_supply(supply_id: StringName) -> bool:
	if selected_supply_ids.has(supply_id):
		selected_supply_ids.erase(supply_id)
		return true
	if selected_supply_ids.size() >= 2:
		return false
	selected_supply_ids.append(supply_id)
	return true


func set_approach(value: StringName) -> bool:
	if not PlanContractCommand.APPROACHES.has(value):
		return false
	approach = value
	return true


func reset() -> void:
	offer_instance_id = &""
	selected_member_ids.clear()
	selected_supply_ids.clear()
	approach = &"balanced"


func to_command() -> PlanContractCommand:
	return PlanContractCommand.create(
		offer_instance_id,
		selected_member_ids,
		selected_supply_ids,
		approach
	)


func _content_signature() -> String:
	var members: Array[StringName] = selected_member_ids.duplicate()
	var supplies: Array[StringName] = selected_supply_ids.duplicate()
	members.sort()
	supplies.sort()
	# Gate F deliberately excludes UI click order and the locked resolution seed.
	return "%s|%s|%s" % [approach, members, supplies]
