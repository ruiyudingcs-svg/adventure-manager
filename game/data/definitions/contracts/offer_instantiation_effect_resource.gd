## Inspector authoring Resource for one bounded offer overlay.
class_name OfferInstantiationEffectResource
extends Resource

const ContractDefinition = preload("res://game/domain/contracts/contract_definition.gd")

@export var type: StringName
@export var target_id: StringName
@export var amount: int = 0


## Compiles a bounded offer overlay effect.
func compile() -> ContractDefinition.OfferInstantiationEffect:
	return ContractDefinition.OfferInstantiationEffect.new(type, target_id, amount)
