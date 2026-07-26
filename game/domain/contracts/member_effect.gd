class_name MemberEffect
extends RefCounted

var target_id: StringName
var type: StringName
var amount: int
var reason_code: StringName


static func create(
	p_target_id: StringName,
	p_type: StringName,
	p_amount: int,
	p_reason_code: StringName
) -> MemberEffect:
	return MemberEffect.new(p_target_id, p_type, p_amount, p_reason_code)


func _init(
	p_target_id: StringName,
	p_type: StringName,
	p_amount: int,
	p_reason_code: StringName
) -> void:
	target_id = p_target_id
	type = p_type
	amount = p_amount
	reason_code = p_reason_code


func duplicate_value() -> MemberEffect:
	return MemberEffect.new(target_id, type, amount, reason_code)
