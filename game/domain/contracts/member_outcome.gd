class_name MemberOutcome
extends RefCounted

const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

var member_id: StringName
var fatigue_delta: int
var injury_result: StringName
var injury_seed: int
var injury_roll: int
var any_injury_chance: int
var heavy_injury_chance: int
var injury_severity_after: int
var recovery_weeks_after: int
var is_available_after: bool
var morale_delta: int
var post_mission_evaluation: float
var reason_entries: Array[ReasonEntry]


static func create(
	p_member_id: StringName,
	p_fatigue_delta: int,
	p_injury_result: StringName,
	p_injury_seed: int,
	p_injury_roll: int,
	p_any_injury_chance: int,
	p_heavy_injury_chance: int,
	p_injury_severity_after: int,
	p_recovery_weeks_after: int,
	p_is_available_after: bool,
	p_morale_delta: int,
	p_post_mission_evaluation: float,
	p_reason_entries: Array[ReasonEntry]
) -> MemberOutcome:
	return MemberOutcome.new(
		p_member_id,
		p_fatigue_delta,
		p_injury_result,
		p_injury_seed,
		p_injury_roll,
		p_any_injury_chance,
		p_heavy_injury_chance,
		p_injury_severity_after,
		p_recovery_weeks_after,
		p_is_available_after,
		p_morale_delta,
		p_post_mission_evaluation,
		p_reason_entries
	)


func _init(
	p_member_id: StringName,
	p_fatigue_delta: int,
	p_injury_result: StringName,
	p_injury_seed: int,
	p_injury_roll: int,
	p_any_injury_chance: int,
	p_heavy_injury_chance: int,
	p_injury_severity_after: int,
	p_recovery_weeks_after: int,
	p_is_available_after: bool,
	p_morale_delta: int,
	p_post_mission_evaluation: float,
	p_reason_entries: Array[ReasonEntry]
) -> void:
	member_id = p_member_id
	fatigue_delta = p_fatigue_delta
	injury_result = p_injury_result
	injury_seed = p_injury_seed
	injury_roll = p_injury_roll
	any_injury_chance = p_any_injury_chance
	heavy_injury_chance = p_heavy_injury_chance
	injury_severity_after = p_injury_severity_after
	recovery_weeks_after = p_recovery_weeks_after
	is_available_after = p_is_available_after
	morale_delta = p_morale_delta
	post_mission_evaluation = p_post_mission_evaluation
	for reason: ReasonEntry in p_reason_entries:
		reason_entries.append(reason.duplicate_value())


func duplicate_value() -> MemberOutcome:
	return MemberOutcome.new(
		member_id,
		fatigue_delta,
		injury_result,
		injury_seed,
		injury_roll,
		any_injury_chance,
		heavy_injury_chance,
		injury_severity_after,
		recovery_weeks_after,
		is_available_after,
		morale_delta,
		post_mission_evaluation,
		reason_entries
	)
