## Read-only starting values for one faction in a campaign setup.
class_name FactionSetupDefinition
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

var faction_id: StringName
var initial_relation: int
var initial_influence: int


static func create(
	p_faction_id: StringName,
	p_initial_relation: int,
	p_initial_influence: int
) -> FactionSetupDefinition:
	if not validate_values(
		p_faction_id,
		p_initial_relation,
		p_initial_influence
	).is_empty():
		return null
	return FactionSetupDefinition.new(
		p_faction_id,
		p_initial_relation,
		p_initial_influence
	)


func _init(
	p_faction_id: StringName,
	p_initial_relation: int,
	p_initial_influence: int
) -> void:
	faction_id = p_faction_id
	initial_relation = p_initial_relation
	initial_influence = p_initial_influence


static func validate_values(
	p_faction_id: StringName,
	p_initial_relation: int,
	p_initial_influence: int
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(p_faction_id):
		errors.append(StableId.validation_error(
			p_faction_id,
			"FactionSetupDefinition.faction_id"
		))
	if p_initial_relation < -100 or p_initial_relation > 100:
		errors.append("Faction setup relation must be between -100 and 100.")
	if p_initial_influence < 0 or p_initial_influence > 100:
		errors.append("Faction setup influence must be between 0 and 100.")
	return errors


func duplicate_value() -> FactionSetupDefinition:
	return FactionSetupDefinition.new(
		faction_id,
		initial_relation,
		initial_influence
	)
