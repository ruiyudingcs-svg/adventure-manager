class_name ProblemUrgencyResult
extends RefCounted

const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

const BAND_LOW: StringName = &"low"
const BAND_GUARDED: StringName = &"guarded"
const BAND_HIGH: StringName = &"high"
const BAND_SEVERE: StringName = &"severe"
const BAND_CRITICAL: StringName = &"critical"

var problem_id: StringName
var evaluated_week: int
var score: int
var band: StringName
var remaining_turns: int
var reason_entries: Array[ReasonEntry]


static func create(
	p_problem_id: StringName,
	p_evaluated_week: int,
	p_score: int,
	p_band: StringName,
	p_remaining_turns: int,
	p_reason_entries: Array[ReasonEntry]
) -> ProblemUrgencyResult:
	return ProblemUrgencyResult.new(
		p_problem_id,
		p_evaluated_week,
		p_score,
		p_band,
		p_remaining_turns,
		p_reason_entries
	)


func _init(
	p_problem_id: StringName,
	p_evaluated_week: int,
	p_score: int,
	p_band: StringName,
	p_remaining_turns: int,
	p_reason_entries: Array[ReasonEntry]
) -> void:
	problem_id = p_problem_id
	evaluated_week = p_evaluated_week
	score = p_score
	band = p_band
	remaining_turns = p_remaining_turns
	for reason: ReasonEntry in p_reason_entries:
		reason_entries.append(reason.duplicate_value())


func duplicate_value() -> ProblemUrgencyResult:
	return ProblemUrgencyResult.new(
		problem_id,
		evaluated_week,
		score,
		band,
		remaining_turns,
		reason_entries
	)


func signature() -> String:
	var reason_parts := PackedStringArray()
	for reason: ReasonEntry in reason_entries:
		reason_parts.append("%s:%s:%s" % [
			reason.code,
			reason.source_id,
			reason.amount,
		])
	return "%s|%d|%d|%s|%d|%s" % [
		problem_id,
		evaluated_week,
		score,
		band,
		remaining_turns,
		reason_parts,
	]
