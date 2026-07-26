## Inspector authoring Resource for one final contract outcome tier.
class_name ContractOutcomeDefinitionResource
extends Resource

const ContractOutcomeDefinition = preload(
	"res://game/domain/contracts/contract_outcome_definition.gd"
)
const WorldEffectResource = preload(
	"res://game/data/definitions/contracts/world_effect_resource.gd"
)
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

@export var reward_multiplier: float = 1.0
@export var fatigue_multiplier: float = 1.0
@export var injury_risk_modifier: int = 0
@export_range(-20, 20) var sponsor_relation_delta: int = 0
@export var campaign_effects: Array[WorldEffectResource] = []
@export var outcome_tags: Array[StringName] = []


## Deep-compiles one final contract tier.
func compile() -> ContractOutcomeDefinition:
	var effects: Array[WorldEffect] = []
	for effect: WorldEffectResource in campaign_effects:
		if effect == null:
			return null
		effects.append(effect.compile())
	return ContractOutcomeDefinition.create(
		reward_multiplier,
		fatigue_multiplier,
		injury_risk_modifier,
		sponsor_relation_delta,
		effects,
		outcome_tags
	)
