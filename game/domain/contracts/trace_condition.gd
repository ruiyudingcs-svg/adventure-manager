class_name TraceCondition
extends RefCounted

const TYPES: Array[StringName] = [
	&"selected_supply_tag_present",
	&"selected_supply_tag_absent",
	&"approach_is",
	&"method_tag_used",
	&"method_tag_not_used",
	&"outcome_tag_present",
	&"outcome_tag_absent",
	&"check_tier_gte",
	&"check_tier_lte",
	&"context_gte",
	&"context_lte",
	&"member_heavy_injury_count_lte",
]

var type: StringName
var source_id: StringName
var key: StringName
var int_value: int
var tag_value: StringName


static func create(
	p_type: StringName,
	p_source_id: StringName = &"",
	p_key: StringName = &"",
	p_int_value: int = 0,
	p_tag_value: StringName = &""
) -> TraceCondition:
	return TraceCondition.new(p_type, p_source_id, p_key, p_int_value, p_tag_value)


func _init(
	p_type: StringName,
	p_source_id: StringName,
	p_key: StringName,
	p_int_value: int,
	p_tag_value: StringName
) -> void:
	type = p_type
	source_id = p_source_id
	key = p_key
	int_value = p_int_value
	tag_value = p_tag_value


func duplicate_value() -> TraceCondition:
	return TraceCondition.new(type, source_id, key, int_value, tag_value)
