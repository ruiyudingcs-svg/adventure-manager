extends RefCounted

const WeekFlowCoordinator = preload(
	"res://game/domain/simulation/week_flow_coordinator.gd"
)
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
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
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_action_path(
			&"faction_free_adventurers",
			&"ending_mass_evacuation",
			12
		),
		_action_path(
			&"faction_arcane_guild",
			&"ending_arcane_capture",
			13
		),
		_action_path(
			&"faction_necrotic_collective",
			&"ending_necrotic_catastrophe",
			14
		),
		_last_defense_path(),
	]


func _action_path(
	faction_id: StringName,
	expected_ending: StringName,
	max_week: int
) -> Dictionary:
	var prepared := _path_inputs(faction_id)
	var state = prepared.state
	var trace := PackedStringArray()
	for week: int in range(2, max_week + 1):
		var opening = WeekFlowCoordinator.open_week(
			WeekFlowCoordinator.WeekOpeningRequest.create(
				week,
				state,
				prepared.adventurers,
				prepared.factions,
				prepared.contracts,
				prepared.actions,
				prepared.problems,
				prepared.situation
			)
		)
		if not opening.is_success():
			return _result(
				"%s real WeekFlow path" % expected_ending,
				false,
				"Week %d opening failed: %s; trace=%s"
					% [week, opening.issues, trace]
			)
		if not opening.new_state.situation.ending_id.is_empty():
			state = opening.new_state
			trace.append("%d:ending:%s" % [
				week,
				state.situation.ending_id,
			])
			break
		var action_ids := PackedStringArray()
		for commitment in opening.planning_result.new_commitments:
			action_ids.append(commitment.action_definition_id)
		var resolution = WeekFlowCoordinator.resolve_week(
			WeekFlowCoordinator.WeekResolutionRequest.create(
				week,
				opening.new_state,
				true,
				null,
				prepared.actions,
				prepared.situation
			)
		)
		if not resolution.is_success():
			return _result(
				"%s real WeekFlow path" % expected_ending,
				false,
				"Week %d resolution failed: %s; trace=%s"
					% [week, resolution.issues, trace]
			)
		state = resolution.new_state
		trace.append("%d:%s:E%d/X%d/P%d/C%d" % [
			week,
			"+".join(action_ids),
			state.situation.clock_values[&"villagers_evacuated"],
			state.situation.clock_values[&"dragon_exhaustion"],
			state.situation.clock_values[&"capture_preparation"],
			state.situation.clock_values[&"necrotic_corruption"],
		])
		if not state.situation.ending_id.is_empty():
			break
	return _result(
		"%s real WeekFlow path" % expected_ending,
		state.situation.ending_id == expected_ending,
		"Expected %s by week %d, got %s; trace=%s" % [
			expected_ending,
			max_week,
			state.situation.ending_id,
			trace,
		]
	)


func _last_defense_path() -> Dictionary:
	var prepared := _path_inputs(&"")
	var state = prepared.state
	var trace := PackedStringArray()
	for week: int in range(2, 16):
		var opening = WeekFlowCoordinator.open_week(
			WeekFlowCoordinator.WeekOpeningRequest.create(
				week,
				state,
				prepared.adventurers,
				prepared.factions,
				prepared.contracts,
				prepared.actions,
				prepared.problems,
				prepared.situation
			)
		)
		if not opening.is_success():
			return _result(
				"ending_dragon_slain_at_cost week-15 fallback",
				false,
				"Week %d opening failed: %s" % [week, opening.issues]
			)
		var resolution = WeekFlowCoordinator.resolve_week(
			WeekFlowCoordinator.WeekResolutionRequest.create(
				week,
				opening.new_state,
				true,
				null,
				prepared.actions,
				prepared.situation
			)
		)
		if not resolution.is_success():
			return _result(
				"ending_dragon_slain_at_cost week-15 fallback",
				false,
				"Week %d resolution failed: %s" % [week, resolution.issues]
			)
		state = resolution.new_state
		trace.append("%d:%s" % [week, state.situation.ending_id])
		if not state.situation.ending_id.is_empty():
			break
	return _result(
		"ending_dragon_slain_at_cost week-15 fallback",
		state.week_index == 15 \
			and state.situation.ending_id == &"ending_dragon_slain_at_cost",
		"Expected the accepted week-15 fallback; trace=%s" % [trace]
	)


func _path_inputs(faction_id: StringName) -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var state = CampaignStateFixtures.create_baseline_state(5000)
	_seed_accepted_contract_progress(state, faction_id)
	for active_problem_id: StringName in [
		&"problem_eastern_road_blocked",
		&"problem_dragon_location_unknown",
		&"problem_dragon_assault_pressure",
	]:
		var definition = catalog.get_problem(active_problem_id)
		state.situation.problems[active_problem_id] = WorldProblemState.create(
			active_problem_id,
			WorldProblemState.STATUS_ACTIVE,
			1,
			1 + definition.response_window_weeks
		)
	var adventurers: Array[AdventurerDefinition] = []
	for definition in catalog.get_all_adventurers():
		if state.adventurers.has(definition.id):
			adventurers.append(definition)
	for snapshot in CatalogContentFixtures.create_baseline_team():
		if not state.adventurers.has(snapshot.id):
			continue
		var found := false
		for definition: AdventurerDefinition in adventurers:
			if definition.id == snapshot.id:
				found = true
				break
		if not found:
			adventurers.append(AdventurerDefinition.create(
				snapshot.id,
				String(snapshot.id),
				snapshot.class_id,
				snapshot.capabilities,
				snapshot.values,
				snapshot.traits,
				[],
				snapshot.wage
			))
	var factions: Array[FactionDefinition] = catalog.get_all_factions()
	var actions: Array[FactionActionDefinition] = (
		catalog.get_all_faction_actions()
	)
	if not faction_id.is_empty():
		state.factions[faction_id].influence = 100
	for faction: FactionDefinition in factions:
		if faction.id != faction_id:
			state.factions[faction.id].influence = 0
	var contracts: Array[ContractDefinition] = catalog.get_all_contracts()
	var problems: Array[WorldProblemDefinition] = catalog.get_all_problems()
	return {
		"state": state,
		"adventurers": adventurers,
		"factions": factions,
		"contracts": contracts,
		"actions": actions,
		"problems": problems,
		"situation": catalog.get_situation(&"situation_dragon_invasion_v0_1"),
	}


func _seed_accepted_contract_progress(state, faction_id: StringName) -> void:
	match faction_id:
		&"faction_free_adventurers":
			# 5 initial + road 5 + north 18 + mine 14 + two healers 16.
			state.situation.clock_values[&"villagers_evacuated"] = 58
		&"faction_arcane_guild":
			# Lair 12 + three scale contracts 54; exhaustion includes their
			# accepted trace after intervening passive recovery.
			state.situation.clock_values[&"capture_preparation"] = 66
			state.situation.clock_values[&"dragon_exhaustion"] = 55
			state.world_events.append(WorldEventState.create(
				&"event_instance_path_lair",
				&"event_dragon_lair_located",
				1,
				&"contract_locate_dragon_lair",
				&"problem_dragon_location_unknown",
				[&"event_dragon_lair_located"]
			))
		&"faction_necrotic_collective":
			# Week-10 passive base 23 + three corpse recoveries 21.
			state.situation.clock_values[&"necrotic_corruption"] = 44


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else message}
