extends RefCounted

const DashboardPresenter = preload(
	"res://game/features/dashboard/dashboard_presenter.gd"
)
const RosterPresenter = preload(
	"res://game/features/roster/roster_presenter.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const CampaignBootstrapFixtures = preload(
	"res://tests/fixtures/campaign_bootstrap_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_dashboard_public_urgency(),
		_test_roster_history_projection(),
	]


func _test_dashboard_public_urgency() -> Dictionary:
	var catalog = CampaignBootstrapFixtures.create_catalog()
	var bootstrap = CampaignBootstrapFixtures.bootstrap(catalog)
	var state = bootstrap.new_state
	var view_data = DashboardPresenter.present(
		state,
		catalog.get_situation(state.situation.definition_id),
		catalog.get_all_contracts(),
		catalog.get_all_factions(),
		catalog.get_all_faction_actions(),
		catalog.get_all_problems()
	)
	var passed: bool = view_data != null \
		and view_data.clocks.size() == 5 \
		and view_data.offers.size() == 3 \
		and view_data.problems.size() == 3
	for problem in view_data.problems:
		passed = passed \
			and problem.player_reason_keys.size() <= 2 \
			and problem.band in [
				&"low",
				&"guarded",
				&"high",
				&"severe",
				&"critical",
			]
	return _result(
		"Dashboard exposes band turns and at most two public reasons",
		passed,
		"Dashboard urgency projection leaked or omitted required fields."
	)


func _test_roster_history_projection() -> Dictionary:
	var catalog = CampaignBootstrapFixtures.create_catalog()
	var bootstrap = CampaignBootstrapFixtures.bootstrap(catalog)
	var state = bootstrap.new_state.duplicate_state()
	var member_ids: Array[StringName] = [
		&"mara_shield",
		&"elin_pathfinder",
		&"sister_ana",
		&"orrin_arcanist",
	]
	state.contract_history.append(ContractHistoryEntry.create_resolved(
		1,
		&"contract_instance_roster_test",
		&"contract_scout_eastern_road",
		&"faction_free_adventurers",
		&"problem_eastern_road_blocked",
		member_ids,
		[],
		&"balanced",
		&"success",
		100,
		[]
	))
	var view_data = RosterPresenter.present(
		state,
		catalog.get_all_campaign_setups()[0],
		catalog.get_all_adventurers(),
		catalog.get_all_contracts()
	)
	var records_by_member: Dictionary[StringName, int] = {}
	for member in view_data.members:
		records_by_member[member.id] = member.recent_records.size()
	var passed: bool = view_data.members.size() == 8
	for member_id: StringName in records_by_member:
		passed = passed and records_by_member[member_id] == (
			1 if member_ids.has(member_id) else 0
		)
	return _result(
		"Roster recent records derive only from ContractHistoryEntry",
		passed,
		"Roster records did not match the sole persisted history entry."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
