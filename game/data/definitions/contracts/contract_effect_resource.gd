## Inspector authoring Resource for one whitelisted clause effect.
class_name ContractEffectResource
extends Resource

const ContractEffect = preload("res://game/domain/contracts/contract_effect.gd")

@export var type: StringName
@export var amount: int = 0
@export var tag_value: StringName
@export var reason_code: StringName


## Compiles a whitelisted clause effect.
func compile() -> ContractEffect:
	return ContractEffect.create(type, amount, tag_value, reason_code)
