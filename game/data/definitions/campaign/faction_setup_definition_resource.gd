## Inspector authoring Resource for one campaign faction starting state.
class_name FactionSetupDefinitionResource
extends Resource

const FactionSetupDefinition = preload(
	"res://game/domain/campaign/faction_setup_definition.gd"
)

@export var faction_id: StringName
@export_range(-100, 100) var initial_relation: int
@export_range(0, 100) var initial_influence: int


func compile() -> FactionSetupDefinition:
	return FactionSetupDefinition.create(
		faction_id,
		initial_relation,
		initial_influence
	)
