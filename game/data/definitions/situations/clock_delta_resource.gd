## Inspector authoring Resource for one passive clock delta.
class_name ClockDeltaResource
extends Resource

const ClockDelta = preload("res://game/domain/situations/clock_delta.gd")

@export var clock_id: StringName
@export var amount: int = 0
@export var reason_code: StringName


## Compiles one passive clock delta.
func compile() -> ClockDelta:
	return ClockDelta.create(clock_id, amount, reason_code)
