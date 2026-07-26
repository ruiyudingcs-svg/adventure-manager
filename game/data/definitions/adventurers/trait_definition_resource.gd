## Inspector authoring Resource for one Gate B trait.
class_name TraitDefinitionResource
extends Resource

const TraitDefinition = preload("res://game/domain/adventurers/trait_definition.gd")
const ConditionalModifierResource = preload(
	"res://game/data/definitions/contracts/conditional_modifier_resource.gd"
)
const ConditionalModifier = preload(
	"res://game/domain/contracts/conditional_modifier.gd"
)

@export var id: StringName
@export var display_name_key: StringName
@export var description_key: StringName
@export var rule_tags: Array[StringName] = []
@export var modifiers: Array[ConditionalModifierResource] = []


## Compiles an independent trait graph after CatalogValidator accepts the resource.
func compile() -> TraitDefinition:
	var compiled_modifiers: Array[ConditionalModifier] = []
	for modifier: ConditionalModifierResource in modifiers:
		if modifier == null:
			return null
		compiled_modifiers.append(modifier.compile())
	return TraitDefinition.create(
		id,
		display_name_key,
		description_key,
		rule_tags,
		compiled_modifiers
	)
