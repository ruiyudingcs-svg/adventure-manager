## Static group of structured world predicates and effects.
class_name WorldRule
extends RefCounted

const WorldCondition = preload("res://game/domain/situations/world_condition.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

var id: StringName
var all_conditions: Array[WorldCondition]
var any_conditions: Array[WorldCondition]
var effects: Array[WorldEffect]
var once: bool
var priority: int


static func create(
	p_id: StringName,
	p_all_conditions: Array[WorldCondition],
	p_any_conditions: Array[WorldCondition],
	p_effects: Array[WorldEffect],
	p_once: bool,
	p_priority: int
) -> WorldRule:
	return WorldRule.new(
		p_id,
		p_all_conditions,
		p_any_conditions,
		p_effects,
		p_once,
		p_priority
	)


func _init(
	p_id: StringName,
	p_all_conditions: Array[WorldCondition],
	p_any_conditions: Array[WorldCondition],
	p_effects: Array[WorldEffect],
	p_once: bool,
	p_priority: int
) -> void:
	id = p_id
	for condition: WorldCondition in p_all_conditions:
		all_conditions.append(condition.duplicate_value() if condition != null else null)
	for condition: WorldCondition in p_any_conditions:
		any_conditions.append(condition.duplicate_value() if condition != null else null)
	for effect: WorldEffect in p_effects:
		effects.append(effect.duplicate_value() if effect != null else null)
	once = p_once
	priority = p_priority


func duplicate_value() -> WorldRule:
	return WorldRule.new(id, all_conditions, any_conditions, effects, once, priority)
