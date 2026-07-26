class_name WorldEffect
extends RefCounted

var type: StringName
var target_id: StringName
var amount: int
var reason_code: StringName


static func create(
	p_type: StringName,
	p_target_id: StringName,
	p_amount: int,
	p_reason_code: StringName
) -> WorldEffect:
	return WorldEffect.new(p_type, p_target_id, p_amount, p_reason_code)


func _init(
	p_type: StringName,
	p_target_id: StringName,
	p_amount: int,
	p_reason_code: StringName
) -> void:
	type = p_type
	target_id = p_target_id
	amount = p_amount
	reason_code = p_reason_code


func duplicate_value() -> WorldEffect:
	return WorldEffect.new(type, target_id, amount, reason_code)
