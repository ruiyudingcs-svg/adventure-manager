class_name ReasonEntry
extends RefCounted

const VISIBILITY_PLAYER: StringName = &"player"
const VISIBILITY_DEBUG: StringName = &"debug"

var code: StringName:
	get:
		return _code
	set(_value):
		assert(false, "ReasonEntry.code is read-only.")
var category: StringName:
	get:
		return _category
	set(_value):
		assert(false, "ReasonEntry.category is read-only.")
var source_id: StringName:
	get:
		return _source_id
	set(_value):
		assert(false, "ReasonEntry.source_id is read-only.")
var target_id: StringName:
	get:
		return _target_id
	set(_value):
		assert(false, "ReasonEntry.target_id is read-only.")
var amount: float:
	get:
		return _amount
	set(_value):
		assert(false, "ReasonEntry.amount is read-only.")
var localization_key: StringName:
	get:
		return _localization_key
	set(_value):
		assert(false, "ReasonEntry.localization_key is read-only.")
var parameters: Dictionary:
	get:
		return _parameters.duplicate(true)
	set(_value):
		assert(false, "ReasonEntry.parameters is read-only.")
var phase: StringName:
	get:
		return _phase
	set(_value):
		assert(false, "ReasonEntry.phase is read-only.")
var visibility: StringName:
	get:
		return _visibility
	set(_value):
		assert(false, "ReasonEntry.visibility is read-only.")

var _code: StringName
var _category: StringName
var _source_id: StringName
var _target_id: StringName
var _amount: float
var _localization_key: StringName
var _parameters: Dictionary
var _phase: StringName
var _visibility: StringName


static func create(
	p_code: StringName,
	p_category: StringName,
	p_source_id: StringName,
	p_target_id: StringName,
	p_amount: float,
	p_localization_key: StringName,
	p_parameters: Dictionary,
	p_phase: StringName,
	p_visibility: StringName
) -> ReasonEntry:
	if p_visibility != VISIBILITY_PLAYER and p_visibility != VISIBILITY_DEBUG:
		return null
	return ReasonEntry.new(
		p_code,
		p_category,
		p_source_id,
		p_target_id,
		p_amount,
		p_localization_key,
		p_parameters,
		p_phase,
		p_visibility
	)


func _init(
	p_code: StringName,
	p_category: StringName,
	p_source_id: StringName,
	p_target_id: StringName,
	p_amount: float,
	p_localization_key: StringName,
	p_parameters: Dictionary,
	p_phase: StringName,
	p_visibility: StringName
) -> void:
	assert(p_visibility == VISIBILITY_PLAYER or p_visibility == VISIBILITY_DEBUG)
	_code = p_code
	_category = p_category
	_source_id = p_source_id
	_target_id = p_target_id
	_amount = p_amount
	_localization_key = p_localization_key
	_parameters = p_parameters.duplicate(true)
	_phase = p_phase
	_visibility = p_visibility


func duplicate_value() -> ReasonEntry:
	return ReasonEntry.new(
		_code,
		_category,
		_source_id,
		_target_id,
		_amount,
		_localization_key,
		_parameters,
		_phase,
		_visibility
	)
