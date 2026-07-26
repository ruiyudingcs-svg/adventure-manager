## Explicit, ordered root of all content Resources accepted by DataCatalog.
class_name ContentManifest
extends Resource

const AdventurerDefinitionResource = preload(
	"res://game/data/definitions/adventurers/adventurer_definition_resource.gd"
)
const TraitDefinitionResource = preload(
	"res://game/data/definitions/adventurers/trait_definition_resource.gd"
)
const MethodTagDefinitionResource = preload(
	"res://game/data/definitions/contracts/method_tag_definition_resource.gd"
)
const SupplyDefinitionResource = preload(
	"res://game/data/definitions/contracts/supply_definition_resource.gd"
)
const ContractClauseDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_clause_definition_resource.gd"
)
const FactionDefinitionResource = preload(
	"res://game/data/definitions/factions/faction_definition_resource.gd"
)
const FactionActionDefinitionResource = preload(
	"res://game/data/definitions/factions/faction_action_definition_resource.gd"
)
const ContractDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_definition_resource.gd"
)
const SituationDefinitionResource = preload(
	"res://game/data/definitions/situations/situation_definition_resource.gd"
)
const ClockDefinitionResource = preload(
	"res://game/data/definitions/situations/clock_definition_resource.gd"
)
const SituationPhaseDefinitionResource = preload(
	"res://game/data/definitions/situations/situation_phase_definition_resource.gd"
)
const WorldProblemDefinitionResource = preload(
	"res://game/data/definitions/situations/world_problem_definition_resource.gd"
)
const EndingDefinitionResource = preload(
	"res://game/data/definitions/situations/ending_definition_resource.gd"
)
const CampaignSetupDefinitionResource = preload(
	"res://game/data/definitions/campaign/campaign_setup_definition_resource.gd"
)

# The explicit arrays are the only content discovery mechanism (Accepted Gate C).
@export var adventurer_definitions: Array[AdventurerDefinitionResource] = []
@export var trait_definitions: Array[TraitDefinitionResource] = []
@export var method_tag_definitions: Array[MethodTagDefinitionResource] = []
@export var supply_definitions: Array[SupplyDefinitionResource] = []
@export var contract_clause_definitions: Array[ContractClauseDefinitionResource] = []
@export var faction_definitions: Array[FactionDefinitionResource] = []
@export var faction_action_definitions: Array[FactionActionDefinitionResource] = []
@export var contract_definitions: Array[ContractDefinitionResource] = []
@export var situation_definitions: Array[SituationDefinitionResource] = []
@export var clock_definitions: Array[ClockDefinitionResource] = []
@export var phase_definitions: Array[SituationPhaseDefinitionResource] = []
@export var problem_definitions: Array[WorldProblemDefinitionResource] = []
@export var ending_definitions: Array[EndingDefinitionResource] = []
@export var campaign_setup_definitions: Array[CampaignSetupDefinitionResource] = []
