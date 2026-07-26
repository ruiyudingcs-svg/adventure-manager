## Inspector authoring Resource for one reasoned MissionContext delta.
class_name MissionContextDeltaResource
extends Resource

@export var key: StringName
@export var amount: int = 0
@export var source_id: StringName


## Compiles the typed authoring fields to the Task 003 runtime delta shape.
func compile() -> Dictionary:
	return {
		"key": key,
		"amount": amount,
		"source_id": source_id,
	}
