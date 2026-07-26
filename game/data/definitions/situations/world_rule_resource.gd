## Inspector authoring Resource for one structured world rule.
class_name WorldRuleResource
extends Resource

const WorldRule = preload("res://game/domain/situations/world_rule.gd")
const WorldConditionResource = preload(
	"res://game/data/definitions/situations/world_condition_resource.gd"
)
const WorldEffectResource = preload(
	"res://game/data/definitions/contracts/world_effect_resource.gd"
)
const WorldCondition = preload("res://game/domain/situations/world_condition.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

@export var id: StringName
@export var all_conditions: Array[WorldConditionResource] = []
@export var any_conditions: Array[WorldConditionResource] = []
@export var effects: Array[WorldEffectResource] = []
@export var once: bool = false
@export var priority: int = 0


## Deep-compiles a structured world rule without evaluating it.
func compile() -> WorldRule:
	var all_compiled: Array[WorldCondition] = []
	var any_compiled: Array[WorldCondition] = []
	var effects_compiled: Array[WorldEffect] = []
	for condition: WorldConditionResource in all_conditions:
		if condition == null:
			return null
		all_compiled.append(condition.compile())
	for condition: WorldConditionResource in any_conditions:
		if condition == null:
			return null
		any_compiled.append(condition.compile())
	for effect: WorldEffectResource in effects:
		if effect == null:
			return null
		effects_compiled.append(effect.compile())
	return WorldRule.create(
		id,
		all_compiled,
		any_compiled,
		effects_compiled,
		once,
		priority
	)
