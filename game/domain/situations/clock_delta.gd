## Static shorthand for one reasoned passive clock delta.
class_name ClockDelta
extends RefCounted

var clock_id: StringName
var amount: int
var reason_code: StringName


static func create(
	p_clock_id: StringName,
	p_amount: int,
	p_reason_code: StringName
) -> ClockDelta:
	return ClockDelta.new(p_clock_id, p_amount, p_reason_code)


func _init(p_clock_id: StringName, p_amount: int, p_reason_code: StringName) -> void:
	clock_id = p_clock_id
	amount = p_amount
	reason_code = p_reason_code


func duplicate_value() -> ClockDelta:
	return ClockDelta.new(clock_id, amount, reason_code)
