## Pure one-faction selection result from the two-pass planner.
class_name FactionIntentPlan
extends RefCounted

const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

var faction_id: StringName
var week_index: int
var mode: StringName
var selected_intent_id: StringName
var reserved_target_lock_key: StringName
var reason_entries: Array[ReasonEntry]


static func create(
	p_faction_id: StringName,
	p_week_index: int,
	p_mode: StringName,
	p_selected_intent_id: StringName,
	p_reserved_target_lock_key: StringName,
	p_reason_entries: Array[ReasonEntry]
) -> FactionIntentPlan:
	return FactionIntentPlan.new(
		p_faction_id,
		p_week_index,
		p_mode,
		p_selected_intent_id,
		p_reserved_target_lock_key,
		p_reason_entries
	)


func _init(
	p_faction_id: StringName,
	p_week_index: int,
	p_mode: StringName,
	p_selected_intent_id: StringName,
	p_reserved_target_lock_key: StringName,
	p_reason_entries: Array[ReasonEntry]
) -> void:
	faction_id = p_faction_id
	week_index = p_week_index
	mode = p_mode
	selected_intent_id = p_selected_intent_id
	reserved_target_lock_key = p_reserved_target_lock_key
	for reason: ReasonEntry in p_reason_entries:
		reason_entries.append(reason.duplicate_value() if reason != null else null)


func duplicate_value() -> FactionIntentPlan:
	return FactionIntentPlan.new(
		faction_id,
		week_index,
		mode,
		selected_intent_id,
		reserved_target_lock_key,
		reason_entries
	)
