class_name CheckOutcomeDefinition
extends RefCounted

const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const MemberEffect = preload("res://game/domain/contracts/member_effect.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")

var context_deltas: Array[Dictionary]
var member_effects: Array[MemberEffect]
var campaign_effects: Array[WorldEffect]
var ideology_impact: IdeologyVector
var outcome_tags: Array[StringName]


static func create(
	p_context_deltas: Array[Dictionary],
	p_member_effects: Array[MemberEffect],
	p_campaign_effects: Array[WorldEffect],
	p_ideology_impact: IdeologyVector,
	p_outcome_tags: Array[StringName]
) -> CheckOutcomeDefinition:
	return CheckOutcomeDefinition.new(
		p_context_deltas,
		p_member_effects,
		p_campaign_effects,
		p_ideology_impact,
		p_outcome_tags
	)


func _init(
	p_context_deltas: Array[Dictionary],
	p_member_effects: Array[MemberEffect],
	p_campaign_effects: Array[WorldEffect],
	p_ideology_impact: IdeologyVector,
	p_outcome_tags: Array[StringName]
) -> void:
	for delta: Dictionary in p_context_deltas:
		context_deltas.append(delta.duplicate(true))
	for effect: MemberEffect in p_member_effects:
		member_effects.append(effect.duplicate_value())
	for effect: WorldEffect in p_campaign_effects:
		campaign_effects.append(effect.duplicate_value())
	ideology_impact = p_ideology_impact.duplicate_value()
	outcome_tags.append_array(p_outcome_tags)


func duplicate_value() -> CheckOutcomeDefinition:
	return CheckOutcomeDefinition.new(
		context_deltas,
		member_effects,
		campaign_effects,
		ideology_impact,
		outcome_tags
	)
