## Inspector authoring Resource for one adventurer template.
class_name AdventurerDefinitionResource
extends Resource

const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const CapabilityBlockResource = preload(
	"res://game/data/definitions/adventurers/capability_block_resource.gd"
)
const IdeologyVectorResource = preload(
	"res://game/data/definitions/adventurers/ideology_vector_resource.gd"
)
const RelationshipDefinitionResource = preload(
	"res://game/data/definitions/adventurers/relationship_definition_resource.gd"
)
const RelationshipDefinition = preload(
	"res://game/domain/adventurers/relationship_definition.gd"
)

@export var id: StringName
@export var display_name: String
@export var class_id: StringName
@export var portrait: Texture2D
@export var base_capabilities: CapabilityBlockResource
@export var traits: Array[StringName] = []
@export var values: IdeologyVectorResource
@export var starting_relationships: Array[RelationshipDefinitionResource] = []
@export var wage: int = 1
@export var bio_key: StringName


## Compiles the complete authoring graph and never shares its mutable arrays.
func compile() -> AdventurerDefinition:
	if base_capabilities == null or values == null:
		return null
	var relationships: Array[RelationshipDefinition] = []
	for relationship: RelationshipDefinitionResource in starting_relationships:
		if relationship == null:
			return null
		var compiled: RelationshipDefinition = relationship.compile()
		if compiled == null:
			return null
		relationships.append(compiled)
	return AdventurerDefinition.create(
		id,
		display_name,
		class_id,
		base_capabilities.compile(),
		values.compile(),
		traits,
		relationships,
		wage,
		bio_key,
		portrait
	)
