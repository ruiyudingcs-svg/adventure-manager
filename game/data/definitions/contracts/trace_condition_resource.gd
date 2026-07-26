## Inspector authoring Resource for one clause trace predicate.
class_name TraceConditionResource
extends Resource

const TraceCondition = preload("res://game/domain/contracts/trace_condition.gd")

@export var type: StringName
@export var source_id: StringName
@export var key: StringName
@export var int_value: int = 0
@export var tag_value: StringName


## Compiles a structured trace predicate.
func compile() -> TraceCondition:
	return TraceCondition.create(type, source_id, key, int_value, tag_value)
