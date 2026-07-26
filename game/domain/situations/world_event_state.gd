class_name WorldEventState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

const VISIBILITY_PLAYER: StringName = &"player"
const VISIBILITY_DEBUG: StringName = &"debug"

var instance_id: StringName
var event_key: StringName
var week_index: int
var source_id: StringName
var related_problem_id: StringName
var effect_reason_codes: Array[StringName]
var visibility: StringName


static func create(
	p_instance_id: StringName,
	p_event_key: StringName,
	p_week_index: int,
	p_source_id: StringName,
	p_related_problem_id: StringName,
	p_effect_reason_codes: Array[StringName],
	p_visibility: StringName = VISIBILITY_PLAYER
) -> WorldEventState:
	if not validate_values(
		p_instance_id,
		p_event_key,
		p_week_index,
		p_source_id,
		p_related_problem_id,
		p_effect_reason_codes,
		p_visibility
	).is_empty():
		return null
	return WorldEventState.new(
		p_instance_id,
		p_event_key,
		p_week_index,
		p_source_id,
		p_related_problem_id,
		p_effect_reason_codes,
		p_visibility
	)


func _init(
	p_instance_id: StringName,
	p_event_key: StringName,
	p_week_index: int,
	p_source_id: StringName,
	p_related_problem_id: StringName,
	p_effect_reason_codes: Array[StringName],
	p_visibility: StringName
) -> void:
	instance_id = p_instance_id
	event_key = p_event_key
	week_index = p_week_index
	source_id = p_source_id
	related_problem_id = p_related_problem_id
	effect_reason_codes.append_array(p_effect_reason_codes)
	# Reason codes describe a set of causes, not execution order. Canonical text
	# order keeps save and full-campaign signatures independent of StringName
	# interning history across earlier simulations.
	effect_reason_codes.sort_custom(_stable_id_less)
	visibility = p_visibility


static func validate_values(
	p_instance_id: StringName,
	p_event_key: StringName,
	p_week_index: int,
	p_source_id: StringName,
	p_related_problem_id: StringName,
	p_effect_reason_codes: Array[StringName],
	p_visibility: StringName
) -> PackedStringArray:
	var errors := PackedStringArray()
	for pair: Array in [
		[p_instance_id, "WorldEventState.instance_id"],
		[p_event_key, "WorldEventState.event_key"],
		[p_source_id, "WorldEventState.source_id"],
	]:
		if not StableId.is_valid(pair[0]):
			errors.append(StableId.validation_error(pair[0], pair[1]))
	if p_week_index < 0:
		errors.append("WorldEventState.week_index must be non-negative.")
	if not p_related_problem_id.is_empty() and not StableId.is_valid(p_related_problem_id):
		errors.append(StableId.validation_error(
			p_related_problem_id,
			"WorldEventState.related_problem_id"
		))
	for reason_code: StringName in p_effect_reason_codes:
		if not StableId.is_valid(reason_code):
			errors.append(StableId.validation_error(
				reason_code,
				"WorldEventState.effect_reason_codes item"
			))
	if p_visibility != VISIBILITY_PLAYER and p_visibility != VISIBILITY_DEBUG:
		errors.append("WorldEventState.visibility must be player or debug.")
	return errors


func validate() -> PackedStringArray:
	return validate_values(
		instance_id,
		event_key,
		week_index,
		source_id,
		related_problem_id,
		effect_reason_codes,
		visibility
	)


func duplicate_state() -> WorldEventState:
	return WorldEventState.new(
		instance_id,
		event_key,
		week_index,
		source_id,
		related_problem_id,
		effect_reason_codes,
		visibility
	)


func content_signature() -> String:
	return "%s|%s|%d|%s|%s|%s|%s" % [
		instance_id,
		event_key,
		week_index,
		source_id,
		related_problem_id,
		effect_reason_codes,
		visibility,
	]


static func _stable_id_less(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
