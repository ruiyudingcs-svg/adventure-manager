## Inspector authoring Resource for one problem urgency rule.
class_name ProblemUrgencyRuleResource
extends Resource

const ProblemUrgencyRule = preload(
	"res://game/domain/situations/problem_urgency_rule.gd"
)
const WorldConditionResource = preload(
	"res://game/data/definitions/situations/world_condition_resource.gd"
)
const WorldCondition = preload("res://game/domain/situations/world_condition.gd")

@export var id: StringName
@export var all_conditions: Array[WorldConditionResource] = []
@export var urgency_delta: int = 0
@export var reason_code: StringName
@export var visibility: StringName = &"player"
@export var priority: int = 0


## Deep-compiles one urgency rule.
func compile() -> ProblemUrgencyRule:
	var conditions: Array[WorldCondition] = []
	for condition: WorldConditionResource in all_conditions:
		if condition == null:
			return null
		conditions.append(condition.compile())
	return ProblemUrgencyRule.create(
		id,
		conditions,
		urgency_delta,
		reason_code,
		visibility,
		priority
	)
