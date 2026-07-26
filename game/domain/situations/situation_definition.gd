## Static situation graph composed only from compiled definition values.
class_name SituationDefinition
extends RefCounted

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

var id: StringName
var display_name_key: StringName
var initial_phase: StringName
var clock_definitions: Array[ClockDefinition]
var phase_definitions: Array[SituationPhaseDefinition]
var problem_definitions: Array[WorldProblemDefinition]
var trigger_rules: Array[WorldRule]
var passive_weekly_effects: Array[ClockDelta]
var ending_definitions: Array[EndingDefinition]


static func create(
	p_id: StringName,
	p_display_name_key: StringName,
	p_initial_phase: StringName,
	p_clock_definitions: Array[ClockDefinition],
	p_phase_definitions: Array[SituationPhaseDefinition],
	p_problem_definitions: Array[WorldProblemDefinition],
	p_trigger_rules: Array[WorldRule],
	p_passive_weekly_effects: Array[ClockDelta],
	p_ending_definitions: Array[EndingDefinition]
) -> SituationDefinition:
	return SituationDefinition.new(
		p_id, p_display_name_key, p_initial_phase, p_clock_definitions,
		p_phase_definitions, p_problem_definitions, p_trigger_rules,
		p_passive_weekly_effects, p_ending_definitions
	)


func _init(
	p_id: StringName,
	p_display_name_key: StringName,
	p_initial_phase: StringName,
	p_clock_definitions: Array[ClockDefinition],
	p_phase_definitions: Array[SituationPhaseDefinition],
	p_problem_definitions: Array[WorldProblemDefinition],
	p_trigger_rules: Array[WorldRule],
	p_passive_weekly_effects: Array[ClockDelta],
	p_ending_definitions: Array[EndingDefinition]
) -> void:
	id = p_id
	display_name_key = p_display_name_key
	initial_phase = p_initial_phase
	for definition: ClockDefinition in p_clock_definitions:
		clock_definitions.append(definition.duplicate_value() if definition != null else null)
	for definition: SituationPhaseDefinition in p_phase_definitions:
		phase_definitions.append(definition.duplicate_value() if definition != null else null)
	for definition: WorldProblemDefinition in p_problem_definitions:
		problem_definitions.append(definition.duplicate_value() if definition != null else null)
	for rule: WorldRule in p_trigger_rules:
		trigger_rules.append(rule.duplicate_value() if rule != null else null)
	for effect: ClockDelta in p_passive_weekly_effects:
		passive_weekly_effects.append(effect.duplicate_value() if effect != null else null)
	for definition: EndingDefinition in p_ending_definitions:
		ending_definitions.append(definition.duplicate_value() if definition != null else null)


func duplicate_value() -> SituationDefinition:
	return SituationDefinition.new(
		id, display_name_key, initial_phase, clock_definitions, phase_definitions,
		problem_definitions, trigger_rules, passive_weekly_effects, ending_definitions
	)
