class_name WorldProblemState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

const STATUS_INACTIVE: StringName = &"inactive"
const STATUS_ACTIVE: StringName = &"active"
const STATUS_RESOLVED: StringName = &"resolved"
const STATUS_ESCALATED: StringName = &"escalated"
const STATUS_CLOSED: StringName = &"closed"
const ALLOWED_STATUSES: Array[StringName] = [
	STATUS_INACTIVE,
	STATUS_ACTIVE,
	STATUS_RESOLVED,
	STATUS_ESCALATED,
	STATUS_CLOSED,
]

var definition_id: StringName
var status: StringName
var opened_week: int
var response_deadline_week: int
var closed_week: int
var source_event_id: StringName
var resolution_reason_code: StringName


static func create(
	p_definition_id: StringName,
	p_status: StringName = STATUS_INACTIVE,
	p_opened_week: int = -1,
	p_response_deadline_week: int = -1,
	p_closed_week: int = -1,
	p_source_event_id: StringName = &"",
	p_resolution_reason_code: StringName = &""
) -> WorldProblemState:
	if not validate_values(
		p_definition_id,
		p_status,
		p_opened_week,
		p_response_deadline_week,
		p_closed_week,
		p_source_event_id,
		p_resolution_reason_code
	).is_empty():
		return null
	return WorldProblemState.new(
		p_definition_id,
		p_status,
		p_opened_week,
		p_response_deadline_week,
		p_closed_week,
		p_source_event_id,
		p_resolution_reason_code
	)


func _init(
	p_definition_id: StringName,
	p_status: StringName,
	p_opened_week: int,
	p_response_deadline_week: int,
	p_closed_week: int,
	p_source_event_id: StringName,
	p_resolution_reason_code: StringName
) -> void:
	definition_id = p_definition_id
	status = p_status
	opened_week = p_opened_week
	response_deadline_week = p_response_deadline_week
	closed_week = p_closed_week
	source_event_id = p_source_event_id
	resolution_reason_code = p_resolution_reason_code


static func validate_values(
	p_definition_id: StringName,
	p_status: StringName,
	p_opened_week: int,
	p_response_deadline_week: int,
	p_closed_week: int,
	p_source_event_id: StringName,
	p_resolution_reason_code: StringName = &""
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(p_definition_id):
		errors.append(StableId.validation_error(
			p_definition_id,
			"WorldProblemState.definition_id"
		))
	if not ALLOWED_STATUSES.has(p_status):
		errors.append("WorldProblemState.status is not allowed: %s." % p_status)
	if p_opened_week < -1 or p_response_deadline_week < -1 or p_closed_week < -1:
		errors.append("WorldProblemState week values must be -1 or non-negative.")
	if not p_source_event_id.is_empty() and not StableId.is_valid(p_source_event_id):
		errors.append(StableId.validation_error(
			p_source_event_id,
			"WorldProblemState.source_event_id"
		))
	if not p_resolution_reason_code.is_empty() \
		and not StableId.is_valid(p_resolution_reason_code):
		errors.append(StableId.validation_error(
			p_resolution_reason_code,
			"WorldProblemState.resolution_reason_code"
		))
	if p_status == STATUS_INACTIVE:
		if p_opened_week != -1 or p_response_deadline_week != -1 or p_closed_week != -1:
			errors.append("Inactive problems cannot have lifecycle week values.")
	elif p_opened_week < 0:
		errors.append("Opened problems require an opened week.")
	if p_response_deadline_week >= 0 \
		and p_opened_week >= 0 \
		and p_response_deadline_week < p_opened_week:
		errors.append("Problem deadline cannot precede its opened week.")
	if (
		p_status == STATUS_RESOLVED
		or p_status == STATUS_ESCALATED
		or p_status == STATUS_CLOSED
	) and p_closed_week < 0:
		errors.append("Terminal problems require a closed week.")
	if (p_status == STATUS_ACTIVE or p_status == STATUS_INACTIVE) and p_closed_week != -1:
		errors.append("Non-terminal problems cannot have a closed week.")
	return errors


func validate() -> PackedStringArray:
	return validate_values(
		definition_id,
		status,
		opened_week,
		response_deadline_week,
		closed_week,
		source_event_id,
		resolution_reason_code
	)


func duplicate_state() -> WorldProblemState:
	return WorldProblemState.new(
		definition_id,
		status,
		opened_week,
		response_deadline_week,
		closed_week,
		source_event_id,
		resolution_reason_code
	)
