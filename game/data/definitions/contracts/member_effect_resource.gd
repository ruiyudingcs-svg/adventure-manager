## Inspector authoring Resource for one pending member effect.
class_name MemberEffectResource
extends Resource

const MemberEffect = preload("res://game/domain/contracts/member_effect.gd")

@export var target_id: StringName
@export var type: StringName
@export var amount: int = 0
@export var reason_code: StringName


## Compiles a pending member effect.
func compile() -> MemberEffect:
	return MemberEffect.create(target_id, type, amount, reason_code)
