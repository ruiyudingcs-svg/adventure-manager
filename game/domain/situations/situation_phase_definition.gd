## Static identity and ordering metadata for one situation phase.
class_name SituationPhaseDefinition
extends RefCounted

var id: StringName
var display_name_key: StringName
var description_key: StringName
var sort_order: int
var is_terminal: bool


static func create(
	p_id: StringName,
	p_display_name_key: StringName,
	p_description_key: StringName,
	p_sort_order: int,
	p_is_terminal: bool
) -> SituationPhaseDefinition:
	return SituationPhaseDefinition.new(
		p_id,
		p_display_name_key,
		p_description_key,
		p_sort_order,
		p_is_terminal
	)


func _init(
	p_id: StringName,
	p_display_name_key: StringName,
	p_description_key: StringName,
	p_sort_order: int,
	p_is_terminal: bool
) -> void:
	id = p_id
	display_name_key = p_display_name_key
	description_key = p_description_key
	sort_order = p_sort_order
	is_terminal = p_is_terminal


func duplicate_value() -> SituationPhaseDefinition:
	return SituationPhaseDefinition.new(
		id,
		display_name_key,
		description_key,
		sort_order,
		is_terminal
	)
