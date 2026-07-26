## Inspector authoring Resource for one faction template.
class_name FactionDefinitionResource
extends Resource

const FactionDefinition = preload("res://game/domain/factions/faction_definition.gd")
const FactionAgendaWeightResource = preload(
	"res://game/data/definitions/factions/faction_agenda_weight_resource.gd"
)
const IdeologyVectorResource = preload(
	"res://game/data/definitions/adventurers/ideology_vector_resource.gd"
)
const FactionAgendaWeight = preload(
	"res://game/domain/factions/faction_agenda_weight.gd"
)

@export var id: StringName
@export var display_name_key: StringName
@export var description_key: StringName
@export var agenda_weights: Array[FactionAgendaWeightResource] = []
@export var preferred_ideology: IdeologyVectorResource
@export var weekly_action_ids: Array[StringName] = []


## Deep-compiles faction policy while Task 010 still owns action definitions.
func compile() -> FactionDefinition:
	if preferred_ideology == null:
		return null
	var compiled_weights: Array[FactionAgendaWeight] = []
	for agenda_weight: FactionAgendaWeightResource in agenda_weights:
		if agenda_weight == null:
			return null
		compiled_weights.append(agenda_weight.compile())
	return FactionDefinition.create(
		id,
		display_name_key,
		description_key,
		compiled_weights,
		preferred_ideology.compile(),
		weekly_action_ids
	)
