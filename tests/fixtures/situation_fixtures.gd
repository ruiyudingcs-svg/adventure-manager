class_name SituationFixtures
extends RefCounted

const ClockDefinition = preload(
	"res://game/domain/situations/clock_definition.gd"
)
const ClockDelta = preload("res://game/domain/situations/clock_delta.gd")
const SituationPhaseDefinition = preload(
	"res://game/domain/situations/situation_phase_definition.gd"
)
const SituationDefinition = preload(
	"res://game/domain/situations/situation_definition.gd"
)
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const ProblemUrgencyRule = preload(
	"res://game/domain/situations/problem_urgency_rule.gd"
)
const WorldRule = preload("res://game/domain/situations/world_rule.gd")
const WorldCondition = preload(
	"res://game/domain/situations/world_condition.gd"
)
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const EndingDefinition = preload(
	"res://game/domain/situations/ending_definition.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const CampaignState = preload(
	"res://game/domain/campaign/campaign_state.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)

const SITUATION_ID: StringName = &"situation_task008_fixture"
const PROBLEM_ID: StringName = &"problem_timed_pressure"


static func create_definition(
	triggers: Array[WorldRule] = [],
	endings: Array[EndingDefinition] = [],
	problems: Array[WorldProblemDefinition] = []
) -> SituationDefinition:
	var effective_problems: Array[WorldProblemDefinition] = problems
	if effective_problems.is_empty():
		effective_problems = [create_problem_definition()]
	var clocks: Array[ClockDefinition] = [
		_clock(&"villagers_evacuated", 5),
		_clock(&"settlement_destruction", 10),
		_clock(&"dragon_exhaustion", 15),
		_clock(&"capture_preparation", 0),
		_clock(&"necrotic_corruption", 5),
	]
	var phases: Array[SituationPhaseDefinition] = [
		_phase(&"phase_early_crisis", 0, false),
		_phase(&"phase_open_conflict", 1, false),
		_phase(&"phase_final_window", 2, false),
		_phase(&"phase_ended", 3, true),
	]
	var passive: Array[ClockDelta] = [
		ClockDelta.create(
			&"settlement_destruction",
			4,
			&"clock_passive_dragon_raids"
		),
		ClockDelta.create(
			&"dragon_exhaustion",
			-2,
			&"clock_passive_dragon_recovery"
		),
		ClockDelta.create(
			&"necrotic_corruption",
			2,
			&"clock_passive_necrotic_seepage"
		),
	]
	return SituationDefinition.create(
		SITUATION_ID,
		&"situation.task008",
		&"phase_early_crisis",
		clocks,
		phases,
		effective_problems,
		triggers,
		passive,
		endings
	)


static func create_problem_definition(
	base_urgency: int = 20,
	age_per_week: int = 8,
	age_cap: int = 16,
	response_window: int = 3,
	urgency_rules: Array[ProblemUrgencyRule] = [],
	activation_rules: Array[WorldRule] = [],
	resolution_rules: Array[WorldRule] = []
) -> WorldProblemDefinition:
	var effective_urgency_rules: Array[ProblemUrgencyRule] = urgency_rules
	if effective_urgency_rules.is_empty():
		effective_urgency_rules = [
			ProblemUrgencyRule.create(
				&"urgency_destruction_pressure",
				[condition(&"clock_gte", &"settlement_destruction", 30)],
				20,
				&"urgency_destruction_pressure",
				&"player",
				20
			),
			ProblemUrgencyRule.create(
				&"urgency_final_phase",
				[condition(&"phase_is", &"phase_final_window")],
				10,
				&"urgency_final_phase",
				&"player",
				10
			),
		]
	var effective_activation: Array[WorldRule] = activation_rules
	if effective_activation.is_empty():
		effective_activation = [
			rule(
				&"activate_timed_pressure",
				[condition(&"clock_gte", &"settlement_destruction", 30)]
			),
		]
	var effective_resolution: Array[WorldRule] = resolution_rules
	if effective_resolution.is_empty():
		effective_resolution = [
			rule(
				&"resolve_timed_pressure",
				[condition(
					&"world_event_occurred",
					&"event_timed_pressure_resolved"
				)]
			),
		]
	var escalation: Array[WorldEffect] = [
		effect(
			&"create_world_event",
			&"event_timed_pressure_escalated",
			0,
			&"problem_timed_pressure_escalated"
		),
		effect(
			&"modify_clock",
			&"settlement_destruction",
			12,
			&"problem_timed_pressure_destruction"
		),
	]
	return WorldProblemDefinition.create(
		PROBLEM_ID,
		&"problem.timed.title",
		&"problem.timed.description",
		[&"timed_pressure"],
		base_urgency,
		age_per_week,
		age_cap,
		response_window,
		effective_urgency_rules,
		effective_activation,
		effective_resolution,
		[&"settlement_destruction"],
		[],
		escalation
	)


static func create_state(
	problem_status: StringName = WorldProblemState.STATUS_INACTIVE,
	opened_week: int = -1,
	deadline_week: int = -1,
	clock_overrides: Dictionary = {},
	phase_id: StringName = &"phase_early_crisis",
	triggered_ids: Array[StringName] = [],
	ending_id: StringName = &""
) -> SituationState:
	var clocks: Dictionary[StringName, int] = {
		&"villagers_evacuated": 5,
		&"settlement_destruction": 10,
		&"dragon_exhaustion": 15,
		&"capture_preparation": 0,
		&"necrotic_corruption": 5,
	}
	for clock_id: StringName in clock_overrides:
		clocks[clock_id] = int(clock_overrides[clock_id])
	var closed_week: int = -1
	if [
		WorldProblemState.STATUS_RESOLVED,
		WorldProblemState.STATUS_ESCALATED,
		WorldProblemState.STATUS_CLOSED,
	].has(problem_status):
		closed_week = maxi(opened_week, 1)
	var problems: Dictionary[StringName, WorldProblemState] = {
		PROBLEM_ID: WorldProblemState.create(
			PROBLEM_ID,
			problem_status,
			opened_week,
			deadline_week,
			closed_week
		),
	}
	return SituationState.create(
		SITUATION_ID,
		phase_id,
		clocks,
		triggered_ids,
		[],
		problems,
		ending_id
	)


static func create_campaign(
	week: int,
	situation_state: SituationState,
	world_events: Array[WorldEventState] = []
) -> CampaignState:
	var base: CampaignState = CampaignStateFixtures.create_baseline_state()
	return CampaignState.create(
		base.campaign_seed,
		week,
		base.guild,
		base.adventurers,
		base.factions,
		situation_state,
		[],
		world_events
	)


static func accepted_phase_triggers() -> Array[WorldRule]:
	return [
		rule(
			&"trigger_phase_open_conflict",
			[
				condition(&"phase_is", &"phase_early_crisis"),
				condition(&"week_gte", &"", 5),
			],
			[],
			[
				effect(
					&"change_phase",
					&"phase_open_conflict",
					0,
					&"phase_open_conflict_started"
				),
			],
			true,
			100
		),
		rule(
			&"trigger_phase_final_window",
			[
				condition(&"phase_is", &"phase_open_conflict"),
				condition(&"week_gte", &"", 9),
			],
			[],
			[
				effect(
					&"change_phase",
					&"phase_final_window",
					0,
					&"phase_final_window_started"
				),
			],
			true,
			100
		),
		_last_defense_trigger(),
	]


static func accepted_endings() -> Array[EndingDefinition]:
	return [
		ending(
			&"ending_necrotic_catastrophe",
			400,
			[
				condition(&"week_gte", &"", 10),
				condition(&"clock_gte", &"necrotic_corruption", 100),
			]
		),
		ending(
			&"ending_dragon_slain_at_cost",
			300,
			[
				condition(&"week_gte", &"", 10),
				condition(&"world_event_occurred", &"event_dragon_killed"),
			]
		),
		ending(
			&"ending_arcane_capture",
			200,
			[
				condition(&"week_gte", &"", 10),
				condition(&"clock_gte", &"capture_preparation", 80),
				condition(&"clock_gte", &"dragon_exhaustion", 60),
				condition(&"clock_lte", &"necrotic_corruption", 59),
			]
		),
		ending(
			&"ending_mass_evacuation",
			100,
			[
				condition(&"week_gte", &"", 10),
				condition(&"clock_gte", &"villagers_evacuated", 70),
			]
		),
	]


static func event_state(
	instance_id: StringName,
	event_key: StringName,
	week: int = 1
) -> WorldEventState:
	return WorldEventState.create(
		instance_id,
		event_key,
		week,
		&"fixture_source",
		&"",
		[&"fixture_event"]
	)


static func rule(
	id: StringName,
	all_conditions: Array[WorldCondition],
	any_conditions: Array[WorldCondition] = [],
	effects: Array[WorldEffect] = [],
	once: bool = true,
	priority: int = 0
) -> WorldRule:
	return WorldRule.create(
		id,
		all_conditions,
		any_conditions,
		effects,
		once,
		priority
	)


static func condition(
	type: StringName,
	target_id: StringName,
	int_value: int = 0
) -> WorldCondition:
	return WorldCondition.create(type, target_id, int_value)


static func effect(
	type: StringName,
	target_id: StringName,
	amount: int,
	reason_code: StringName
) -> WorldEffect:
	return WorldEffect.create(type, target_id, amount, reason_code)


static func ending(
	id: StringName,
	priority: int,
	all_conditions: Array[WorldCondition],
	any_conditions: Array[WorldCondition] = []
) -> EndingDefinition:
	return EndingDefinition.create(
		id,
		StringName("%s.name" % id),
		StringName("%s.description" % id),
		priority,
		all_conditions,
		any_conditions
	)


static func _clock(id: StringName, initial_value: int) -> ClockDefinition:
	return ClockDefinition.create(
		id,
		StringName("%s.name" % id),
		0,
		100,
		initial_value,
		&"player"
	)


static func _phase(
	id: StringName,
	sort_order: int,
	is_terminal: bool
) -> SituationPhaseDefinition:
	return SituationPhaseDefinition.create(
		id,
		StringName("%s.name" % id),
		StringName("%s.description" % id),
		sort_order,
		is_terminal
	)


static func _last_defense_trigger() -> WorldRule:
	return rule(
		&"trigger_last_defense_kills_dragon",
		[
			condition(&"week_gte", &"", 15),
			condition(&"world_event_not_occurred", &"event_dragon_killed"),
			condition(&"clock_lte", &"necrotic_corruption", 99),
			condition(&"clock_lte", &"villagers_evacuated", 69),
		],
		[
			condition(&"clock_lte", &"capture_preparation", 79),
			condition(&"clock_lte", &"dragon_exhaustion", 59),
			condition(&"clock_gte", &"necrotic_corruption", 60),
		],
		[
			effect(
				&"create_world_event",
				&"event_dragon_killed",
				0,
				&"last_defense_dragon_killed"
			),
			effect(
				&"create_world_event",
				&"event_last_defense",
				0,
				&"last_defense_formed"
			),
			effect(
				&"modify_clock",
				&"settlement_destruction",
				30,
				&"last_defense_destruction"
			),
		],
		true,
		1000
	)
