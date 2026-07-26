## Inspector authoring Resource for one fixed V0.1 supply.
class_name SupplyDefinitionResource
extends Resource

const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")
const ConditionalModifierResource = preload(
	"res://game/data/definitions/contracts/conditional_modifier_resource.gd"
)
const ConditionalModifier = preload(
	"res://game/domain/contracts/conditional_modifier.gd"
)

@export var id: StringName
@export var display_name_key: StringName
@export var cost: int = 0
@export var tags: Array[StringName] = []
@export var modifiers: Array[ConditionalModifierResource] = []
@export var consumed_on_use: bool = true


## Compiles supply effects into a new graph so source Resources remain authoring-only.
func compile() -> SupplyDefinition:
	var compiled_modifiers: Array[ConditionalModifier] = []
	for modifier: ConditionalModifierResource in modifiers:
		if modifier == null:
			return null
		compiled_modifiers.append(modifier.compile())
	return SupplyDefinition.create(
		id,
		display_name_key,
		cost,
		tags,
		compiled_modifiers,
		consumed_on_use
	)
