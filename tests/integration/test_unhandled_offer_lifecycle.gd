extends RefCounted

const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const FactionTurnPlanner = preload(
	"res://game/domain/simulation/faction_turn_planner.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const FactionPlannerFixtures = preload(
	"res://tests/fixtures/faction_planner_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_policy_matrix_test(),
		_inactive_problem_expires_test(),
		_shared_problem_escalates_once_test(),
		_missing_reference_rolls_back_test(),
		_lifecycle_determinism_test(),
	]


func _policy_matrix_test() -> Dictionary:
	var expired = _run_scenario(&"expire", 50, true, true)
	var npc_completed = _run_scenario(&"npc_or_expire", 5, true, true)
	var npc_expired = _run_scenario(&"npc_or_expire", 4, true, true)
	var npc_escalated = _run_scenario(&"npc_or_escalate", 4, true, true)
	var escalated = _run_scenario(&"escalate", 50, true, false)
	var passed: bool = _status(expired) == ContractOfferState.STATUS_EXPIRED \
		and _status(npc_completed) == ContractOfferState.STATUS_NPC_COMPLETED \
		and _status(npc_expired) == ContractOfferState.STATUS_EXPIRED \
		and _status(npc_escalated) == ContractOfferState.STATUS_ESCALATED \
		and _status(escalated) == ContractOfferState.STATUS_ESCALATED \
		and npc_completed.world_events.size() == 1 \
		and expired.world_events.is_empty() \
		and npc_expired.world_events.is_empty()
	return _result(
		"all four unhandled policies follow executable and fallback branches",
		passed,
		"Unexpected expire, NPC completion, or escalation policy result."
	)


func _inactive_problem_expires_test() -> Dictionary:
	var result = _run_scenario(&"escalate", 50, false, false)
	return _result(
		"inactive related problem forces natural expiration",
		result.is_success() \
			and _status(result) == ContractOfferState.STATUS_EXPIRED \
			and result.world_events.is_empty(),
		"Inactive problems must not be escalated twice."
	)


func _missing_reference_rolls_back_test() -> Dictionary:
	var setup := _setup()
	var state = setup["state"]
	var definitions = setup["request"].contract_definitions
	var offer = state.pending_contracts[0]
	for definition in definitions:
		if definition.id == offer.definition_id:
			definition.unhandled_policy = &"npc_or_expire"
			definition.npc_completion_action_id = &"action_missing"
	var before := CampaignStateFixtures.state_signature(state)
	var result = ContractOfferService.resolve_unhandled_offers(
		state,
		state.week_index,
		definitions,
		setup["request"].faction_definitions,
		setup["request"].action_definitions,
		setup["request"].problem_definitions
	)
	return _result(
		"missing lifecycle reference rejects the entire batch",
		not result.is_success() \
			and result.operations.is_empty() \
			and CampaignStateFixtures.state_signature(state) == before,
		"Missing action reference produced partial lifecycle intent."
	)


func _shared_problem_escalates_once_test() -> Dictionary:
	var opening = FactionTurnPlanner.plan_week(
		FactionPlannerFixtures.create_request()
	)
	var state = opening.new_state.duplicate_state()
	var first_offer = state.pending_contracts[0]
	var second_offer = state.pending_contracts[1]
	var shared_problem_id: StringName = first_offer.related_problem_id
	second_offer.related_problem_id = shared_problem_id
	state.pending_contracts.clear()
	state.pending_contracts.append(first_offer)
	state.pending_contracts.append(second_offer)
	state.week_index = maxi(first_offer.expires_week, second_offer.expires_week) + 1
	var request = FactionPlannerFixtures.create_request(state)
	for offer in request.base_state.pending_contracts:
		for definition in request.contract_definitions:
			if definition.id == offer.definition_id:
				definition.unhandled_policy = &"escalate"
				definition.npc_completion_action_id = &""
	var result = ContractOfferService.resolve_unhandled_offers(
		request.base_state,
		request.base_state.week_index,
		request.contract_definitions,
		request.faction_definitions,
		request.action_definitions,
		request.problem_definitions
	)
	var expected_event_count := 0
	for problem in request.problem_definitions:
		if problem.id != shared_problem_id:
			continue
		for effect in problem.escalation_effects:
			if effect.type == &"create_world_event":
				expected_event_count += 1
	var escalated_count := 0
	var expired_count := 0
	for offer in result.updated_offers:
		if offer.status == ContractOfferState.STATUS_ESCALATED:
			escalated_count += 1
		elif offer.status == ContractOfferState.STATUS_EXPIRED:
			expired_count += 1
	return _result(
		"two expired offers sharing a problem apply escalation once",
		result.is_success() \
			and escalated_count == 1 \
			and expired_count == 1 \
			and result.world_events.size() == expected_event_count,
		"Sequential result issues=%s escalated=%d expired=%d events=%d"
			% [
				result.issues,
				escalated_count,
				expired_count,
				result.world_events.size(),
			]
	)


