class_name MissionContext
extends RefCounted

const CONTEXT_KEYS: Array[StringName] = [
	&"intel",
	&"route_safety",
	&"collected_resources",
	&"protected_civilians",
	&"time_pressure",
	&"alert_level",
	&"enemy_pressure",
	&"collateral_pressure",
	&"team_strain",
	&"extraction_pressure",
]


var outcome_tags: Array[StringName]:
	get:
		return _copy_tags(_outcome_tags)
var used_method_tags: Array[StringName]:
	get:
		return _copy_tags(_used_method_tags)

var _values: Dictionary[StringName, int] = {}
var _outcome_tags: Array[StringName] = []
var _used_method_tags: Array[StringName] = []


static func create_default() -> MissionContext:
	return MissionContext.new()


static func create_delta(
	key: StringName,
	amount: int,
	source_id: StringName = &""
) -> Dictionary:
	return {
		"key": key,
		"amount": amount,
		"source_id": source_id,
	}


func _init(
	p_values: Dictionary[StringName, int] = {},
	p_outcome_tags: Array[StringName] = [],
	p_used_method_tags: Array[StringName] = []
) -> void:
	for key: StringName in CONTEXT_KEYS:
		_values[key] = clampi(p_values.get(key, 0), 0, 10)
	_outcome_tags = _stable_unique(p_outcome_tags)
	_used_method_tags = _stable_unique(p_used_method_tags)


func get_value(key: StringName) -> int:
	return _values.get(key, -1)


func has_key(key: StringName) -> bool:
	return CONTEXT_KEYS.has(key)


func duplicate_value() -> MissionContext:
	return MissionContext.new(_values.duplicate(), _outcome_tags, _used_method_tags)


func is_equal_to(other: MissionContext) -> bool:
	if other == null:
		return false
	for key: StringName in CONTEXT_KEYS:
		if get_value(key) != other.get_value(key):
			return false
	return _outcome_tags == other.outcome_tags \
		and _used_method_tags == other.used_method_tags


static func _stable_unique(source: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: StringName in source:
		if not result.has(value):
			result.append(value)
	return result


static func _copy_tags(source: Array[StringName]) -> Array[StringName]:
	var copied: Array[StringName] = []
	copied.append_array(source)
	return copied
