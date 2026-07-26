## Inspector authoring Resource for one deterministic offer overlay rule.
class_name OfferInstantiationRuleResource
extends Resource

const ContractDefinition = preload("res://game/domain/contracts/contract_definition.gd")
const OfferBindingConditionResource = preload(
	"res://game/data/definitions/contracts/offer_binding_condition_resource.gd"
)
const OfferInstantiationEffectResource = preload(
	"res://game/data/definitions/contracts/offer_instantiation_effect_resource.gd"
)
@export var id: StringName
@export var all_conditions: Array[OfferBindingConditionResource] = []
@export var effects: Array[OfferInstantiationEffectResource] = []
@export var reason_code: StringName


## Deep-compiles a deterministic offer-instantiation rule.
func compile() -> ContractDefinition.OfferInstantiationRule:
	var conditions: Array[ContractDefinition.OfferBindingCondition] = []
	var compiled_effects: Array[ContractDefinition.OfferInstantiationEffect] = []
	for condition: OfferBindingConditionResource in all_conditions:
		if condition == null:
			return null
		conditions.append(condition.compile())
	for effect: OfferInstantiationEffectResource in effects:
		if effect == null:
			return null
		compiled_effects.append(effect.compile())
	return ContractDefinition.OfferInstantiationRule.new(
		id,
		conditions,
		compiled_effects,
		reason_code
	)
