extends RefCounted

const StateOperation = preload("res://game/core/result/state_operation.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const SituationResolver = preload(
	"res://game/domain/simulation/situation_resolver.gd"
)
const SituationFixtures = preload(
	"res://tests/fixtures/situation_fixtures.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_base_and_situation_operations_commit_atomically_test(),
		_invalid_combined_batch_rolls_back_test(),
		_week_fifteen_last_defense_path_test(),
		_non_world_state_is_outside_resolver_input_test(),
	]


func _base_and_situation_operations_commit_atomically_test() -> Dictionary:
	var definition = SituationFixtures.create_definition()
	var state = SituationFixtures.create_state(
		&"inactive",
		-1,
		-1,
		{&"settlement_destruction": 25}
	)
	var campaign = SituationFixtures.create_campaign(2, state)
	var before: String = CampaignStateFixtures.state_signature(campaign)
	var base_operations: Array[StateOperation] = [
		_clock_delta(5, &"contract_world_effect", 100),
	]
	var resolved = SituationResolver.resolve(
		2,
		definition,
		campaign.situation,
		campaign.world_events,
		campaign.contract_history,
		base_operations,
		SituationResolver.BOUNDARY_WEEK_START
	)
	var complete_batch: Array[StateOperation] = []
	complete_batch.append_array(base_operations)
	complete_batch.append_array(resolved.operations)
	var committed = CampaignTransaction.apply(campaign, complete_batch)
	var problem = (
		committed.new_state.situation.problems[SituationFixtures.PROBLEM_ID]
		if committed.is_success()
		else null
	)
	var passed: bool = resolved.is_success() \
		and committed.is_success() \
		and committed.new_state.situation.clock_values[&"settlement_destruction"] == 34 \
		and problem.status == &"active" \
		and problem.opened_week == 2 \
		and problem.response_deadline_week == 4 \
		and CampaignStateFixtures.state_signature(campaign) == before
	return _result(
		"base and resolver world operations commit in one transaction",
		passed,
		"Expected 25 + 5 base + 4 passive, activation deadline 4, and pure input."
	)


func _invalid_combined_batch_rolls_back_test() -> Dictionary:
	var definition = SituationFixtures.create_definition()
	var campaign = SituationFixtures.create_campaign(
		2,
		SituationFixtures.create_state()
	)
	var before: String = CampaignStateFixtures.state_signature(campaign)
	var base_operations: Array[StateOperation] = [
		_clock_delta(20, &"contract_world_effect", 100),
	]
	var resolved = SituationResolver.resolve(
		2,
		definition,
		campaign.situation,
		campaign.world_events,
		campaign.contract_history,
		base_operations,
		SituationResolver.BOUNDARY_WEEK_START
	)
	var complete_batch: Array[StateOperation] = []
	complete_batch.append_array(base_operations)
	complete_batch.append_array(resolved.operations)
	complete_batch.append(StateOperation.create(
		CampaignTransaction.TARGET_CLOCK,
		&"clock_missing",
		CampaignTransaction.FIELD_VALUE,
		StateOperation.OP_ADD_INT,
		1,
		&"invalid_world_target",
		999
	))
	var committed = CampaignTransaction.apply(campaign, complete_batch)
	var passed: bool = resolved.is_success() \
		and not committed.is_success() \
		and committed.new_state == null \
		and CampaignStateFixtures.state_signature(campaign) == before
	return _result(
		"invalid operation rolls back the complete situation batch",
		passed,
		"Expected no base, passive, trigger, or problem mutation after rejection."
	)


func _week_fifteen_last_defense_path_test() -> Dictionary:
	var definition = SituationFixtures.create_definition(
		SituationFixtures.accepted_phase_triggers(),
		SituationFixtures.accepted_endings()
	)
	var campaign = SituationFixtures.create_campaign(
		15,
		SituationFixtures.create_state(
			&"inactive",
			-1,
			-1,
			{
				&"villagers_evacuated": 69,
				&"settlement_destruction": 10,
				&"dragon_exhaustion": 59,
				&"capture_preparation": 79,
				&"necrotic_corruption": 59,
			},
			&"phase_final_window",
			[
				&"trigger_phase_open_conflict",
				&"trigger_phase_final_window",
			]
		)
	)
	var resolved = SituationResolver.resolve(
		15,
		definition,
		campaign.situation,
		campaign.world_events,
		campaign.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var committed = CampaignTransaction.apply(campaign, resolved.operations)
	var event_keys: Array[StringName] = []
	if committed.is_success():
		for event in committed.new_state.world_events:
			event_keys.append(event.event_key)
	var terminal_problem = (
		committed.new_state.situation.problems[SituationFixtures.PROBLEM_ID]
		if committed.is_success()
		else null
	)
	var passed: bool = resolved.is_success() \
		and resolved.selected_ending_id == &"ending_dragon_slain_at_cost" \
		and committed.is_success() \
		and committed.new_state.situation.ending_id == &"ending_dragon_slain_at_cost" \
		and committed.new_state.situation.phase_id == &"phase_ended" \
		and committed.new_state.situation.triggered_rule_ids.has(
			&"trigger_last_defense_kills_dragon"
		) \
		and event_keys.has(&"event_dragon_killed") \
		and event_keys.has(&"event_last_defense") \
		and committed.new_state.situation.clock_values[&"settlement_destruction"] == 40 \
		and terminal_problem.status == &"closed" \
		and terminal_problem.opened_week == 15 \
		and terminal_problem.closed_week == 15
	return _result(
		"week fifteen accepted fixture reaches the costly dragon-slaying ending",
		passed,
		"Expected fallback events, ending, terminal phase, cost, and closed problem."
	)


func _non_world_state_is_outside_resolver_input_test() -> Dictionary:
	var definition = SituationFixtures.create_definition()
	var shared_state = SituationFixtures.create_state(
		&"active",
		3,
		5,
		{&"settlement_destruction": 40}
	)
	var campaign_a = SituationFixtures.create_campaign(4, shared_state)
	var campaign_b = SituationFixtures.create_campaign(4, shared_state)
	campaign_b.guild.gold = 1
	campaign_b.guild.reputation = 0
	campaign_b.guild.base_cohesion = 100
	for member_id: StringName in campaign_b.adventurers:
		campaign_b.adventurers[member_id].set_fatigue(100)
		campaign_b.adventurers[member_id].set_morale(0)
	for faction_id: StringName in campaign_b.factions:
		campaign_b.factions[faction_id].relation = -100
		campaign_b.factions[faction_id].influence = 0
	var result_a = SituationResolver.resolve(
		4,
		definition,
		campaign_a.situation,
		campaign_a.world_events,
		campaign_a.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var result_b = SituationResolver.resolve(
		4,
		definition,
		campaign_b.situation,
		campaign_b.world_events,
		campaign_b.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var passed: bool = result_a.is_success() \
		and result_b.is_success() \
		and result_a.signature() == result_b.signature()
	return _result(
		"resolver output is independent of economy members and factions",
		passed,
		"Changing all excluded campaign domains must not change world resolution."
	)


func _clock_delta(
	amount: int,
	reason_code: StringName,
	source_order: int
) -> StateOperation:
	return StateOperation.create(
		CampaignTransaction.TARGET_CLOCK,
		&"settlement_destruction",
		CampaignTransaction.FIELD_VALUE,
		StateOperation.OP_ADD_INT,
		amount,
		reason_code,
		source_order
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
