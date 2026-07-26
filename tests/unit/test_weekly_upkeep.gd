extends RefCounted

const AdventurerState = preload(
	"res://game/domain/adventurers/adventurer_state.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const CampaignHistoryQuery = preload(
	"res://game/domain/campaign/campaign_history_query.gd"
)
const WeeklyParticipationSnapshot = preload(
	"res://game/domain/campaign/weekly_participation_snapshot.gd"
)
const WeeklyUpkeepResolver = preload(
	"res://game/domain/simulation/weekly_upkeep_resolver.gd"
)
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_history_query_and_full_gate_d_test(),
		_shortfall_branch_test(),
		_invalid_injury_rolls_back_test(),
		_deterministic_upkeep_test(),
	]


func _history_query_and_full_gate_d_test() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var state = _eight_member_state(1000)
	state.adventurers[&"mara_shield"] = AdventurerState.create(
		&"mara_shield", 30, 50, 30, 1, 0, true
	)
	state.adventurers[&"toren_hammer"] = AdventurerState.create(
		&"toren_hammer", 19, 50, 80, 3, 0, false, {}, 0, 2
	)
	var history := ContractHistoryEntry.create_resolved(
		1,
		&"contract_history_week_one",
		&"contract_north_road_evacuation",
		&"faction_free_adventurers",
		&"",
		[&"mara_shield"],
		[],
		&"balanced",
		&"success",
		10,
		[]
	)
	state.contract_history.append(history)
	var query = CampaignHistoryQuery.participation_for_week(state, 1)
	if not query.is_success():
		return _result(
			"history query feeds every accepted Gate D upkeep rule",
			false,
			"History query failed: %s" % query.issues
		)
	var upkeep = WeeklyUpkeepResolver.resolve(
		2,
		state,
		catalog.get_all_adventurers(),
		query.snapshot
	)
	var committed = CampaignTransaction.apply(state, upkeep.operations)
	var passed: bool = upkeep.is_success() \
		and upkeep.required_upkeep == 153 \
		and upkeep.paid == 153 \
		and upkeep.shortfall == 0 \
		and committed.is_success() \
		and committed.new_state.guild.gold == 847 \
		and committed.new_state.adventurers[&"mara_shield"].get_fatigue() == 30 \
		and committed.new_state.adventurers[&"mara_shield"].get_injury_severity() == 0 \
		and committed.new_state.adventurers[&"mara_shield"].get_is_available() \
		and committed.new_state.adventurers[&"mara_shield"] \
			.get_recent_assignment_count() == 1 \
		and committed.new_state.adventurers[&"toren_hammer"].get_fatigue() == 0 \
		and committed.new_state.adventurers[&"toren_hammer"].get_injury_severity() == 80 \
		and committed.new_state.adventurers[&"toren_hammer"] \
			.get_recovery_weeks_remaining() == 2 \
		and committed.new_state.adventurers[&"toren_hammer"] \
			.get_recent_neglect_count() == 2
	return _result(
		"history query feeds every accepted Gate D upkeep rule",
		passed,
		"Expected wages 98 + maintenance 25 + treatment 30, stable attendance, recovery, and counters."
	)


func _shortfall_branch_test() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var state = _eight_member_state(122)
	var empty_ids: Array[StringName] = []
	var snapshot := WeeklyParticipationSnapshot.new(1, empty_ids)
	var upkeep = WeeklyUpkeepResolver.resolve(
		2, state, catalog.get_all_adventurers(), snapshot
	)
	var committed = CampaignTransaction.apply(state, upkeep.operations)
	var passed: bool = upkeep.is_success() \
		and upkeep.required_upkeep == 123 \
		and upkeep.paid == 122 \
		and upkeep.shortfall == 1 \
		and committed.is_success() \
		and committed.new_state.guild.gold == 0 \
		and committed.new_state.guild.reputation == 45
	if passed:
		for member_id: StringName in committed.new_state.adventurers:
			if committed.new_state.adventurers[member_id].get_morale() != 45:
				passed = false
				break
	return _result(
		"one-gold shortfall commits the fixed austerity branch",
		passed,
		"Expected Gold 0, reputation -5, and every member morale -5."
	)


func _invalid_injury_rolls_back_test() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var state = _eight_member_state()
	state.adventurers[&"mara_shield"] = AdventurerState.create(
		&"mara_shield", 0, 50, 20, 1
	)
	var empty_ids: Array[StringName] = []
	var upkeep = WeeklyUpkeepResolver.resolve(
		2,
		state,
		catalog.get_all_adventurers(),
		WeeklyParticipationSnapshot.new(1, empty_ids)
	)
	return _result(
		"inconsistent injury state exposes no partial operations",
		not upkeep.is_success() and upkeep.operations.is_empty(),
		"Unsupported injury severity 1..29 must reject the whole upkeep projection."
	)


func _deterministic_upkeep_test() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var state = _eight_member_state()
	var snapshot := WeeklyParticipationSnapshot.new(
		1, [&"mara_shield", &"sister_ana"]
	)
	var first = WeeklyUpkeepResolver.resolve(
		2, state, catalog.get_all_adventurers(), snapshot
	)
	var second = WeeklyUpkeepResolver.resolve(
		2, state, catalog.get_all_adventurers(), snapshot
	)
	return _result(
		"identical upkeep input repeats exactly",
		_operation_signature(first.operations) == _operation_signature(second.operations),
		"Upkeep operation order or values changed between identical calls."
	)


func _eight_member_state(gold: int = 1000):
	var catalog = CatalogContentFixtures.create_catalog()
	var state = CampaignStateFixtures.create_baseline_state(gold)
	state.adventurers.clear()
	for definition in catalog.get_all_adventurers():
		state.adventurers[definition.id] = AdventurerState.create(definition.id)
	return state


func _operation_signature(operations: Array) -> String:
	var parts := PackedStringArray()
	for operation in operations:
		parts.append("%s:%s:%s:%s:%s:%s:%d" % [
			operation.target_kind,
			operation.target_id,
			operation.field_id,
			operation.operation,
			operation.value,
			operation.reason_code,
			operation.source_order,
		])
	return "|".join(parts)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
