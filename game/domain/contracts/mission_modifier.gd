class_name MissionModifier
extends RefCounted

const CONDITION_TYPES: Array[StringName] = [
	&"context_gte",
	&"context_lte",
	&"previous_check_tier_gte",
	&"previous_check_tier_lte",
	&"outcome_tag_present",
	&"supply_tag_present",
	&"approach_is",
]

var condition_type: StringName
var operand: StringName
var threshold: int
var amount: int
var per_context_point: bool
var maximum_absolute_amount: int


static func create(
	p_condition_type: StringName,
	p_operand: StringName,
	p_threshold: int,
	p_amount: int,
	p_per_context_point: bool = false,
	p_maximum_absolute_amount: int = 0
) -> MissionModifier:
	return MissionModifier.new(
		p_condition_type,
		p_operand,
		p_threshold,
		p_amount,
		p_per_context_point,
		p_maximum_absolute_amount
	)


static func context_per_point(
	context_key: StringName,
	amount_per_point: int,
	maximum_absolute_amount: int = 0
) -> MissionModifier:
	return MissionModifier.new(
		&"context_gte",
		context_key,
		1,
		amount_per_point,
		true,
		maximum_absolute_amount
	)


func _init(
	p_condition_type: StringName,
	p_operand: StringName,
	p_threshold: int,
	p_amount: int,
	p_per_context_point: bool,
	p_maximum_absolute_amount: int
) -> void:
	condition_type = p_condition_type
	operand = p_operand
	threshold = p_threshold
	amount = p_amount
	per_context_point = p_per_context_point
	maximum_absolute_amount = p_maximum_absolute_amount


func duplicate_value() -> MissionModifier:
	return MissionModifier.new(
		condition_type,
		operand,
		threshold,
		amount,
		per_context_point,
		maximum_absolute_amount
	)
