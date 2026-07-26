## Static, reasoned urgency adjustment for a world problem.
class_name ProblemUrgencyRule
extends RefCounted

const WorldCondition = preload("res://game/domain/situations/world_condition.gd")

var id: StringName
var all_conditions: Array[WorldCondition]
var urgency_delta: int
var reason_code: StringName
var visibility: StringName
var priority: int


static func create(
	p_id: StringName,
	p_all_conditions: Array[WorldCondition],
	p_urgency_delta: int,
	p_reason_code: StringName,
	p_visibility: StringName,
	p_priority: int
) -> ProblemUrgencyRule:
	return ProblemUrgencyRule.new(
		p_id,
		p_all_conditions,
		p_urgency_delta,
		p_reason_code,
		p_visibility,
		p_priority
	)


func _init(
	p_id: StringName,
	p_all_conditions: Array[WorldCondition],
	p_urgency_delta: int,
	p_reason_code: StringName,
	p_visibility: StringName,
	p_priority: int
) -> void:
	id = p_id
	for condition: WorldCondition in p_all_conditions:
		all_conditions.append(condition.duplicate_value() if condition != null else null)
	urgency_delta = p_urgency_delta
	reason_code = p_reason_code
	visibility = p_visibility
	priority = p_priority


func duplicate_value() -> ProblemUrgencyRule:
	return ProblemUrgencyRule.new(
		id,
		all_conditions,
		urgency_delta,
		reason_code,
		visibility,
		priority
	)
