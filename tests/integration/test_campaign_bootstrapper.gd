extends RefCounted

const CampaignBootstrapper = preload(
	"res://game/domain/simulation/campaign_bootstrapper.gd"
)
const CampaignBootstrapFixtures = preload(
	"res://tests/fixtures/campaign_bootstrap_fixtures.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_deterministic_signature(),
		_test_exact_first_week_state(),
		_test_real_week_flow_opening(),
		_test_invalid_request_is_atomic(),
	]


func _test_deterministic_signature() -> Dictionary:
	var catalog = CampaignBootstrapFixtures.create_catalog()
	var first = CampaignBootstrapFixtures.bootstrap(catalog, 8814014)
	var second = CampaignBootstrapFixtures.bootstrap(catalog, 8814014)
	return _result(
		"same setup and seed produce the same first-week signature",
		first.is_success() \
			and second.is_success() \
			and first.content_signature() == second.content_signature(),
		"Repeated bootstrap output was not deterministic."
	)


func _test_exact_first_week_state() -> Dictionary:
	var result = CampaignBootstrapFixtures.bootstrap(null, 140014)
	if not result.is_success():
		return _result(
			"Gate F initial state and deadlines are exact",
			false,
			"Bootstrap failed: %s" % result.issues
		)
	var state = result.new_state
	var expected_clocks := {
		&"villagers_evacuated": 5,
		&"settlement_destruction": 10,
		&"dragon_exhaustion": 15,
		&"capture_preparation": 0,
		&"necrotic_corruption": 5,
	}
	var active: Array[StringName] = []
	var deadlines: Dictionary[StringName, int] = {}
	for problem_id: StringName in state.situation.problems:
		var problem = state.situation.problems[problem_id]
		if problem.status == WorldProblemState.STATUS_ACTIVE:
			active.append(problem_id)
			deadlines[problem_id] = problem.response_deadline_week
	active.sort()
	var passed: bool = state.week_index == 1 \
		and state.guild.gold == 250 \
		and state.guild.reputation == 20 \
		and state.guild.base_cohesion == 50 \
		and state.guild.weekly_maintenance == 25 \
		and state.adventurers.size() == 8 \
		and state.factions.size() == 3 \
		and state.situation.phase_id == &"phase_early_crisis" \
		and state.situation.clock_values == expected_clocks \
		and active == [
			&"problem_dragon_assault_pressure",
			&"problem_dragon_location_unknown",
			&"problem_eastern_road_blocked",
		] \
		and deadlines[&"problem_eastern_road_blocked"] == 3 \
		and deadlines[&"problem_dragon_location_unknown"] == 4 \
		and deadlines[&"problem_dragon_assault_pressure"] == 3
	for member in state.adventurers.values():
		passed = passed \
			and member.get_fatigue() == 0 \
			and member.get_morale() == 50 \
			and member.get_injury_severity() == 0 \
			and member.get_recovery_weeks_remaining() == 0 \
			and member.get_growth_xp() == 0 \
			and member.get_is_available()
	for faction in state.factions.values():
		passed = passed \
			and faction.relation == 0 \
			and faction.influence == 60
	return _result(
		"Gate F initial state and deadlines are exact",
		passed,
		"One or more accepted initial values or deadlines differed."
	)


func _test_real_week_flow_opening() -> Dictionary:
	var result = CampaignBootstrapFixtures.bootstrap(null, 140014)
	var opening = result.opening_result
	var passed: bool = result.is_success() \
		and result.new_state.pending_contracts.size() == 3 \
		and result.new_state.faction_action_commitments.is_empty() \
		and opening.upkeep_result == null \
		and opening.prelude_result == null \
		and result.new_state.guild.gold == 250 \
		and result.new_state.situation.clock_values[
			&"settlement_destruction"
		] == 10 \
		and result.new_state.situation.clock_values[
			&"dragon_exhaustion"
		] == 15 \
		and result.new_state.situation.clock_values[
			&"necrotic_corruption"
		] == 5
	return _result(
		"first week uses real WeekFlow without upkeep passive drift or actions",
		passed,
		"Week-one special opening did not preserve the Gate F boundary."
	)


func _test_invalid_request_is_atomic() -> Dictionary:
	var catalog = CampaignBootstrapFixtures.create_catalog()
	var request = CampaignBootstrapFixtures.create_request(catalog)
	request.setup.adventurer_ids.append(&"missing_adventurer")
	var result = CampaignBootstrapper.bootstrap(request)
	return _result(
		"invalid bootstrap never returns partial CampaignState",
		not result.is_success() \
			and result.new_state == null \
			and result.opening_result == null \
			and not result.issues.is_empty(),
		"Invalid content returned a partial state or no issue."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
