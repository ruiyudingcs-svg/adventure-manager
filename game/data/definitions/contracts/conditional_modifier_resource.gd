## Inspector authoring Resource for one structured fixed modifier.
class_name ConditionalModifierResource
extends Resource

const ConditionalModifier = preload(
	"res://game/domain/contracts/conditional_modifier.gd"
)

@export var target_type: StringName
@export var match_tag: StringName
@export var amount: int = 0
@export var reason_code: StringName


## Compiles a structured modifier; no field is interpreted as executable code.
func compile() -> ConditionalModifier:
	return ConditionalModifier.create(target_type, match_tag, amount, reason_code)
