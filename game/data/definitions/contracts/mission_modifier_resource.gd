## Inspector authoring Resource for one structured check-score modifier.
class_name MissionModifierResource
extends Resource

const MissionModifier = preload("res://game/domain/contracts/mission_modifier.gd")

@export var condition_type: StringName
@export var operand: StringName
@export var threshold: int = 0
@export var amount: int = 0
@export var per_context_point: bool = false
@export var maximum_absolute_amount: int = 0


## Compiles a structured check modifier without executable expressions.
func compile() -> MissionModifier:
	return MissionModifier.create(
		condition_type,
		operand,
		threshold,
		amount,
		per_context_point,
		maximum_absolute_amount
	)
