class_name StateChange
extends RefCounted

var target_id: StringName
var field_path: String
var old_value: Variant
var new_value: Variant
var reason_codes: Array[StringName]


static func create(
	p_target_id: StringName,
	p_field_path: String,
	p_old_value: Variant,
	p_new_value: Variant,
	p_reason_codes: Array[StringName]
) -> StateChange:
	return StateChange.new(
		p_target_id,
		p_field_path,
		p_old_value,
		p_new_value,
		p_reason_codes
	)


func _init(
	p_target_id: StringName,
	p_field_path: String,
	p_old_value: Variant,
	p_new_value: Variant,
	p_reason_codes: Array[StringName]
) -> void:
	target_id = p_target_id
	field_path = p_field_path
	old_value = _duplicate_variant(p_old_value)
	new_value = _duplicate_variant(p_new_value)
	reason_codes.append_array(p_reason_codes)


func duplicate_value() -> StateChange:
	return StateChange.new(target_id, field_path, old_value, new_value, reason_codes)


func signature() -> String:
	return "%s|%s|%s|%s|%s" % [
		target_id,
		field_path,
		var_to_str(old_value),
		var_to_str(new_value),
		reason_codes,
	]


static func _duplicate_variant(source: Variant) -> Variant:
	if source is Object and source.has_method("duplicate_state"):
		return source.call("duplicate_state")
	if source is Object and source.has_method("duplicate_value"):
		return source.call("duplicate_value")
	if typeof(source) == TYPE_ARRAY or typeof(source) == TYPE_DICTIONARY:
		return source.duplicate(true)
	return source
