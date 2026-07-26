## Pure derived candidate used only during one faction planning call.
class_name FactionIntentCandidate
extends RefCounted

const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

const MODE_DIRECT_ACTION: StringName = &"direct_action"
const MODE_CONTRACT_PROPOSAL: StringName = &"contract_proposal"

var id: StringName
var faction_id: StringName
var week_index: int
var execution_mode: StringName
var source_definition_id: StringName
var origin_type: StringName
var target_problem_id: StringName
var target_lock_key: StringName
var agenda_tags: Array[StringName]
var base_priority: int
var urgency_contribution: int
var agenda_fit: int
var repeat_penalty: int
var total_priority: int
var influence_cost: int
var eligible: bool
var rejection_reason_codes: Array[StringName]
var reason_entries: Array[ReasonEntry]


static func create(
	p_id: StringName,
	p_faction_id: StringName,
	p_week_index: int,
	p_execution_mode: StringName,
	p_source_definition_id: StringName,
	p_origin_type: StringName,
	p_target_problem_id: StringName,
	p_target_lock_key: StringName,
	p_agenda_tags: Array[StringName],
	p_base_priority: int,
	p_urgency_contribution: int,
	p_agenda_fit: int,
	p_repeat_penalty: int,
	p_influence_cost: int,
	p_eligible: bool,
	p_rejection_reason_codes: Array[StringName],
	p_reason_entries: Array[ReasonEntry]
) -> FactionIntentCandidate:
	return FactionIntentCandidate.new(
		p_id,
		p_faction_id,
		p_week_index,
		p_execution_mode,
		p_source_definition_id,
		p_origin_type,
		p_target_problem_id,
		p_target_lock_key,
		p_agenda_tags,
		p_base_priority,
		p_urgency_contribution,
		p_agenda_fit,
		p_repeat_penalty,
		p_base_priority + p_urgency_contribution + p_agenda_fit - p_repeat_penalty,
		p_influence_cost,
		p_eligible,
		p_rejection_reason_codes,
		p_reason_entries
	)


func _init(
	p_id: StringName,
	p_faction_id: StringName,
	p_week_index: int,
	p_execution_mode: StringName,
	p_source_definition_id: StringName,
	p_origin_type: StringName,
	p_target_problem_id: StringName,
	p_target_lock_key: StringName,
	p_agenda_tags: Array[StringName],
	p_base_priority: int,
	p_urgency_contribution: int,
	p_agenda_fit: int,
	p_repeat_penalty: int,
	p_total_priority: int,
	p_influence_cost: int,
	p_eligible: bool,
	p_rejection_reason_codes: Array[StringName],
	p_reason_entries: Array[ReasonEntry]
) -> void:
	id = p_id
	faction_id = p_faction_id
	week_index = p_week_index
	execution_mode = p_execution_mode
	source_definition_id = p_source_definition_id
	origin_type = p_origin_type
	target_problem_id = p_target_problem_id
	target_lock_key = p_target_lock_key
	agenda_tags.append_array(p_agenda_tags)
	base_priority = p_base_priority
	urgency_contribution = p_urgency_contribution
	agenda_fit = p_agenda_fit
	repeat_penalty = p_repeat_penalty
	total_priority = p_total_priority
	influence_cost = p_influence_cost
	eligible = p_eligible
	rejection_reason_codes.append_array(p_rejection_reason_codes)
	for reason: ReasonEntry in p_reason_entries:
		reason_entries.append(reason.duplicate_value() if reason != null else null)


func duplicate_value() -> FactionIntentCandidate:
	return FactionIntentCandidate.new(
		id, faction_id, week_index, execution_mode, source_definition_id,
		origin_type, target_problem_id, target_lock_key, agenda_tags,
		base_priority, urgency_contribution, agenda_fit, repeat_penalty,
		total_priority, influence_cost, eligible, rejection_reason_codes,
		reason_entries
	)
