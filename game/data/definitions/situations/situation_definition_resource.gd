## Inspector authoring Resource for one complete static situation graph.
class_name SituationDefinitionResource
extends Resource

const SituationDefinition = preload(
	"res://game/domain/situations/situation_definition.gd"
)
const ClockDefinitionResource = preload(
	"res://game/data/definitions/situations/clock_definition_resource.gd"
)
const SituationPhaseDefinitionResource = preload(
	"res://game/data/definitions/situations/situation_phase_definition_resource.gd"
)
const WorldProblemDefinitionResource = preload(
	"res://game/data/definitions/situations/world_problem_definition_resource.gd"
)
const WorldRuleResource = preload(
	"res://game/data/definitions/situations/world_rule_resource.gd"
)
const ClockDeltaResource = preload(
	"res://game/data/definitions/situations/clock_delta_resource.gd"
)
const EndingDefinitionResource = preload(
	"res://game/data/definitions/situations/ending_definition_resource.gd"
)
const ClockDefinition = preload("res://game/domain/situations/clock_definition.gd")
const SituationPhaseDefinition = preload(
	"res://game/domain/situations/situation_phase_definition.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const WorldRule = preload("res://game/domain/situations/world_rule.gd")
const ClockDelta = preload("res://game/domain/situations/clock_delta.gd")
const EndingDefinition = preload("res://game/domain/situations/ending_definition.gd")

@export var id: StringName
@export var display_name_key: StringName
@export var initial_phase: StringName
@export var clock_definitions: Array[ClockDefinitionResource] = []
@export var phase_definitions: Array[SituationPhaseDefinitionResource] = []
@export var problem_definitions: Array[WorldProblemDefinitionResource] = []
@export var trigger_rules: Array[WorldRuleResource] = []
@export var passive_weekly_effects: Array[ClockDeltaResource] = []
@export var ending_definitions: Array[EndingDefinitionResource] = []


## Deep-compiles the complete static situation graph.
func compile() -> SituationDefinition:
	var clocks: Array[ClockDefinition] = []
	var phases: Array[SituationPhaseDefinition] = []
	var problems: Array[WorldProblemDefinition] = []
	var triggers: Array[WorldRule] = []
	var passive: Array[ClockDelta] = []
	var endings: Array[EndingDefinition] = []
	for definition: ClockDefinitionResource in clock_definitions:
		if definition == null:
			return null
		clocks.append(definition.compile())
	for definition: SituationPhaseDefinitionResource in phase_definitions:
		if definition == null:
			return null
		phases.append(definition.compile())
	for definition: WorldProblemDefinitionResource in problem_definitions:
		if definition == null:
			return null
		problems.append(definition.compile())
	for rule: WorldRuleResource in trigger_rules:
		if rule == null:
			return null
		triggers.append(rule.compile())
	for effect: ClockDeltaResource in passive_weekly_effects:
		if effect == null:
			return null
		passive.append(effect.compile())
	for definition: EndingDefinitionResource in ending_definitions:
		if definition == null:
			return null
		endings.append(definition.compile())
	return SituationDefinition.create(
		id,
		display_name_key,
		initial_phase,
		clocks,
		phases,
		problems,
		triggers,
		passive,
		endings
	)
