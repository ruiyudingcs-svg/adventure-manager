extends RefCounted

const ContentManifest = preload("res://game/data/catalogs/content_manifest.gd")
const AdventurerDefinitionResource = preload(
	"res://game/data/definitions/adventurers/adventurer_definition_resource.gd"
)
const CapabilityBlockResource = preload(
	"res://game/data/definitions/adventurers/capability_block_resource.gd"
)
const IdeologyVectorResource = preload(
	"res://game/data/definitions/adventurers/ideology_vector_resource.gd"
)
const TraitDefinitionResource = preload(
	"res://game/data/definitions/adventurers/trait_definition_resource.gd"
)
const MethodTagDefinitionResource = preload(
	"res://game/data/definitions/contracts/method_tag_definition_resource.gd"
)
const SupplyDefinitionResource = preload(
	"res://game/data/definitions/contracts/supply_definition_resource.gd"
)
const ConditionalModifierResource = preload(
	"res://game/data/definitions/contracts/conditional_modifier_resource.gd"
)
const ContractClauseDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_clause_definition_resource.gd"
)
const ContractEffectResource = preload(
	"res://game/data/definitions/contracts/contract_effect_resource.gd"
)
const FactionDefinitionResource = preload(
	"res://game/data/definitions/factions/faction_definition_resource.gd"
)
const FactionActionDefinitionResource = preload(
	"res://game/data/definitions/factions/faction_action_definition_resource.gd"
)
const ContractDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_definition_resource.gd"
)
const ContractStageDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_stage_definition_resource.gd"
)
const ContractCheckDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_check_definition_resource.gd"
)
const CapabilityWeightsResource = preload(
	"res://game/data/definitions/contracts/capability_weights_resource.gd"
)
const CheckOutcomeTableResource = preload(
	"res://game/data/definitions/contracts/check_outcome_table_resource.gd"
)
const CheckOutcomeDefinitionResource = preload(
	"res://game/data/definitions/contracts/check_outcome_definition_resource.gd"
)
const MissionContextDeltaResource = preload(
	"res://game/data/definitions/contracts/mission_context_delta_resource.gd"
)
const ContractOutcomeTableResource = preload(
	"res://game/data/definitions/contracts/contract_outcome_table_resource.gd"
)
const ContractOutcomeDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_outcome_definition_resource.gd"
)
const WorldRuleResource = preload(
	"res://game/data/definitions/situations/world_rule_resource.gd"
)
const WorldConditionResource = preload(
	"res://game/data/definitions/situations/world_condition_resource.gd"
)
const WorldEffectResource = preload(
	"res://game/data/definitions/contracts/world_effect_resource.gd"
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
const EndingDefinitionResource = preload(
	"res://game/data/definitions/situations/ending_definition_resource.gd"
)
const SituationDefinitionResource = preload(
	"res://game/data/definitions/situations/situation_definition_resource.gd"
)


static func create_valid_manifest() -> ContentManifest:
	var manifest := ContentManifest.new()
	manifest.trait_definitions.append(_trait())
	manifest.method_tag_definitions.append(_method_tag())
	manifest.supply_definitions.append(_supply())
	manifest.contract_clause_definitions.append(_clause())
	manifest.faction_definitions.append(_faction())
	manifest.faction_action_definitions.append(_faction_action())

	var contract := _contract()
	manifest.contract_definitions.append(contract)
	manifest.adventurer_definitions.append(_adventurer(&"hero_zeta", "Zeta"))
	manifest.adventurer_definitions.append(_adventurer(&"hero_alpha", "Alpha"))

	var clock := _clock()
	var phases: Array[SituationPhaseDefinitionResource] = [
		_phase(&"phase_early", 0, false),
		_phase(&"phase_middle", 1, false),
		_phase(&"phase_late", 2, false),
		_phase(&"phase_terminal", 3, true),
	]
	var problem := _problem(contract.id, clock.id)
	var ending := _ending()
	manifest.clock_definitions.append(clock)
	manifest.phase_definitions.append_array(phases)
	manifest.problem_definitions.append(problem)
	manifest.ending_definitions.append(ending)
	manifest.situation_definitions.append(_situation(clock, phases, problem, ending))
	return manifest


static func _adventurer(id: StringName, display_name: String) -> AdventurerDefinitionResource:
	var resource := AdventurerDefinitionResource.new()
	resource.id = id
	resource.display_name = display_name
	resource.class_id = &"vanguard"
	resource.base_capabilities = CapabilityBlockResource.new()
	resource.base_capabilities.frontline = 60
	resource.base_capabilities.offense = 50
	resource.base_capabilities.scouting = 40
	resource.base_capabilities.support = 30
	resource.base_capabilities.arcana = 20
	resource.base_capabilities.discipline = 50
	resource.traits = [&"cautious"]
	resource.values = _vector(false)
	resource.wage = 10
	return resource


static func _trait() -> TraitDefinitionResource:
	var resource := TraitDefinitionResource.new()
	resource.id = &"cautious"
	resource.display_name_key = &"trait.cautious.name"
	resource.description_key = &"trait.cautious.description"
	return resource


static func _method_tag() -> MethodTagDefinitionResource:
	var resource := MethodTagDefinitionResource.new()
	resource.id = &"scouting"
	resource.ideology_vector = _vector(false)
	resource.taboo_intensity = 0
	return resource


static func _supply() -> SupplyDefinitionResource:
	var resource := SupplyDefinitionResource.new()
	resource.id = &"supply_scouting"
	resource.display_name_key = &"supply.scouting"
	resource.cost = 5
	resource.tags = [&"scouting"]
	var modifier := ConditionalModifierResource.new()
	modifier.target_type = &"check"
	modifier.match_tag = &"navigation"
	modifier.amount = 5
	modifier.reason_code = &"supply_scouting"
	resource.modifiers.append(modifier)
	return resource


static func _clause() -> ContractClauseDefinitionResource:
	var resource := ContractClauseDefinitionResource.new()
	resource.id = &"clause_test"
	resource.category = &"target_state"
	resource.importance = &"mandatory"
	resource.success_ideology_impact = _vector(true)
	resource.failure_ideology_impact = _vector(true)
	return resource


static func _faction() -> FactionDefinitionResource:
	var resource := FactionDefinitionResource.new()
	resource.id = &"faction_test"
	resource.display_name_key = &"faction.test"
	resource.preferred_ideology = _vector(false)
	resource.weekly_action_ids = [&"action_test"]
	return resource


static func _faction_action() -> FactionActionDefinitionResource:
	var resource := FactionActionDefinitionResource.new()
	resource.id = &"action_test"
	resource.agenda_tags = [&"test_agenda"]
	resource.target_lock_key = &"action.test"
	resource.base_intent_priority = 10
	resource.urgency_weight = 20
	resource.recent_repeat_cooldown = 2
	resource.influence_cost = 5
	resource.target_problem_tags = [&"test_problem"]
	resource.event_key = &"event_action_test"
	var condition := WorldConditionResource.new()
	condition.type = &"problem_is_active"
	condition.target_id = &"problem_test"
	resource.conditions.append(condition)
	var effect := WorldEffectResource.new()
	effect.type = &"modify_clock"
	effect.target_id = &"clock_test"
	effect.amount = 3
	effect.reason_code = &"action_test_clock"
	resource.effects.append(effect)
	return resource


static func _contract() -> ContractDefinitionResource:
	var resource := ContractDefinitionResource.new()
	resource.id = &"contract_test"
	resource.title_key = &"contract.test.title"
	resource.description_key = &"contract.test.description"
	resource.sponsor_faction_id = &"faction_test"
	resource.related_problem_id = &"problem_test"
	resource.target_lock_key = &"target_test"
	resource.repeat_policy = &"repeatable"
	resource.base_reward = 100
	resource.base_fatigue = 8
	resource.risk_level = 2
	resource.offer_duration_weeks = 1
	resource.intent_ideology_vector = _vector(true)
	resource.expected_method_tags = [&"scouting"]
	resource.clause_ids = [&"clause_test"]
	resource.allowed_supply_tags = [&"scouting"]
	var phases: Array[StringName] = [
		&"approach", &"main_action", &"special_objective", &"extraction"
	]
	var types: Array[StringName] = [
		&"navigation", &"reconnaissance", &"protection", &"extraction"
	]
	for index: int in range(phases.size()):
		resource.stages.append(_stage(index, phases[index], types[index]))
	resource.final_outcome_table = _contract_outcomes()
	var availability := WorldRuleResource.new()
	availability.id = &"contract_test_available"
	var condition := WorldConditionResource.new()
	condition.type = &"phase_is"
	condition.target_id = &"phase_early"
	availability.all_conditions.append(condition)
	resource.availability_rules.append(availability)
	resource.unhandled_policy = &"expire"
	return resource


static func _stage(
	index: int,
	phase: StringName,
	check_type: StringName
) -> ContractStageDefinitionResource:
	var stage := ContractStageDefinitionResource.new()
	stage.id = StringName("stage_%d" % index)
	stage.phase = phase
	var check := ContractCheckDefinitionResource.new()
	check.id = StringName("check_%d" % index)
	check.check_type = check_type
	check.difficulty = 20 + index
	check.result_weight = 0.25
	check.approach_profile = &"careful"
	check.method_tags = [&"scouting"]
	check.capability_weights = CapabilityWeightsResource.new()
	check.capability_weights.frontline = 0.5
	check.capability_weights.offense = 0.5
	check.outcome_table = _check_outcomes()
	stage.check = check
	return stage


static func _check_outcomes() -> CheckOutcomeTableResource:
	var table := CheckOutcomeTableResource.new()
	table.exceptional = _check_outcome()
	table.success = _check_outcome()
	table.partial = _check_outcome()
	table.failure = _check_outcome()
	table.severe = _check_outcome()
	return table


static func _check_outcome() -> CheckOutcomeDefinitionResource:
	var outcome := CheckOutcomeDefinitionResource.new()
	outcome.ideology_impact = _vector(true)
	var delta := MissionContextDeltaResource.new()
	delta.key = &"intel"
	delta.amount = 1
	delta.source_id = &"fixture_intel"
	outcome.context_deltas.append(delta)
	return outcome


static func _contract_outcomes() -> ContractOutcomeTableResource:
	var table := ContractOutcomeTableResource.new()
	table.exceptional = _contract_outcome(1.25, 0.8, -10, 5)
	table.success = _contract_outcome(1.0, 1.0, -5, 3)
	table.partial = _contract_outcome(0.75, 1.1, 0, 0)
	table.failure = _contract_outcome(0.4, 1.3, 10, -5)
	table.severe = _contract_outcome(0.0, 1.5, 20, -10)
	return table


static func _contract_outcome(
	reward: float,
	fatigue: float,
	injury: int,
	relation: int
) -> ContractOutcomeDefinitionResource:
	var outcome := ContractOutcomeDefinitionResource.new()
	outcome.reward_multiplier = reward
	outcome.fatigue_multiplier = fatigue
	outcome.injury_risk_modifier = injury
	outcome.sponsor_relation_delta = relation
	return outcome


static func _clock() -> ClockDefinitionResource:
	var resource := ClockDefinitionResource.new()
	resource.id = &"clock_test"
	resource.display_name_key = &"clock.test"
	resource.initial_value = 10
	return resource


static func _phase(
	id: StringName,
	sort_order: int,
	terminal: bool
) -> SituationPhaseDefinitionResource:
	var resource := SituationPhaseDefinitionResource.new()
	resource.id = id
	resource.display_name_key = StringName("%s.name" % id)
	resource.sort_order = sort_order
	resource.is_terminal = terminal
	return resource


static func _problem(
	contract_id: StringName,
	clock_id: StringName
) -> WorldProblemDefinitionResource:
	var resource := WorldProblemDefinitionResource.new()
	resource.id = &"problem_test"
	resource.title_key = &"problem.test.title"
	resource.problem_tags = [&"test_problem"]
	resource.base_urgency = 20
	resource.age_urgency_per_week = 2
	resource.age_urgency_cap = 20
	resource.response_window_weeks = 3
	resource.related_clock_ids = [clock_id]
	resource.contract_definition_ids = [contract_id]
	var escalation_event := WorldEffectResource.new()
	escalation_event.type = &"create_world_event"
	escalation_event.target_id = &"event_problem_test_escalated"
	escalation_event.reason_code = &"problem_test_escalated"
	resource.escalation_effects.append(escalation_event)
	return resource


static func _ending() -> EndingDefinitionResource:
	var resource := EndingDefinitionResource.new()
	resource.id = &"ending_test"
	resource.display_name_key = &"ending.test"
	resource.priority = 1
	return resource


static func _situation(
	clock: ClockDefinitionResource,
	phases: Array[SituationPhaseDefinitionResource],
	problem: WorldProblemDefinitionResource,
	ending: EndingDefinitionResource
) -> SituationDefinitionResource:
	var resource := SituationDefinitionResource.new()
	resource.id = &"situation_test"
	resource.display_name_key = &"situation.test"
	resource.initial_phase = &"phase_early"
	resource.clock_definitions.append(clock)
	resource.phase_definitions.append_array(phases)
	resource.problem_definitions.append(problem)
	resource.ending_definitions.append(ending)
	return resource


static func _vector(task: bool) -> IdeologyVectorResource:
	var resource := IdeologyVectorResource.new()
	resource.task_accumulation = task
	return resource
