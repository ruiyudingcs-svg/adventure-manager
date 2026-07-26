## Static faction identity and agenda policy.
class_name FactionDefinition
extends RefCounted

const FactionAgendaWeight = preload("res://game/domain/factions/faction_agenda_weight.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")

var id: StringName
var display_name_key: StringName
var description_key: StringName
var agenda_weights: Array[FactionAgendaWeight]
var preferred_ideology: IdeologyVector
## Task 010 owns the typed action definition; Task 005 preserves references as stable IDs.
var weekly_action_ids: Array[StringName]


static func create(
	p_id: StringName,
	p_display_name_key: StringName,
	p_description_key: StringName,
	p_agenda_weights: Array[FactionAgendaWeight],
	p_preferred_ideology: IdeologyVector,
	p_weekly_action_ids: Array[StringName]
) -> FactionDefinition:
	return FactionDefinition.new(
		p_id,
		p_display_name_key,
		p_description_key,
		p_agenda_weights,
		p_preferred_ideology,
		p_weekly_action_ids
	)


func _init(
	p_id: StringName,
	p_display_name_key: StringName,
	p_description_key: StringName,
	p_agenda_weights: Array[FactionAgendaWeight],
	p_preferred_ideology: IdeologyVector,
	p_weekly_action_ids: Array[StringName]
) -> void:
	id = p_id
	display_name_key = p_display_name_key
	description_key = p_description_key
	for agenda_weight: FactionAgendaWeight in p_agenda_weights:
		agenda_weights.append(
			agenda_weight.duplicate_value() if agenda_weight != null else null
		)
	preferred_ideology = (
		p_preferred_ideology.duplicate_value()
		if p_preferred_ideology != null else null
	)
	weekly_action_ids.append_array(p_weekly_action_ids)


func duplicate_value() -> FactionDefinition:
	return FactionDefinition.new(
		id,
		display_name_key,
		description_key,
		agenda_weights,
		preferred_ideology,
		weekly_action_ids
	)