func _lifecycle_determinism_test() -> Dictionary:
	var setup := _setup()
	var state = setup["state"]
	var request = setup["request"]
	var offer = state.pending_contracts[0]
	for definition in request.contract_definitions:
		if definition.id == offer.definition_id:
			definition.unhandled_policy = &"expire"
			definition.npc_completion_action_id = &""
	var baseline = ContractOfferService.resolve_unhandled_offers(
		state,
		state.week_index,
		request.contract_definitions,
		request.faction_definitions,
		request.action_definitions,
		request.problem_definitions
	)
	if not baseline.is_success():
		return _result(
			"unhandled lifecycle repeats 100 times identically",
			false,
			"Baseline lifecycle failed: %s" % baseline.issues
		)
	var signature := CampaignStateFixtures.state_signature(baseline.new_state)
	for _iteration: int in range(100):
		var repeated = ContractOfferService.resolve_unhandled_offers(
			state,
			state.week_index,
			request.contract_definitions,
			request.faction_definitions,
			request.action_definitions,
			request.problem_definitions
		)
		if not repeated.is_success() \
				or CampaignStateFixtures.state_signature(repeated.new_state) != signature:
			return _result(
				"unhandled lifecycle repeats 100 times identically",
				false,
				"Offer ordering or terminal output changed."
			)
	return _result("unhandled lifecycle repeats 100 times identically", true, "")


func _run_scenario(
	policy: StringName,
	influence: int,
	problem_active: bool,
	with_action: bool
):
	var setup := _setup()
	var state = setup["state"]
	var request = setup["request"]
	var offer = state.pending_contracts[0]
	var selected_action
	for faction in request.faction_definitions:
		if faction.id == offer.sponsor_faction_id:
			for action in request.action_definitions:
				if action.id == faction.weekly_action_ids[0]:
					selected_action = action
					break
			faction.weekly_action_ids.clear()
			faction.weekly_action_ids.append(selected_action.id)
			break
	selected_action.target_lock_key = offer.target_lock_key
	selected_action.influence_cost = 5
	state.factions[offer.sponsor_faction_id].influence = influence
	if not problem_active:
		state.situation.problems[offer.related_problem_id] = WorldProblemState.create(
			offer.related_problem_id,
			WorldProblemState.STATUS_RESOLVED,
			0,
			10,
			state.week_index,
			&"",
			&"fixture_problem_resolved"
		)
	for definition in request.contract_definitions:
		if definition.id == offer.definition_id:
			definition.unhandled_policy = policy
			definition.npc_completion_action_id = (
				selected_action.id if with_action else &""
			)
	return ContractOfferService.resolve_unhandled_offers(
		state,
		state.week_index,
		request.contract_definitions,
		request.faction_definitions,
		request.action_definitions,
		request.problem_definitions
	)


func _setup() -> Dictionary:
	var opening = FactionTurnPlanner.plan_week(
		FactionPlannerFixtures.create_request()
	)
	assert(opening.is_success())
	var state = opening.new_state.duplicate_state()
	var offer = state.pending_contracts[0]
	state.pending_contracts.clear()
	state.pending_contracts.append(offer)
	state.week_index = offer.expires_week + 1
	var request = FactionPlannerFixtures.create_request(state)
	return {"state": request.base_state, "request": request}


func _status(result) -> StringName:
	return (
		result.updated_offers[0].status
		if result != null and result.is_success() \
			and not result.updated_offers.is_empty()
		else &""
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else message}
