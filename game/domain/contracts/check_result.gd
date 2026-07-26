class_name CheckResult
extends RefCounted

const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const MemberEffect = preload("res://game/domain/contracts/member_effect.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")

var check_id: StringName
var phase: StringName
var check_type: StringName
var raw_score: float
var score: int
var result_tier: StringName
var result_weight: float
var seed: int
var used_method_tags: Array[StringName]
var context_before: MissionContext
var context_deltas: Array[Dictionary]
var reason_entries: Array[ReasonEntry]
var pending_member_effects: Array[MemberEffect]
var pending_campaign_effects: Array[WorldEffect]
var ideology_impact: IdeologyVector
var outcome_tags: Array[StringName]


static func create(
	p_check_id: StringName,
	p_phase: StringName,
	p_check_type: StringName,
	p_raw_score: float,
	p_score: int,
	p_result_tier: StringName,
	p_result_weight: float,
	p_seed: int,
	p_used_method_tags: Array[StringName],
	p_context_before: MissionContext,
	p_context_deltas: Array[Dictionary],
	p_reason_entries: Array[ReasonEntry],
	p_pending_member_effects: Array[MemberEffect],
	p_pending_campaign_effects: Array[WorldEffect],
	p_ideology_impact: IdeologyVector,
	p_outcome_tags: Array[StringName]
) -> CheckResult:
	return CheckResult.new(
		p_check_id,
		p_phase,
		p_check_type,
		p_raw_score,
		p_score,
		p_result_tier,
		p_result_weight,
		p_seed,
		p_used_method_tags,
		p_context_before,
		p_context_deltas,
		p_reason_entries,
		p_pending_member_effects,
		p_pending_campaign_effects,
		p_ideology_impact,
		p_outcome_tags
	)


func _init(
	p_check_id: StringName,
	p_phase: StringName,
	p_check_type: StringName,
	p_raw_score: float,
	p_score: int,
	p_result_tier: StringName,
	p_result_weight: float,
	p_seed: int,
	p_used_method_tags: Array[StringName],
	p_context_before: MissionContext,
	p_context_deltas: Array[Dictionary],
	p_reason_entries: Array[ReasonEntry],
	p_pending_member_effects: Array[MemberEffect],
	p_pending_campaign_effects: Array[WorldEffect],
	p_ideology_impact: IdeologyVector,
	p_outcome_tags: Array[StringName]
) -> void:
	check_id = p_check_id
	phase = p_phase
	check_type = p_check_type
	raw_score = p_raw_score
	score = p_score
	result_tier = p_result_tier
	result_weight = p_result_weight
	seed = p_seed
	used_method_tags.append_array(p_used_method_tags)
	context_before = p_context_before.duplicate_value()
	for delta: Dictionary in p_context_deltas:
		context_deltas.append(delta.duplicate(true))
	for reason: ReasonEntry in p_reason_entries:
		reason_entries.append(reason.duplicate_value())
	for effect: MemberEffect in p_pending_member_effects:
		pending_member_effects.append(effect.duplicate_value())
	for effect: WorldEffect in p_pending_campaign_effects:
		pending_campaign_effects.append(effect.duplicate_value())
	ideology_impact = p_ideology_impact.duplicate_value()
	outcome_tags.append_array(p_outcome_tags)


func duplicate_value() -> CheckResult:
	return CheckResult.new(
		check_id,
		phase,
		check_type,
		raw_score,
		score,
		result_tier,
		result_weight,
		seed,
		used_method_tags,
		context_before,
		context_deltas,
		reason_entries,
		pending_member_effects,
		pending_campaign_effects,
		ideology_impact,
		outcome_tags
	)
