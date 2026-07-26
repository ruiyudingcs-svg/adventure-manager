## Inspector authoring Resource for one persistent world problem.
class_name WorldProblemDefinitionResource
extends Resource

const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const ProblemUrgencyRuleResource = preload(
	"res://game/data/definitions/situations/problem_urgency_rule_resource.gd"
)
const WorldRuleResource = preload(
	"res://game/data/definitions/situations/world_rule_resource.gd"
)
const WorldEffectResource = preload(
	"res://game/data/definitions/contracts/world_effect_resource.gd"
)
const ProblemUrgencyRule = preload(
	"res://game/domain/situations/problem_urgency_rule.gd"
)
const WorldRule = preload("res://game/domain/situations/world_rule.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

@export var id: StringName
@export var title_key: StringName
@export var description_key: StringName
@export var problem_tags: Array[StringName] = []
@export_range(0, 100) var base_urgency: int = 0
@export var age_urgency_per_week: int = 0
@export var age_urgency_cap: int = 0
@export var response_window_weeks: int = -1
@export var urgency_rules: Array[ProblemUrgencyRuleResource] = []
@export var activation_rules: Array[WorldRuleResource] = []
@export var resolution_rules: Array[WorldRuleResource] = []
@export var related_clock_ids: Array[StringName] = []
@export var contract_definition_ids: Array[StringName] = []
@export var escalation_effects: Array[WorldEffectResource] = []


## Deep-compiles one persistent world-problem definition.
func compile() -> WorldProblemDefinition:
	var compiled_urgency: Array[ProblemUrgencyRule] = []
	var compiled_activation: Array[WorldRule] = []
	var compiled_resolution: Array[WorldRule] = []
	var compiled_escalation: Array[WorldEffect] = []
	for rule: ProblemUrgencyRuleResource in urgency_rules:
		if rule == null:
			return null
		compiled_urgency.append(rule.compile())
	for rule: WorldRuleResource in activation_rules:
		if rule == null:
			return null
		compiled_activation.append(rule.compile())
	for rule: WorldRuleResource in resolution_rules:
		if rule == null:
			return null
		compiled_resolution.append(rule.compile())
	for effect: WorldEffectResource in escalation_effects:
		if effect == null:
			return null
		compiled_escalation.append(effect.compile())
	return WorldProblemDefinition.create(
		id, title_key, description_key, problem_tags, base_urgency,
		age_urgency_per_week, age_urgency_cap, response_window_weeks,
		compiled_urgency, compiled_activation, compiled_resolution, related_clock_ids,
		contract_definition_ids, compiled_escalation
	)
