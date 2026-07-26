class_name MessageRequest
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

const CATEGORY_UPKEEP: StringName = &"upkeep"
const CATEGORY_WORLD_EVENT: StringName = &"world_event"
const CATEGORY_CONTRACT_OFFER: StringName = &"contract_offer"
const CATEGORY_CONTRACT_LIFECYCLE: StringName = &"contract_lifecycle"
const CATEGORY_FACTION_ACTION: StringName = &"faction_action"
const CATEGORY_CONTRACT_RESULT: StringName = &"contract_result"
const CATEGORY_WEEK_SUMMARY: StringName = &"week_summary"
const ALLOWED_CATEGORIES: Array[StringName] = [
	CATEGORY_UPKEEP,
	CATEGORY_WORLD_EVENT,
	CATEGORY_CONTRACT_OFFER,
	CATEGORY_CONTRACT_LIFECYCLE,
	CATEGORY_FACTION_ACTION,
	CATEGORY_CONTRACT_RESULT,
	CATEGORY_WEEK_SUMMARY,
]

const IMPORTANCE_LOW: StringName = &"low"
const IMPORTANCE_NORMAL: StringName = &"normal"
const IMPORTANCE_HIGH: StringName = &"high"
const IMPORTANCE_CRITICAL: StringName = &"critical"
const ALLOWED_IMPORTANCE: Array[StringName] = [
	IMPORTANCE_LOW,
	IMPORTANCE_NORMAL,
	IMPORTANCE_HIGH,
	IMPORTANCE_CRITICAL,
]

var category: StringName
var source_type: StringName
var source_id: StringName
var title_key: StringName
var body_key: StringName
var parameters: Dictionary:
	get:
		return _parameters.duplicate(true)
	set(value):
		_parameters = value.duplicate(true)
var importance: StringName
var trace_order: int

var _parameters: Dictionary


static func create(
	p_category: StringName,
	p_source_type: StringName,
	p_source_id: StringName,
	p_title_key: StringName,
	p_body_key: StringName,
	p_parameters: Dictionary,
	p_importance: StringName = IMPORTANCE_NORMAL,
	p_trace_order: int = 0
) -> MessageRequest:
	var request := MessageRequest.new(
		p_category,
		p_source_type,
		p_source_id,
		p_title_key,
		p_body_key,
		p_parameters,
		p_importance,
		p_trace_order
	)
	return request if request.validate().is_empty() else null


func _init(
	p_category: StringName,
	p_source_type: StringName,
	p_source_id: StringName,
	p_title_key: StringName,
	p_body_key: StringName,
	p_parameters: Dictionary,
	p_importance: StringName,
	p_trace_order: int
) -> void:
	category = p_category
	source_type = p_source_type
	source_id = p_source_id
	title_key = p_title_key
	body_key = p_body_key
	_parameters = p_parameters.duplicate(true)
	importance = p_importance
	trace_order = p_trace_order


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not ALLOWED_CATEGORIES.has(category):
		errors.append("MessageRequest.category is not allowed: %s." % category)
	if not ALLOWED_IMPORTANCE.has(importance):
		errors.append("MessageRequest.importance is not allowed: %s." % importance)
	for pair: Array in [
		[source_type, "source_type"],
		[source_id, "source_id"],
		[title_key, "title_key"],
		[body_key, "body_key"],
	]:
		if not StableId.is_valid(pair[0]):
			errors.append(StableId.validation_error(
				pair[0],
				"MessageRequest.%s" % pair[1]
			))
	if trace_order < 0:
		errors.append("MessageRequest.trace_order must be non-negative.")
	_validate_parameter_value(_parameters, "parameters", errors)
	return errors


func duplicate_value() -> MessageRequest:
	return MessageRequest.new(
		category,
		source_type,
		source_id,
		title_key,
		body_key,
		_parameters,
		importance,
		trace_order
	)


func signature() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%d" % [
		category,
		source_type,
		source_id,
		title_key,
		body_key,
		_stable_variant_signature(_parameters),
		importance,
		trace_order,
	]


static func _validate_parameter_value(
	value: Variant,
	path: String,
	errors: PackedStringArray
) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return
		TYPE_ARRAY:
			for index: int in range(value.size()):
				_validate_parameter_value(value[index], "%s[%d]" % [path, index], errors)
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
					errors.append("%s keys must be String or StringName." % path)
					continue
				_validate_parameter_value(value[key], "%s.%s" % [path, key], errors)
		_:
			errors.append(
				"%s contains unsupported parameter type %s."
				% [path, type_string(typeof(value))]
			)


static func _stable_variant_signature(value: Variant) -> String:
	if typeof(value) == TYPE_ARRAY:
		var parts := PackedStringArray()
		for item: Variant in value:
			parts.append(_stable_variant_signature(item))
		return "[%s]" % "|".join(parts)
	if typeof(value) == TYPE_DICTIONARY:
		var keys := PackedStringArray()
		for key: Variant in value:
			keys.append(String(key))
		keys.sort()
		var parts := PackedStringArray()
		for key: String in keys:
			var actual_key: Variant = (
				StringName(key) if value.has(StringName(key)) else key
			)
			parts.append("%s=%s" % [
				key,
				_stable_variant_signature(value[actual_key]),
			])
		return "{%s}" % "|".join(parts)
	return var_to_str(value)
