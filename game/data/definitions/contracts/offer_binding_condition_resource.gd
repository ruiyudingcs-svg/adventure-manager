## Inspector authoring Resource for one structured offer-binding predicate.
class_name OfferBindingConditionResource
extends Resource

const ContractDefinition = preload("res://game/domain/contracts/contract_definition.gd")

@export var type: StringName
@export var target_id: StringName
@export var int_value: int = 0
@export var tag_value: StringName


## Compiles a structured offer-binding predicate.
func compile() -> ContractDefinition.OfferBindingCondition:
	return ContractDefinition.OfferBindingCondition.new(
		type,
		target_id,
		int_value,
		tag_value
	)
