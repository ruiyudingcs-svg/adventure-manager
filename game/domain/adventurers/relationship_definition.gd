class_name RelationshipDefinition
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

var target_id: StringName:
	get:
		return _target_id
	set(_value):
		assert(false, "RelationshipDefinition.target_id is read-only.")
var base_value: int:
	get:
		return _base_value
	set(_value):
		assert(false, "RelationshipDefinition.base_value is read-only.")

var _target_id: StringName
var _base_value: int


static func create(p_target_id: StringName, p_base_value: int) -> RelationshipDefinition:
	if not StableId.is_valid(p_target_id):
		return null
	return RelationshipDefinition.new(p_target_id, p_base_value)


func _init(p_target_id: StringName, p_base_value: int) -> void:
	assert(StableId.is_valid(p_target_id))
	_target_id = p_target_id
	_base_value = p_base_value


func duplicate_value() -> RelationshipDefinition:
	return RelationshipDefinition.new(_target_id, _base_value)
