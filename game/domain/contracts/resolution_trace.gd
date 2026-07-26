class_name ResolutionTrace
extends RefCounted

const PhaseResult = preload("res://game/domain/contracts/phase_result.gd")
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const MemberEffect = preload("res://game/domain/contracts/member_effect.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")

var phase_results: Array[PhaseResult]
var final_context: MissionContext
var contract_score: float
var initial_result_tier: StringName
var check_caps: Array[StringName]
var strictest_check_cap: StringName
var pending_member_effects: Array[MemberEffect]
var pending_campaign_effects: Array[WorldEffect]
var ideology_impact: IdeologyVector
var outcome_tags: Array[StringName]
var used_method_tags: Array[StringName]


static func create(
	p_phase_results: Array[PhaseResult],
	p_final_context: MissionContext,
	p_contract_score: float,
	p_initial_result_tier: StringName,
	p_check_caps: Array[StringName],
	p_strictest_check_cap: StringName,
	p_pending_member_effects: Array[MemberEffect],
	p_pending_campaign_effects: Array[WorldEffect],
	p_ideology_impact: IdeologyVector,
	p_outcome_tags: Array[StringName],
	p_used_method_tags: Array[StringName]
) -> ResolutionTrace:
	return ResolutionTrace.new(
		p_phase_results,
		p_final_context,
		p_contract_score,
		p_initial_result_tier,
		p_check_caps,
		p_strictest_check_cap,
		p_pending_member_effects,
		p_pending_campaign_effects,
		p_ideology_impact,
		p_outcome_tags,
		p_used_method_tags
	)


func _init(
	p_phase_results: Array[PhaseResult],
	p_final_context: MissionContext,
	p_contract_score: float,
	p_initial_result_tier: StringName,
	p_check_caps: Array[StringName],
	p_strictest_check_cap: StringName,
	p_pending_member_effects: Array[MemberEffect],
	p_pending_campaign_effects: Array[WorldEffect],
	p_ideology_impact: IdeologyVector,
	p_outcome_tags: Array[StringName],
	p_used_method_tags: Array[StringName]
) -> void:
	for phase_result: PhaseResult in p_phase_results:
		phase_results.append(phase_result.duplicate_value())
	final_context = p_final_context.duplicate_value()
	contract_score = p_contract_score
	initial_result_tier = p_initial_result_tier
	check_caps.append_array(p_check_caps)
	strictest_check_cap = p_strictest_check_cap
	for effect: MemberEffect in p_pending_member_effects:
		pending_member_effects.append(effect.duplicate_value())
	for effect: WorldEffect in p_pending_campaign_effects:
		pending_campaign_effects.append(effect.duplicate_value())
	ideology_impact = p_ideology_impact.duplicate_value()
	outcome_tags.append_array(p_outcome_tags)
	used_method_tags.append_array(p_used_method_tags)
