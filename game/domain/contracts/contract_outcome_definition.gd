class_name ContractOutcomeDefinition
extends RefCounted

const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

var reward_multiplier: float
var fatigue_multiplier: float
var injury_risk_modifier: int
var sponsor_relation_delta: int
var campaign_effects: Array[WorldEffect]
var outcome_tags: Array[StringName]


static func create(
	p_reward_multiplier: float,
	p_fatigue_multiplier: float,
	p_injury_risk_modifier: int,
	p_sponsor_relation_delta: int,
	p_campaign_effects: Array[WorldEffect],
	p_outcome_tags: Array[StringName]
) -> ContractOutcomeDefinition:
	return ContractOutcomeDefinition.new(
		p_reward_multiplier,
		p_fatigue_multiplier,
		p_injury_risk_modifier,
		p_sponsor_relation_delta,
		p_campaign_effects,
		p_outcome_tags
	)


func _init(
	p_reward_multiplier: float,
	p_fatigue_multiplier: float,
	p_injury_risk_modifier: int,
	p_sponsor_relation_delta: int,
	p_campaign_effects: Array[WorldEffect],
	p_outcome_tags: Array[StringName]
) -> void:
	reward_multiplier = p_reward_multiplier
	fatigue_multiplier = p_fatigue_multiplier
	injury_risk_modifier = p_injury_risk_modifier
	sponsor_relation_delta = p_sponsor_relation_delta
	for effect: WorldEffect in p_campaign_effects:
		campaign_effects.append(effect.duplicate_value())
	outcome_tags.append_array(p_outcome_tags)


func duplicate_value() -> ContractOutcomeDefinition:
	return ContractOutcomeDefinition.new(
		reward_multiplier,
		fatigue_multiplier,
		injury_risk_modifier,
		sponsor_relation_delta,
		campaign_effects,
		outcome_tags
	)
