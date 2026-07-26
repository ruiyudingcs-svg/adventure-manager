class_name MethodTagDefinition
extends RefCounted

const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")

var id: StringName
var ideology_vector: IdeologyVector
var taboo_intensity: int


static func create(
	p_id: StringName,
	p_ideology_vector: IdeologyVector,
	p_taboo_intensity: int
) -> MethodTagDefinition:
	return MethodTagDefinition.new(p_id, p_ideology_vector, p_taboo_intensity)


func _init(
	p_id: StringName,
	p_ideology_vector: IdeologyVector,
	p_taboo_intensity: int
) -> void:
	id = p_id
	ideology_vector = p_ideology_vector.duplicate_value()
	taboo_intensity = p_taboo_intensity


func duplicate_value() -> MethodTagDefinition:
	return MethodTagDefinition.new(id, ideology_vector, taboo_intensity)
