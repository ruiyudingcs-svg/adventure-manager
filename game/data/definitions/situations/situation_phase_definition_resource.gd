## Inspector authoring Resource for one ordered situation phase.
class_name SituationPhaseDefinitionResource
extends Resource

const SituationPhaseDefinition = preload(
	"res://game/domain/situations/situation_phase_definition.gd"
)

@export var id: StringName
@export var display_name_key: StringName
@export var description_key: StringName
@export var sort_order: int = 0
@export var is_terminal: bool = false


## Compiles one stable situation phase.
func compile() -> SituationPhaseDefinition:
	return SituationPhaseDefinition.create(
		id,
		display_name_key,
		description_key,
		sort_order,
		is_terminal
	)
