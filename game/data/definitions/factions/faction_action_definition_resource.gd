## Inspector authoring Resource for one deterministic faction action.
class_name FactionActionDefinitionResource
extends Resource

const FactionActionDefinition = preload(
	"res://game/domain/factions/faction_action_definition.gd"
)
const WorldConditionResource = preload(
	"res://game/data/definitions/situations/world_condition_resource.gd"
)
const WorldEffectResource = preload(
	"res://game/data/definitions/contracts/world_effect_resource.gd"
)
const WorldCondition = preload(
	"res://game/domain/situations/world_condition.gd"
)
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

@export var id: StringName
@export var agenda_tags: Array[StringName] = []
@export var target_lock_key: StringName
@export_range(0, 20) var base_intent_priority: int = 0
@export_range(0, 40) var urgency_weight: int = 0
@export_range(0, 20) var recent_repeat_cooldown: int = 0
@export_range(0, 100) var influence_cost: int = 0
@export var conditions: Array[WorldConditionResource] = []
@export var target_problem_tags: Array[StringName] = []
@export var effects: Array[WorldEffectResource] = []
@export var event_key: StringName


## Deep-compiles action predicates and effects at the catalog boundary.
func compile() -> FactionActionDefinition:
	var compiled_conditions: Array[WorldCondition] = []
	var compiled_effects: Array[WorldEffect] = []
	for condition: WorldConditionResource in conditions:
		if condition == null:
			return null
		compiled_conditions.append(condition.compile())
	for effect: WorldEffectResource in effects:
		if effect == null:
			return null
		compiled_effects.append(effect.compile())
	return FactionActionDefinition.create(
		id,
		agenda_tags,
		target_lock_key,
		base_intent_priority,
		urgency_weight,
		recent_repeat_cooldown,
		influence_cost,
		compiled_conditions,
		target_problem_tags,
		compiled_effects,
		event_key
	)
