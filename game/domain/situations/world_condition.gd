## Structured, non-executable predicate used by static world definitions.
class_name WorldCondition
extends RefCounted

var type: StringName
var target_id: StringName
var int_value: int


static func create(
	p_type: StringName,
	p_target_id: StringName,
	p_int_value: int = 0
) -> WorldCondition:
	return WorldCondition.new(p_type, p_target_id, p_int_value)


func _init(p_type: StringName, p_target_id: StringName, p_int_value: int) -> void:
	type = p_type
	target_id = p_target_id
	int_value = p_int_value


func duplicate_value() -> WorldCondition:
	return WorldCondition.new(type, target_id, int_value)
