## Inspector authoring Resource for one structured world predicate.
class_name WorldConditionResource
extends Resource

const WorldCondition = preload("res://game/domain/situations/world_condition.gd")

@export var type: StringName
@export var target_id: StringName
@export var int_value: int = 0


## Compiles a whitelisted world predicate record.
func compile() -> WorldCondition:
	return WorldCondition.create(type, target_id, int_value)
