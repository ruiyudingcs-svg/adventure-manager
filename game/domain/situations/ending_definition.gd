## Static ending candidate and its structured conditions.
class_name EndingDefinition
extends RefCounted

const WorldCondition = preload("res://game/domain/situations/world_condition.gd")

var id: StringName
var display_name_key: StringName
var description_key: StringName
var priority: int
var all_conditions: Array[WorldCondition]
var any_conditions: Array[WorldCondition]


static func create(
	p_id: StringName,
	p_display_name_key: StringName,
	p_description_key: StringName,
	p_priority: int,
	p_all_conditions: Array[WorldCondition],
	p_any_conditions: Array[WorldCondition]
) -> EndingDefinition:
	return EndingDefinition.new(
		p_id,
		p_display_name_key,
		p_description_key,
		p_priority,
		p_all_conditions,
		p_any_conditions
	)


func _init(
	p_id: StringName,
	p_display_name_key: StringName,
	p_description_key: StringName,
	p_priority: int,
	p_all_conditions: Array[WorldCondition],
	p_any_conditions: Array[WorldCondition]
) -> void:
	id = p_id
	display_name_key = p_display_name_key
	description_key = p_description_key
	priority = p_priority
	for condition: WorldCondition in p_all_conditions:
		all_conditions.append(condition.duplicate_value() if condition != null else null)
	for condition: WorldCondition in p_any_conditions:
		any_conditions.append(condition.duplicate_value() if condition != null else null)


func duplicate_value() -> EndingDefinition:
	return EndingDefinition.new(
		id,
		display_name_key,
		description_key,
		priority,
		all_conditions,
		any_conditions
	)
