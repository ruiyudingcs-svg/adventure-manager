extends RefCounted

const WeekFlowCoordinator = preload(
	"res://game/domain/simulation/week_flow_coordinator.gd"
)
const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const PlanContractCommand = preload(
	"res://game/domain/contracts/plan_contract_command.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const FactionActionCommitmentState = preload(
	"res://game/domain/factions/faction_action_commitment_state.gd"
)
const FactionActionDefinition = preload(
	"res://game/domain/factions/faction_action_definition.gd"
)
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const MessageRequest = preload("res://game/domain/messages/message_request.gd")
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)
const ContractOfferFixtures = preload(
	"res://tests/fixtures/contract_offer_fixtures.gd"
)
const FactionPlannerFixtures = preload(
	"res://tests/fixtures/faction_planner_fixtures.gd"
)
const FactionTurnPlanner = preload(
	"res://game/domain/simulation/faction_turn_planner.gd"
)


class MessageSourceResult extends RefCounted:
	var post_world_result = null


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_first_week_skips_upkeep_and_passive_test(),
		_deadline_precedes_offer_lifecycle_test(),
		_open_week_and_resolve_actions_test(),
		_contract_and_offer_commit_test(),
		_supply_shortfall_rolls_back_test(),
		_ten_week_headless_test(),
		_message_visibility_and_ending_mapping_test(),
	]


func _first_week_skips_upkeep_and_passive_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	state.week_index = 0
	var request = _opening_request(state, 1)
	var gold_before: int = request.base_state.guild.gold
	var clocks_before: Dictionary = request.base_state.situation.clock_values.duplicate()
	var opening = WeekFlowCoordinator.open_week(request)
	var offer_messages := 0
	var summary_messages := 0
	var offer_parameters_are_public := true
	if opening.is_success():
		for message in opening.generated_messages:
			if message.category == MessageRequest.CATEGORY_CONTRACT_OFFER:
				offer_messages += 1
				var parameters: Dictionary = message.parameters
				offer_parameters_are_public = (
					parameters.has("origin_type")
					and parameters.has("reason_codes")
					and parameters["reason_codes"].size() <= 2
					and not parameters.has("score")
					and not parameters.has("candidates")
				)
			elif message.category == MessageRequest.CATEGORY_WEEK_SUMMARY:
				summary_messages += 1
	return _result(
		"first week plans directly without upkeep or passive world progress",
		opening.is_success() \
			and opening.new_state.week_index == 1 \
			and opening.new_state.guild.gold == gold_before \
			and opening.new_state.situation.clock_values == clocks_before \
			and opening.upkeep_result == null \
			and opening.prelude_result == null \
			and offer_messages == opening.planning_result.new_offers.size() \
			and summary_messages == 1 \
			and offer_parameters_are_public,
		"Week 1 must only advance the index and build the initial frozen plan."
	)


func _open_week_and_resolve_actions_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var opening_two = WeekFlowCoordinator.open_week(_opening_request(state, 2))
	if not opening_two.is_success():
		return _result(
			"week opening and committed actions use frozen snapshots",
			false,
			"Week 2 opening failed: %s" % opening_two.issues
		)
	var end_two = WeekFlowCoordinator.resolve_week(_resolution_request(
		opening_two.new_state, true, opening_two.planning_result, null
	))
	if not end_two.is_success():
		return _result(
			"week opening and committed actions use frozen snapshots",
			false,
			"Week 2 resolution failed: %s" % end_two.issues
		)
	var opening_three = WeekFlowCoordinator.open_week(
		_opening_request(end_two.new_state, 3)
	)
	if not opening_three.is_success():
		return _result(
			"week opening and committed actions use frozen snapshots",
			false,
			"Week 3 opening failed: %s" % opening_three.issues
		)
	var before := CampaignStateFixtures.state_signature(opening_three.new_state)
	var end_three = WeekFlowCoordinator.resolve_week(_resolution_request(
		opening_three.new_state, true, opening_three.planning_result, null
	))
	var resolved_count := 0
	var end_categories: Array[StringName] = []
	if end_three.is_success():
		for message in end_three.generated_messages:
			if not end_categories.has(message.category):
				end_categories.append(message.category)
		for commitment in end_three.new_state.faction_action_commitments:
			if commitment.status == &"resolved":
				resolved_count += 1
	var passed: bool = end_three.is_success() \
		and opening_two.new_state.week_index == 2 \
		and opening_two.new_state.pending_contracts.size() == 3 \
		and opening_three.planning_result.new_commitments.size() > 0 \
		and resolved_count == opening_three.planning_result.new_commitments.size() \
		and end_categories.has(MessageRequest.CATEGORY_FACTION_ACTION) \
		and end_categories.has(MessageRequest.CATEGORY_WORLD_EVENT) \
		and end_categories.has(MessageRequest.CATEGORY_WEEK_SUMMARY) \
		and CampaignStateFixtures.state_signature(opening_three.new_state) == before
	return _result(
		"week opening and committed actions use frozen snapshots",
		passed,
		(
			"Expected week increments only on open, three offers, three atomic "
			+ "action resolutions, and pure input; got week=%d offers=%d "
			+ "new_commitments=%d resolved=%d pure=%s."
		) % [
			opening_two.new_state.week_index,
			opening_two.new_state.pending_contracts.size(),
			opening_three.planning_result.new_commitments.size(),
			resolved_count,
			CampaignStateFixtures.state_signature(opening_three.new_state) == before,
		]
	)


