## Inspector authoring Resource for one structured world effect.
class_name WorldEffectResource
extends Resource

const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

@export var type: StringName
@export var target_id: StringName
@export var amount: int = 0
@export var reason_code: StringName


## Compiles a whitelisted world effect data record.
func compile() -> WorldEffect:
	return WorldEffect.create(type, target_id, amount, reason_code)
