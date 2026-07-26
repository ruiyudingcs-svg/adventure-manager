class_name FactionState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

var definition_id: StringName
var relation: int
var influence: int


static func create(
	p_definition_id: StringName,
	p_relation: int,
	p_influence: int
) -> FactionState:
	if not validate_values(p_definition_id, p_relation, p_influence).is_empty():
		return null
	return FactionState.new(p_definition_id, p_relation, p_influence)


func _init(
	p_definition_id: StringName,
	p_relation: int,
	p_influence: int
) -> void:
	definition_id = p_definition_id
	relation = p_relation
	influence = p_influence


static func validate_values(
	p_definition_id: StringName,
	p_relation: int,
	p_influence: int
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(p_definition_id):
		errors.append(StableId.validation_error(p_definition_id, "FactionState.definition_id"))
	if p_relation < -100 or p_relation > 100:
		errors.append("FactionState.relation must be between -100 and 100.")
	if p_influence < 0 or p_influence > 100:
		errors.append("FactionState.influence must be between 0 and 100.")
	return errors


func validate() -> PackedStringArray:
	return validate_values(definition_id, relation, influence)


func duplicate_state() -> FactionState:
	return FactionState.new(definition_id, relation, influence)
