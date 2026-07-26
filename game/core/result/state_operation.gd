class_name StateOperation
extends RefCounted

const OP_ADD_INT: StringName = &"add_int"
const OP_SET_ID: StringName = &"set_id"
const OP_ADD_UNIQUE: StringName = &"add_unique"
const OP_REMOVE_UNIQUE: StringName = &"remove_unique"
const OP_APPEND_RECORD: StringName = &"append_record"

const ALLOWED_OPERATIONS: Array[StringName] = [
	OP_ADD_INT,
	OP_SET_ID,
	OP_ADD_UNIQUE,
	OP_REMOVE_UNIQUE,
	OP_APPEND_RECORD,
]

var target_kind: StringName
var target_id: StringName
var field_id: StringName
var operation: StringName
var value: Variant
var reason_code: StringName
var source_order: int


static func create(
	p_target_kind: StringName,
	p_target_id: StringName,
	p_field_id: StringName,
	p_operation: StringName,
	p_value: Variant,
	p_reason_code: StringName,
	p_source_order: int
) -> StateOperation:
	return StateOperation.new(
		p_target_kind,
		p_target_id,
		p_field_id,
		p_operation,
		p_value,
		p_reason_code,
		p_source_order
	)


func _init(
	p_target_kind: StringName,
	p_target_id: StringName,
	p_field_id: StringName,
	p_operation: StringName,
	p_value: Variant,
	p_reason_code: StringName,
	p_source_order: int
) -> void:
	target_kind = p_target_kind
	target_id = p_target_id
	field_id = p_field_id
	operation = p_operation
	value = _duplicate_variant(p_value)
	reason_code = p_reason_code
	source_order = p_source_order


func duplicate_value() -> StateOperation:
	return StateOperation.new(
		target_kind,
		target_id,
		field_id,
		operation,
		value,
		reason_code,
		source_order
	)


static func is_allowed_operation(value_to_check: StringName) -> bool:
	return ALLOWED_OPERATIONS.has(value_to_check)


static func _duplicate_variant(source: Variant) -> Variant:
	if source is Object and source.has_method("duplicate_state"):
		return source.call("duplicate_state")
	if source is Object and source.has_method("duplicate_value"):
		return source.call("duplicate_value")
	if typeof(source) == TYPE_ARRAY or typeof(source) == TYPE_DICTIONARY:
		return source.duplicate(true)
	return source
