## Static persistent world-problem template.
class_name WorldProblemDefinition
extends RefCounted

const ProblemUrgencyRule = preload(
	"res://game/domain/situations/problem_urgency_rule.gd"
)
const WorldRule = preload("res://game/domain/situations/world_rule.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

var id: StringName
var title_key: StringName
var description_key: StringName
var problem_tags: Array[StringName]
var base_urgency: int
var age_urgency_per_week: int
var age_urgency_cap: int
var response_window_weeks: int
var urgency_rules: Array[ProblemUrgencyRule]
var activation_rules: Array[WorldRule]
var resolution_rules: Array[WorldRule]
var related_clock_ids: Array[StringName]
var contract_definition_ids: Array[StringName]
var escalation_effects: Array[WorldEffect]


static func create(
	p_id: StringName,
	p_title_key: StringName,
	p_description_key: StringName,
	p_problem_tags: Array[StringName],
	p_base_urgency: int,
	p_age_urgency_per_week: int,
	p_age_urgency_cap: int,
	p_response_window_weeks: int,
	p_urgency_rules: Array[ProblemUrgencyRule],
	p_activation_rules: Array[WorldRule],
	p_resolution_rules: Array[WorldRule],
	p_related_clock_ids: Array[StringName],
	p_contract_definition_ids: Array[StringName],
	p_escalation_effects: Array[WorldEffect]
) -> WorldProblemDefinition:
	return WorldProblemDefinition.new(
		p_id, p_title_key, p_description_key, p_problem_tags, p_base_urgency,
		p_age_urgency_per_week, p_age_urgency_cap, p_response_window_weeks,
		p_urgency_rules, p_activation_rules, p_resolution_rules, p_related_clock_ids,
		p_contract_definition_ids, p_escalation_effects
	)


func _init(
	p_id: StringName,
	p_title_key: StringName,
	p_description_key: StringName,
	p_problem_tags: Array[StringName],
	p_base_urgency: int,
	p_age_urgency_per_week: int,
	p_age_urgency_cap: int,
	p_response_window_weeks: int,
	p_urgency_rules: Array[ProblemUrgencyRule],
	p_activation_rules: Array[WorldRule],
	p_resolution_rules: Array[WorldRule],
	p_related_clock_ids: Array[StringName],
	p_contract_definition_ids: Array[StringName],
	p_escalation_effects: Array[WorldEffect]
) -> void:
	id = p_id
	title_key = p_title_key
	description_key = p_description_key
	problem_tags.append_array(p_problem_tags)
	base_urgency = p_base_urgency
	age_urgency_per_week = p_age_urgency_per_week
	age_urgency_cap = p_age_urgency_cap
	response_window_weeks = p_response_window_weeks
	for rule: ProblemUrgencyRule in p_urgency_rules:
		urgency_rules.append(rule.duplicate_value() if rule != null else null)
	for rule: WorldRule in p_activation_rules:
		activation_rules.append(rule.duplicate_value() if rule != null else null)
	for rule: WorldRule in p_resolution_rules:
		resolution_rules.append(rule.duplicate_value() if rule != null else null)
	related_clock_ids.append_array(p_related_clock_ids)
	contract_definition_ids.append_array(p_contract_definition_ids)
	for effect: WorldEffect in p_escalation_effects:
		escalation_effects.append(effect.duplicate_value() if effect != null else null)


func duplicate_value() -> WorldProblemDefinition:
	return WorldProblemDefinition.new(
		id, title_key, description_key, problem_tags, base_urgency,
		age_urgency_per_week, age_urgency_cap, response_window_weeks, urgency_rules,
		activation_rules, resolution_rules, related_clock_ids, contract_definition_ids,
		escalation_effects
	)