func _deadline_precedes_offer_lifecycle_test() -> Dictionary:
	var fixture_request = FactionPlannerFixtures.create_request(
		CampaignStateFixtures.create_baseline_state()
	)
	var planned = FactionTurnPlanner.plan_week(fixture_request)
	if not planned.is_success():
		return _result(
			"problem deadline precedes old Offer lifecycle",
			false,
			"Could not seed pending Offers."
		)
	var state = planned.new_state
	var offer = state.pending_contracts[0]
	if offer.related_problem_id.is_empty():
		return _result(
			"problem deadline precedes old Offer lifecycle",
			false,
			"Fixture Offer did not retain its problem anchor."
		)
	offer.expires_week = 1
	state.situation.problems[offer.related_problem_id].response_deadline_week = 1
	var next_request = FactionPlannerFixtures.create_request(state)
	# The fixture refreshes problem states, so restore this precise overdue edge
	# before handing the detached request to the coordinator.
	next_request.base_state.pending_contracts[0].expires_week = 1
	next_request.base_state.situation.problems[
		offer.related_problem_id
	].response_deadline_week = 1
	var opening = WeekFlowCoordinator.open_week(
		_opening_request_from_planner(next_request, 2)
	)
	var lifecycle_status: StringName = &""
	var lifecycle_reason: StringName = &""
	if (
		opening.lifecycle_result != null
		and opening.lifecycle_result.is_success()
		and not opening.lifecycle_result.updated_offers.is_empty()
	):
		lifecycle_status = opening.lifecycle_result.updated_offers[0].status
		lifecycle_reason = (
			opening.lifecycle_result.updated_offers[0].terminal_reason_code
		)
	return _result(
		"problem deadline precedes old Offer lifecycle",
		opening.is_success() \
			and opening.prelude_result.escalated_problem_ids.has(
				offer.related_problem_id
			) \
			and lifecycle_status == ContractOfferState.STATUS_EXPIRED \
			and lifecycle_reason == &"offer_expired_problem_inactive",
		(
			"Deadline escalation must precede lifecycle; success=%s escalated=%s "
			+ "status=%s reason=%s issues=%s."
		) % [
			opening.is_success(),
			(
				opening.prelude_result.escalated_problem_ids
				if opening.prelude_result != null
				else []
			),
			lifecycle_status,
			lifecycle_reason,
			opening.issues,
		]
	)


