class_name SupplyDefinition
extends RefCounted

const ConditionalModifier = preload("res://game/domain/contracts/conditional_modifier.gd")

var id: StringName
var display_name_key: StringName
var cost: int
var tags: Array[StringName]
var modifiers: Array[ConditionalModifier]
var consumed_on_use: bool


static func create(
	p_id: StringName,
	p_display_name_key: StringName,
	p_cost: int,
	p_tags: Array[StringName],
	p_modifiers: Array[ConditionalModifier],
	p_consumed_on_use: bool = true
) -> SupplyDefinition:
	return SupplyDefinition.new(
		p_id,
		p_display_name_key,
		p_cost,
		p_tags,
		p_modifiers,
		p_consumed_on_use
	)


func _init(
	p_id: StringName,
	p_display_name_key: StringName,
	p_cost: int,
	p_tags: Array[StringName],
	p_modifiers: Array[ConditionalModifier],
	p_consumed_on_use: bool
) -> void:
	id = p_id
	display_name_key = p_display_name_key
	cost = p_cost
	tags.append_array(p_tags)
	for modifier: ConditionalModifier in p_modifiers:
		modifiers.append(modifier.duplicate_value() if modifier != null else null)
	consumed_on_use = p_consumed_on_use


func duplicate_value() -> SupplyDefinition:
	return SupplyDefinition.new(
		id,
		display_name_key,
		cost,
		tags,
		modifiers,
		consumed_on_use
	)
