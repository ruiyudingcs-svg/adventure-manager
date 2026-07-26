## Inspector authoring Resource for one bounded situation clock.
class_name ClockDefinitionResource
extends Resource

const ClockDefinition = preload(
	"res://game/domain/situations/clock_definition.gd"
)

@export var id: StringName
@export var display_name_key: StringName
@export var min_value: int = 0
@export var max_value: int = 100
@export var initial_value: int = 0
@export var visibility: StringName = &"player"


## Compiles a clock definition with no shared mutable state.
func compile() -> ClockDefinition:
	return ClockDefinition.create(
		id,
		display_name_key,
		min_value,
		max_value,
		initial_value,
		visibility
	)