func _contract_and_offer_commit_test() -> Dictionary:
	var prepared: Dictionary = _accepted_fixture_state(false)
	if prepared.is_empty():
		return _result(
			"player contract, Offer terminal state, and world commit together",
			false,
			"Could not prepare accepted Offer fixture."
		)
	var state = prepared["state"]
	var catalog = CatalogContentFixtures.create_catalog()
	var problem = catalog.get_all_problems()[0]
	var action = FactionPlannerFixtures.action_for(
		&"faction_arcane_guild", problem, &"atomic", 1, 0, 0, 0
	)
	var commitment_reasons: Array[ReasonEntry] = []
	var commitment := FactionActionCommitmentState.create(
		&"faction_action_atomic_test",
		&"faction_arcane_guild",
		action.id,
		problem.id,
		action.target_lock_key,
		state.week_index,
		0,
		commitment_reasons
	)
	state.faction_action_commitments.append(commitment)
	var before := CampaignStateFixtures.state_signature(state)
	var action_definitions: Array[FactionActionDefinition] = [action]
	var request := WeekFlowCoordinator.WeekResolutionRequest.create(
		state.week_index,
		state,
		false,
		prepared["definitions"],
		action_definitions,
		prepared["situation"]
	)
	var resolved = WeekFlowCoordinator.resolve_week(request)
	var retried = WeekFlowCoordinator.resolve_week(request)
	var has_contract_result := false
	if resolved.is_success():
		for message in resolved.generated_messages:
			if message.category == MessageRequest.CATEGORY_CONTRACT_RESULT:
				has_contract_result = true
	var passed: bool = resolved.is_success() \
		and retried.is_success() \
		and CampaignStateFixtures.state_signature(resolved.new_state) \
			== CampaignStateFixtures.state_signature(retried.new_state) \
		and resolved.new_state.active_plan == null \
		and resolved.new_state.pending_contracts.is_empty() \
		and resolved.new_state.contract_history.size() == 1 \
		and resolved.new_state.faction_action_commitments[0].status == &"resolved" \
		and has_contract_result \
		and CampaignStateFixtures.state_signature(state) == before
	return _result(
		"player contract, Offer terminal state, and world commit together",
		passed,
		"Expected contract effects, resolved history, Offer removal, and plan clear in one transaction."
	)


func _supply_shortfall_rolls_back_test() -> Dictionary:
	var prepared: Dictionary = _accepted_fixture_state(true)
	if prepared.is_empty():
		return _result(
			"optional supply shortfall rolls back the whole week end",
			false,
			"Could not prepare accepted Offer with supply."
		)
	var state = prepared["state"]
	state.guild.gold = 0
	var before := CampaignStateFixtures.state_signature(state)
	var resolved = WeekFlowCoordinator.resolve_week(
		WeekFlowCoordinator.WeekResolutionRequest.create(
			state.week_index,
			state,
			false,
			prepared["definitions"],
			[],
			prepared["situation"]
		)
	)
	return _result(
		"optional supply shortfall rolls back the whole week end",
		not resolved.is_success() \
			and resolved.new_state == null \
			and CampaignStateFixtures.state_signature(state) == before,
		"Insufficient supply gold must expose no state, history, or partial effects."
	)


func _ten_week_headless_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state(2000)
	var trace := PackedStringArray()
	for week: int in range(2, 12):
		var opening = WeekFlowCoordinator.open_week(_opening_request(state, week))
		if not opening.is_success():
			return _result(
				"ten-week headless loop keeps auditable atomic boundaries",
				false,
				"Week %d opening failed: %s" % [week, opening.issues]
			)
		trace.append("open:%d:%d" % [week, opening.operations.size()])
		state = opening.new_state
		var resolution = WeekFlowCoordinator.resolve_week(
			_resolution_request(state, true, opening.planning_result, null)
		)
		if not resolution.is_success():
			return _result(
				"ten-week headless loop keeps auditable atomic boundaries",
				false,
				"Week %d resolution failed: %s" % [week, resolution.issues]
			)
		trace.append("resolve:%d:%d" % [week, resolution.operations.size()])
		state = resolution.new_state
	return _result(
		"ten-week headless loop keeps auditable atomic boundaries",
		state.week_index == 11 and trace.size() == 20,
		"Expected ten open/resolve pairs without a scene tree."
	)


