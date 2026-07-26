## Inspector authoring Resource for one method tag and its value meaning.
class_name MethodTagDefinitionResource
extends Resource

const MethodTagDefinition = preload(
	"res://game/domain/contracts/method_tag_definition.gd"
)
const IdeologyVectorResource = preload(
	"res://game/data/definitions/adventurers/ideology_vector_resource.gd"
)

@export var id: StringName
@export var ideology_vector: IdeologyVectorResource
@export_range(0, 2) var taboo_intensity: int = 0


## Compiles a method tag into an independent runtime definition.
func compile() -> MethodTagDefinition:
	if ideology_vector == null:
		return null
	return MethodTagDefinition.create(id, ideology_vector.compile(), taboo_intensity)
