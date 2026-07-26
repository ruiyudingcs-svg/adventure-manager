## Inspector authoring Resource for one directed starting relationship.
class_name RelationshipDefinitionResource
extends Resource

const RelationshipDefinition = preload(
	"res://game/domain/adventurers/relationship_definition.gd"
)

@export var target_id: StringName
@export_range(-100, 100) var base_value: int = 0


## Compiles the relationship into an independent runtime value.
func compile() -> RelationshipDefinition:
	return RelationshipDefinition.create(target_id, base_value)