func _message_visibility_and_ending_mapping_test() -> Dictionary:
	var reasons: Array[ReasonEntry] = [
		ReasonEntry.create(
			&"player_z",
			&"test",
			&"source",
			&"target",
			0.0,
			&"reason_player_z",
			{},
			&"test",
			ReasonEntry.VISIBILITY_PLAYER
		),
		ReasonEntry.create(
			&"debug_secret",
			&"test",
			&"source",
			&"target",
			0.0,
			&"reason_debug_secret",
			{},
			&"test",
			ReasonEntry.VISIBILITY_DEBUG
		),
		ReasonEntry.create(
			&"player_a",
			&"test",
			&"source",
			&"target",
			0.0,
			&"reason_player_a",
			{},
			&"test",
			ReasonEntry.VISIBILITY_PLAYER
		),
		ReasonEntry.create(
			&"player_x",
			&"test",
			&"source",
			&"target",
			0.0,
			&"reason_player_x",
			{},
			&"test",
			ReasonEntry.VISIBILITY_PLAYER
		),
	]
	var visible: Array[StringName] = WeekFlowCoordinator._player_reason_codes(
		reasons
	)
	var state = CampaignStateFixtures.create_baseline_state()
	var ended = state.duplicate_state()
	ended.situation.ending_id = &"ending_test"
	var messages: Array[MessageRequest] = []
	WeekFlowCoordinator._append_world_messages(
		messages,
		state,
		ended,
		MessageSourceResult.new(),
		&"week_resolution"
	)
	var ending_message: MessageRequest
	for message: MessageRequest in messages:
		if message.source_type == &"week_resolution_situation":
			ending_message = message
			break
	var passed: bool = visible.size() == 2 \
		and not visible.has(&"debug_secret") \
		and ending_message != null \
		and ending_message.category == MessageRequest.CATEGORY_WORLD_EVENT \
		and ending_message.importance == MessageRequest.IMPORTANCE_CRITICAL \
		and ending_message.parameters["ending_id"] == &"ending_test"
	return _result(
		"message visibility caps reasons and ending maps critical",
		passed,
		"Debug reasons leaked, player reasons were not capped, or ending mapping was absent."
	)


func _opening_request(state, week: int):
	var fixture_request = FactionPlannerFixtures.create_request(state)
	return _opening_request_from_planner(fixture_request, week)


func _opening_request_from_planner(fixture_request, week: int):
	for contract in fixture_request.contract_definitions:
		contract.unhandled_policy = &"expire"
		contract.npc_completion_action_id = &""
	var catalog = CatalogContentFixtures.create_catalog()
	var adventurers: Array[AdventurerDefinition] = []
	for definition in catalog.get_all_adventurers():
		if fixture_request.base_state.adventurers.has(definition.id):
			adventurers.append(definition)
	for snapshot in CatalogContentFixtures.create_baseline_team():
		if not fixture_request.base_state.adventurers.has(snapshot.id):
			continue
		var already_added := false
		for definition: AdventurerDefinition in adventurers:
			if definition.id == snapshot.id:
				already_added = true
				break
		if not already_added:
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
	return WeekFlowCoordinator.WeekOpeningRequest.create(
		week,
		fixture_request.base_state,
		adventurers,
		fixture_request.faction_definitions,
		fixture_request.contract_definitions,
		fixture_request.action_definitions,
		fixture_request.problem_definitions,
		catalog.get_all_situations()[0]
	)


func _resolution_request(state, skip_contract: bool, planning_result, definitions):
	var fixture_request = FactionPlannerFixtures.create_request(state)
	var catalog = CatalogContentFixtures.create_catalog()
	return WeekFlowCoordinator.WeekResolutionRequest.create(
		state.week_index,
		state,
		skip_contract,
		definitions,
		fixture_request.action_definitions,
		catalog.get_all_situations()[0]
	)


func _accepted_fixture_state(with_supply: bool) -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var offer_result = ContractOfferService.create_offer(
		ContractOfferFixtures.create_request(state)
	)
	if not offer_result.is_success():
		return {}
	var offered = CampaignTransaction.apply(state, offer_result.operations)
	if not offered.is_success():
		return {}
	var definitions = ContractOfferFixtures.create_planning_definitions()
	var supply_ids: Array[StringName] = []
	if with_supply:
		supply_ids.append(&"supply_medical")
	var member_ids: Array[StringName] = []
	member_ids.assign(offered.new_state.adventurers.keys())
	member_ids.sort()
	var command := PlanContractCommand.create(
		offered.new_state.pending_contracts[0].instance_id,
		member_ids,
		supply_ids,
		&"balanced"
	)
	var accepted = ContractOfferService.accept_offer(
		offered.new_state,
		command,
		definitions
	)
	if not accepted.is_success():
		return {}
	var committed = CampaignTransaction.apply(
		offered.new_state,
		accepted.operations
	)
	if not committed.is_success() \
			or committed.new_state.pending_contracts[0].status \
				!= ContractOfferState.STATUS_ACCEPTED:
		return {}
	var catalog = CatalogContentFixtures.create_catalog()
	return {
		"state": committed.new_state,
		"definitions": definitions,
		"situation": catalog.get_all_situations()[0],
	}


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
