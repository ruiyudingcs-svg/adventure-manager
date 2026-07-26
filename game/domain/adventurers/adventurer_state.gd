class_name AdventurerState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

const STATUS_MIN: int = 0
const STATUS_MAX: int = 100

var definition_id: StringName:
	get:
		return _definition_id
	set(_value):
		assert(false, "AdventurerState.definition_id cannot change.")

var _definition_id: StringName
var _fatigue: int
var _morale: int
var _injury_severity: int
var _recovery_weeks_remaining: int
var _growth_xp: int
var _is_available: bool
var _relationship_deltas: Dictionary[StringName, int] = {}
var _recent_assignment_count: int
var _recent_neglect_count: int


static func create(
	p_definition_id: StringName,
	p_fatigue: int = 0,
	p_morale: int = 50,
	p_injury_severity: int = 0,
	p_recovery_weeks_remaining: int = 0,
	p_growth_xp: int = 0,
	p_is_available: bool = true,
	p_relationship_deltas: Dictionary[StringName, int] = {},
	p_recent_assignment_count: int = 0,
	p_recent_neglect_count: int = 0
) -> AdventurerState:
	if not validate_values(
		p_definition_id,
		p_fatigue,
		p_morale,
		p_injury_severity,
		p_recovery_weeks_remaining,
		p_growth_xp,
		p_relationship_deltas,
		p_recent_assignment_count,
		p_recent_neglect_count
	).is_empty():
		return null

	var state := AdventurerState.new()
	state._definition_id = p_definition_id
	state._fatigue = p_fatigue
	state._morale = p_morale
	state._injury_severity = p_injury_severity
	state._recovery_weeks_remaining = p_recovery_weeks_remaining
	state._growth_xp = p_growth_xp
	state._is_available = p_is_available
	state._relationship_deltas = _copy_relationships(p_relationship_deltas)
	state._recent_assignment_count = p_recent_assignment_count
	state._recent_neglect_count = p_recent_neglect_count
	return state


static func validate_values(
	p_definition_id: StringName,
	p_fatigue: int,
	p_morale: int,
	p_injury_severity: int,
	p_recovery_weeks_remaining: int,
	p_growth_xp: int,
	p_relationship_deltas: Dictionary[StringName, int],
	p_recent_assignment_count: int,
	p_recent_neglect_count: int
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(p_definition_id):
		errors.append(StableId.validation_error(p_definition_id, "AdventurerState.definition_id"))
	_append_status_error(errors, &"fatigue", p_fatigue)
	_append_status_error(errors, &"morale", p_morale)
	_append_status_error(errors, &"injury_severity", p_injury_severity)
	if p_recovery_weeks_remaining < 0:
		errors.append("recovery_weeks_remaining must be non-negative.")
	if p_growth_xp < 0:
		errors.append("growth_xp must be non-negative.")
	if p_recent_assignment_count < 0 or p_recent_neglect_count < 0:
		errors.append("Recent assignment counters must be non-negative.")
	for target_id: StringName in p_relationship_deltas:
		if not StableId.is_valid(target_id):
			errors.append(StableId.validation_error(target_id, "relationship_deltas key"))
	return errors


func get_fatigue() -> int:
	return _fatigue


func set_fatigue(value: int) -> bool:
	if not _is_status_value(value):
		return false
	_fatigue = value
	return true


func get_morale() -> int:
	return _morale


func set_morale(value: int) -> bool:
	if not _is_status_value(value):
		return false
	_morale = value
	return true


func get_injury_severity() -> int:
	return _injury_severity


func set_injury_severity(value: int) -> bool:
	if not _is_status_value(value):
		return false
	_injury_severity = value
	return true


func get_recovery_weeks_remaining() -> int:
	return _recovery_weeks_remaining


func get_growth_xp() -> int:
	return _growth_xp


func get_is_available() -> bool:
	return _is_available


func get_relationship_deltas() -> Dictionary[StringName, int]:
	return _copy_relationships(_relationship_deltas)


func set_relationship_delta(target_id: StringName, value: int) -> bool:
	if not StableId.is_valid(target_id):
		return false
	_relationship_deltas[target_id] = value
	return true


func get_recent_assignment_count() -> int:
	return _recent_assignment_count


func get_recent_neglect_count() -> int:
	return _recent_neglect_count


func duplicate_state() -> AdventurerState:
	return AdventurerState.create(
		_definition_id,
		_fatigue,
		_morale,
		_injury_severity,
		_recovery_weeks_remaining,
		_growth_xp,
		_is_available,
		_relationship_deltas,
		_recent_assignment_count,
		_recent_neglect_count
	)


static func _copy_relationships(
	source: Dictionary[StringName, int]
) -> Dictionary[StringName, int]:
	var copied: Dictionary[StringName, int] = {}
	for target_id: StringName in source:
		copied[target_id] = source[target_id]
	return copied


static func _append_status_error(errors: PackedStringArray, field_name: StringName, value: int) -> void:
	if not _is_status_value(value):
		errors.append("%s must be between %d and %d." % [field_name, STATUS_MIN, STATUS_MAX])


static func _is_status_value(value: int) -> bool:
	return value >= STATUS_MIN and value <= STATUS_MAX
