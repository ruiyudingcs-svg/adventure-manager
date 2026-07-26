## Immutable NPC faction action compiled from authoring Resources.
class_name FactionActionDefinition
extends RefCounted

const WorldCondition = preload(
	"res://game/domain/situations/world_condition.gd"
)
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

var id: StringName
var agenda_tags: Array[StringName]
var target_lock_key: StringName
var base_intent_priority: int
var urgency_weight: int
var recent_repeat_cooldown: int
var influence_cost: int
var conditions: Array[WorldCondition]
var target_problem_tags: Array[StringName]
var effects: Array[WorldEffect]
var event_key: StringName


static func create(
	p_id: StringName,
	p_agenda_tags: Array[StringName],
	p_target_lock_key: StringName,
	p_base_intent_priority: int,
	p_urgency_weight: int,
	p_recent_repeat_cooldown: int,
	p_influence_cost: int,
	p_conditions: Array[WorldCondition],
	p_target_problem_tags: Array[StringName],
	p_effects: Array[WorldEffect],
	p_event_key: StringName
) -> FactionActionDefinition:
	return FactionActionDefinition.new(
		p_id,
		p_agenda_tags,
		p_target_lock_key,
		p_base_intent_priority,
		p_urgency_weight,
		p_recent_repeat_cooldown,
		p_influence_cost,
		p_conditions,
		p_target_problem_tags,
		p_effects,
		p_event_key
	)


func _init(
	p_id: StringName,
	p_agenda_tags: Array[StringName],
	p_target_lock_key: StringName,
	p_base_intent_priority: int,
	p_urgency_weight: int,
	p_recent_repeat_cooldown: int,
	p_influence_cost: int,
	p_conditions: Array[WorldCondition],
	p_target_problem_tags: Array[StringName],
	p_effects: Array[WorldEffect],
	p_event_key: StringName
) -> void:
	id = p_id
	agenda_tags.append_array(p_agenda_tags)
	target_lock_key = p_target_lock_key
	base_intent_priority = p_base_intent_priority
	urgency_weight = p_urgency_weight
	recent_repeat_cooldown = p_recent_repeat_cooldown
	influence_cost = p_influence_cost
	for condition: WorldCondition in p_conditions:
		conditions.append(condition.duplicate_value() if condition != null else null)
	target_problem_tags.append_array(p_target_problem_tags)
	for effect: WorldEffect in p_effects:
		effects.append(effect.duplicate_value() if effect != null else null)
	event_key = p_event_key


func duplicate_value() -> FactionActionDefinition:
	return FactionActionDefinition.new(
		id,
		agenda_tags,
		target_lock_key,
		base_intent_priority,
		urgency_weight,
		recent_repeat_cooldown,
		influence_cost,
		conditions,
		target_problem_tags,
		effects,
		event_key
	)
