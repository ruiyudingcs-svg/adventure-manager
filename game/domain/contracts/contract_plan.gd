class_name ContractPlan
extends RefCounted

const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")

var members: Array[AdventurerSnapshot]
var selected_supplies: Array[SupplyDefinition]
var approach: StringName


static func create(
	p_members: Array[AdventurerSnapshot],
	p_selected_supplies: Array[SupplyDefinition],
	p_approach: StringName
) -> ContractPlan:
	return ContractPlan.new(
		p_members,
		p_selected_supplies,
		p_approach
	)


func _init(
	p_members: Array[AdventurerSnapshot],
	p_selected_supplies: Array[SupplyDefinition],
	p_approach: StringName
) -> void:
	for member: AdventurerSnapshot in p_members:
		members.append(member.duplicate_value() if member != null else null)
	for supply: SupplyDefinition in p_selected_supplies:
		selected_supplies.append(supply.duplicate_value() if supply != null else null)
	approach = p_approach


func duplicate_value() -> ContractPlan:
	return ContractPlan.new(members, selected_supplies, approach)
