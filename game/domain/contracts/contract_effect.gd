class_name ContractEffect
extends RefCounted

const TYPES: Array[StringName] = [
	&"modify_reward_percent",
	&"modify_sponsor_relation",
	&"add_outcome_tag",
]

var type: StringName
var amount: int
var tag_value: StringName
var reason_code: StringName


static func create(
	p_type: StringName,
	p_amount: int = 0,
	p_tag_value: StringName = &"",
	p_reason_code: StringName = &""
) -> ContractEffect:
	return ContractEffect.new(p_type, p_amount, p_tag_value, p_reason_code)


func _init(
	p_type: StringName,
	p_amount: int,
	p_tag_value: StringName,
	p_reason_code: StringName
) -> void:
	type = p_type
	amount = p_amount
	tag_value = p_tag_value
	reason_code = p_reason_code


func duplicate_value() -> ContractEffect:
	return ContractEffect.new(type, amount, tag_value, reason_code)
