## Inspector authoring Resource for one ending candidate.
class_name EndingDefinitionResource
extends Resource

const EndingDefinition = preload(
	"res://game/domain/situations/ending_definition.gd"
)
const WorldConditionResource = preload(
	"res://game/data/definitions/situations/world_condition_resource.gd"
)
const WorldCondition = preload("res://game/domain/situations/world_condition.gd")

@export var id: StringName
@export var display_name_key: StringName
@export var description_key: StringName
@export var priority: int = 0
@export var all_conditions: Array[WorldConditionResource] = []
@export var any_conditions: Array[WorldConditionResource] = []


## Deep-compiles an ending predicate graph without selecting an ending.
func compile() -> EndingDefinition:
	var all_compiled: Array[WorldCondition] = []
	var any_compiled: Array[WorldCondition] = []
	for condition: WorldConditionResource in all_conditions:
		if condition == null:
			return null
		all_compiled.append(condition.compile())
	for condition: WorldConditionResource in any_conditions:
		if condition == null:
			return null
		any_compiled.append(condition.compile())
	return EndingDefinition.create(
		id,
		display_name_key,
		description_key,
		priority,
		all_compiled,
		any_compiled
	)
