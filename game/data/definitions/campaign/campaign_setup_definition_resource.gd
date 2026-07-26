## Inspector authoring Resource for one explicit new-campaign setup.
class_name CampaignSetupDefinitionResource
extends Resource

const CampaignSetupDefinition = preload(
	"res://game/domain/campaign/campaign_setup_definition.gd"
)
const FactionSetupDefinitionResource = preload(
	"res://game/data/definitions/campaign/faction_setup_definition_resource.gd"
)
const FactionSetupDefinition = preload(
	"res://game/domain/campaign/faction_setup_definition.gd"
)

@export var id: StringName
@export var situation_definition_id: StringName
@export var adventurer_ids: Array[StringName] = []
@export var faction_setups: Array[FactionSetupDefinitionResource] = []
@export var initial_active_problem_ids: Array[StringName] = []
@export var initial_gold: int
@export var initial_reputation: int
@export var initial_base_cohesion: int
@export var weekly_maintenance: int


## Deep-compiles setup subresources so callers cannot mutate authoring data.
func compile() -> CampaignSetupDefinition:
	var compiled_factions: Array[FactionSetupDefinition] = []
	for setup: FactionSetupDefinitionResource in faction_setups:
		if setup == null:
			return null
		var compiled := setup.compile()
		if compiled == null:
			return null
		compiled_factions.append(compiled)
	return CampaignSetupDefinition.create(
		id,
		situation_definition_id,
		adventurer_ids,
		compiled_factions,
		initial_active_problem_ids,
		initial_gold,
		initial_reputation,
		initial_base_cohesion,
		weekly_maintenance
	)
