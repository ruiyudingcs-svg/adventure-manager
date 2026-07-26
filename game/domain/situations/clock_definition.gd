## Static bounded world-progress clock definition.
class_name ClockDefinition
extends RefCounted

var id: StringName
var display_name_key: StringName
var min_value: int
var max_value: int
var initial_value: int
var visibility: StringName


static func create(
	p_id: StringName,
	p_display_name_key: StringName,
	p_min_value: int,
	p_max_value: int,
	p_initial_value: int,
	p_visibility: StringName
) -> ClockDefinition:
	return ClockDefinition.new(
		p_id,
		p_display_name_key,
		p_min_value,
		p_max_value,
		p_initial_value,
		p_visibility
	)


func _init(
	p_id: StringName,
	p_display_name_key: StringName,
	p_min_value: int,
	p_max_value: int,
	p_initial_value: int,
	p_visibility: StringName
) -> void:
	id = p_id
	display_name_key = p_display_name_key
	min_value = p_min_value
	max_value = p_max_value
	initial_value = p_initial_value
	visibility = p_visibility


func duplicate_value() -> ClockDefinition:
	return ClockDefinition.new(
		id,
		display_name_key,
		min_value,
		max_value,
		initial_value,
		visibility
	)
