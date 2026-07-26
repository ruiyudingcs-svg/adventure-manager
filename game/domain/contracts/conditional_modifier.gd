class_name ConditionalModifier
extends RefCounted

const TARGET_TYPES: Array[StringName] = [
	&"check",
	&"injury_any",
	&"injury_heavy",
	&"fatigue",
]

var target_type: StringName
var match_tag: StringName
var amount: int
var reason_code: StringName


static func create(
	p_target_type: StringName,
	p_match_tag: StringName,
	p_amount: int,
	p_reason_code: StringName
) -> ConditionalModifier:
	return ConditionalModifier.new(p_target_type, p_match_tag, p_amount, p_reason_code)


func _init(
	p_target_type: StringName,
	p_match_tag: StringName,
	p_amount: int,
	p_reason_code: StringName
) -> void:
	target_type = p_target_type
	match_tag = p_match_tag
	amount = p_amount
	reason_code = p_reason_code


func duplicate_value() -> ConditionalModifier:
	return ConditionalModifier.new(target_type, match_tag, amount, reason_code)
