class_name FactionPlannerFixtures
extends RefCounted

const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)
const FactionTurnPlanner = preload(
	"res://game/domain/simulation/faction_turn_planner.gd"
)
const FactionDefinition = preload(
	"res://game/domain/factions/faction_definition.gd"
)
const FactionActionDefinition = preload(
	"res://game/domain/factions/faction_action_definition.gd"
)
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const ProblemUrgencyResult = preload(
	"res://game/domain/situations/problem_urgency_result.gd"
)
const WorldCondition = preload(
	"res://game/domain/situations/world_condition.gd"
)
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const DeclinedOfferSuppressionKey = preload(
	"res://game/domain/contracts/declined_offer_suppression_key.gd"
)


static func create_request(
	state = null,
	suppressions: Array = []
) -> FactionTurnPlanner.FactionPlanningRequest:
	var source_state = (
		CampaignStateFixtures.create_baseline_state()
		if state == null
		else state
	)
	var catalog = CatalogContentFixtures.create_catalog()
	var factions: Array[FactionDefinition] = catalog.get_all_factions()
	var contracts: Array[ContractDefinition] = catalog.get_all_contracts()
	var problems: Array[WorldProblemDefinition] = catalog.get_all_problems()
	var actions: Array[FactionActionDefinition] = []
	var problem_by_faction: Dictionary[StringName, WorldProblemDefinition] = {}
	for contract: ContractDefinition in contracts:
		contract.starts_unlocked = true
		contract.repeat_policy = &"repeatable"
		contract.availability_rules.clear()
		contract.proposal_base_priority = 12
		contract.urgency_weight = 20
		problem_by_faction[contract.sponsor_faction_id] = _problem_by_id(
			problems,
			contract.related_problem_id
		)
	for faction: FactionDefinition in factions:
		var problem: WorldProblemDefinition = problem_by_faction[faction.id]
		var action := action_for(
			faction.id,
			problem,
			&"primary",
			12,
			20,
			2,
			5
		)
		var fallback := action_for(
			faction.id,
			problem,
			&"fallback",
			8,
			10,
			0,
			4
		)
		actions.append(action)
		actions.append(fallback)
		faction.weekly_action_ids = [action.id, fallback.id]
	for problem: WorldProblemDefinition in problems:
		source_state.situation.problems[problem.id] = WorldProblemState.create(
			problem.id,
			WorldProblemState.STATUS_ACTIVE,
			0,
			10
		)
	var urgencies: Array[ProblemUrgencyResult] = []
	for problem: WorldProblemDefinition in problems:
		urgencies.append(ProblemUrgencyResult.create(
			problem.id,
			source_state.week_index,
			50,
			&"high",
			3,
			[]
		))
	var typed_suppressions: Array[DeclinedOfferSuppressionKey] = []
	for suppression: DeclinedOfferSuppressionKey in suppressions:
		typed_suppressions.append(suppression)
	return FactionTurnPlanner.FactionPlanningRequest.create(
		source_state,
		factions,
		contracts,
		actions,
		problems,
		urgencies,
		typed_suppressions
	)


static func action_for(
	faction_id: StringName,
	problem: WorldProblemDefinition,
	suffix: StringName,
	base_priority: int,
	urgency_weight: int,
	cooldown: int,
	cost: int
) -> FactionActionDefinition:
	var faction_short := String(faction_id).trim_prefix("faction_")
	var action_id := StringName("action_%s_%s" % [faction_short, suffix])
	var target_lock := StringName("%s.%s" % [faction_short, suffix])
	var agenda_tag := _agenda_tag_for(faction_id)
	var conditions: Array[WorldCondition] = []
	var effects: Array[WorldEffect] = [
		WorldEffect.create(
			&"modify_clock",
			problem.related_clock_ids[0],
			3,
			StringName("%s_clock_progress" % action_id)
		),
	]
	return FactionActionDefinition.create(
		action_id,
		[agenda_tag],
		target_lock,
		base_priority,
		urgency_weight,
		cooldown,
		cost,
		conditions,
		[problem.problem_tags[0]],
		effects,
		StringName("event_%s" % action_id)
	)


static func _problem_by_id(
	problems: Array[WorldProblemDefinition],
	id: StringName
) -> WorldProblemDefinition:
	for problem: WorldProblemDefinition in problems:
		if problem.id == id:
			return problem
	return null


static func _agenda_tag_for(faction_id: StringName) -> StringName:
	match faction_id:
		&"faction_arcane_guild":
			return &"capture"
		&"faction_free_adventurers":
			return &"evacuation"
	return &"corruption"
