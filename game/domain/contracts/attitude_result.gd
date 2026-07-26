class_name AttitudeResult
extends RefCounted

const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

var member_id: StringName
var ideology_fit: int
var method_fit: int
var personal_fit: int
var score: int
var status: StringName
var forced: bool
var reason_entries: Array[ReasonEntry]


static func create(
	p_member_id: StringName,
	p_ideology_fit: int,
	p_method_fit: int,
	p_personal_fit: int,
	p_score: int,
	p_status: StringName,
	p_forced: bool,
	p_reason_entries: Array[ReasonEntry]
) -> AttitudeResult:
	return AttitudeResult.new(
		p_member_id,
		p_ideology_fit,
		p_method_fit,
		p_personal_fit,
		p_score,
		p_status,
		p_forced,
		p_reason_entries
	)


func _init(
	p_member_id: StringName,
	p_ideology_fit: int,
	p_method_fit: int,
	p_personal_fit: int,
	p_score: int,
	p_status: StringName,
	p_forced: bool,
	p_reason_entries: Array[ReasonEntry]
) -> void:
	member_id = p_member_id
	ideology_fit = p_ideology_fit
	method_fit = p_method_fit
	personal_fit = p_personal_fit
	score = p_score
	status = p_status
	forced = p_forced
	for reason: ReasonEntry in p_reason_entries:
		reason_entries.append(reason.duplicate_value())


func duplicate_value() -> AttitudeResult:
	return AttitudeResult.new(
		member_id,
		ideology_fit,
		method_fit,
		personal_fit,
		score,
		status,
		forced,
		reason_entries
	)
