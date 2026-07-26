extends RefCounted

const FactionTurnPlanner = preload(
	"res://game/domain/simulation/faction_turn_planner.gd"
)
const FactionIntentCandidate = preload(
	"res://game/domain/factions/faction_intent_candidate.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const DeclinedOfferSuppressionKey = preload(
	"res://game/domain/contracts/declined_offer_suppression_key.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const FactionPlannerFixtures = preload(
	"res://tests/fixtures/faction_planner_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_empty_columns_choose_offers_test(),
		_pending_columns_choose_actions_test(),
		_two_pass_lock_priority_test(),
		_priority_and_suppression_test(),
		_origin_dedup_and_influence_boundary_test(),
		_deterministic_planning_test(),
		_commitment_resolution_projection_test(),
	]


func _empty_columns_choose_offers_test() -> Dictionary:
	var request = FactionPlannerFixtures.create_request()
	var before := CampaignStateFixtures.state_signature(request.base_state)
	var result = FactionTurnPlanner.plan_week(request)
	var passed: bool = result.is_success() \
		and result.new_offers.size() == 3 \
		and result.new_commitments.is_empty() \
		and result.new_state.pending_contracts.size() == 3 \
		and request.base_state.faction_action_commitments.is_empty() \
		and CampaignStateFixtures.state_signature(request.base_state) == before
	return _result(
		"empty faction columns create offers only and preserve inputs",
		passed,
		"Expected three offers, no actions, one atomic new state, and pure inputs."
	)


func _pending_columns_choose_actions_test() -> Dictionary:
	var opening = FactionTurnPlanner.plan_week(
		FactionPlannerFixtures.create_request()
	)
	if not opening.is_success():
		return _result(
			"pending factions keep offers and reserve actions atomically",
			false,
			"Could not create opening offers: %s" % opening.issues
		)
	var request = FactionPlannerFixtures.create_request(opening.new_state)
	var before_influence := 0
	for faction_id: StringName in request.base_state.factions:
		before_influence += request.base_state.factions[faction_id].influence
	var planned = FactionTurnPlanner.plan_week(request)
	var after_influence := 0
	if planned.is_success():
		for faction_id: StringName in planned.new_state.factions:
			after_influence += planned.new_state.factions[faction_id].influence
	var passed: bool = planned.is_success() \
		and planned.new_offers.is_empty() \
		and planned.new_commitments.size() == 3 \
		and planned.new_state.pending_contracts.size() == 3 \
		and planned.new_state.faction_action_commitments.size() == 3 \
		and after_influence == before_influence - 15
	return _result(
		"pending factions keep offers and reserve actions atomically",
		passed,
		"Expected three retained Offers, three commitments, and one influence debit each."
	)


func _two_pass_lock_priority_test() -> Dictionary:
	var first = FactionTurnPlanner.plan_week(
		FactionPlannerFixtures.create_request()
	)
	if not first.is_success():
		return _result(
			"contract pass reserves locks before direct action pass",
			false,
			"Could not seed offers."
		)
	var mixed_state = first.new_state.duplicate_state()
	var kept_offer = mixed_state.pending_contracts[0]
	mixed_state.pending_contracts.clear()
	mixed_state.pending_contracts.append(kept_offer)
	var request = FactionPlannerFixtures.create_request(mixed_state)
	var empty_faction_lock: StringName
	for contract in request.contract_definitions:
		if contract.sponsor_faction_id != kept_offer.sponsor_faction_id:
			empty_faction_lock = contract.target_lock_key
			break
	var kept_primary_action: StringName
	for faction in request.faction_definitions:
		if faction.id == kept_offer.sponsor_faction_id:
			kept_primary_action = faction.weekly_action_ids[0]
	for action in request.action_definitions:
		if action.id == kept_primary_action:
			action.target_lock_key = empty_faction_lock
	var planned = FactionTurnPlanner.plan_week(request)
	var action_used_conflict := false
	var offered_locks: Array[StringName] = []
	for offer in planned.new_offers:
		offered_locks.append(offer.target_lock_key)
	for commitment in planned.new_commitments:
		if offered_locks.has(commitment.target_lock_key):
			action_used_conflict = true
	return _result(
		"contract pass reserves locks before direct action pass",
		planned.is_success() \
			and planned.new_offers.size() == 2 \
			and not action_used_conflict,
		"A direct action consumed a lock needed by the earlier contract pass."
	)


func _priority_and_suppression_test() -> Dictionary:
	var request = FactionPlannerFixtures.create_request()
	var first_contract = request.contract_definitions[0]
	var suppression := DeclinedOfferSuppressionKey.create(
		first_contract.id,
		ContractOfferState.ORIGIN_PROBLEM,
		first_contract.related_problem_id,
		first_contract.target_lock_key
	)
	var suppressed_request = FactionPlannerFixtures.create_request(
		request.base_state,
		[suppression]
	)
	# Task013 publishes multiple contracts per faction. Narrow this formula test
	# to one contract per faction so the suppressed faction has no alternative.
	var one_per_faction: Array = []
	var seen_factions: Dictionary[StringName, bool] = {}
	for contract in suppressed_request.contract_definitions:
		if not seen_factions.has(contract.sponsor_faction_id):
			seen_factions[contract.sponsor_faction_id] = true
			one_per_faction.append(contract)
	suppressed_request.contract_definitions.assign(one_per_faction)
	var result = FactionTurnPlanner.plan_week(suppressed_request)
	var reused := false
	for offer in result.new_offers:
		for reason in offer.generation_reason_entries:
			if reason.code == &"declined_offer_reused_no_alternative":
				reused = true
	var formula_ok := false
	for candidate in result.candidates:
		if candidate.execution_mode == FactionIntentCandidate.MODE_CONTRACT_PROPOSAL:
			formula_ok = candidate.total_priority == (
				candidate.base_priority
				+ candidate.urgency_contribution
				+ candidate.agenda_fit
				- candidate.repeat_penalty
			)
			if formula_ok:
				break
	return _result(
		"priority formula and no-alternative declined reuse are explicit",
		result.is_success() and reused and formula_ok \
			and FactionTurnPlanner._repeat_penalty(3, 3, 1) == 7,
		"Expected four-term priority, round-away cooldown, and fallback reuse reason."
	)


func _deterministic_planning_test() -> Dictionary:
	var request = FactionPlannerFixtures.create_request()
	var baseline = FactionTurnPlanner.plan_week(request)
	if not baseline.is_success():
		return _result(
			"faction planning repeats 100 times identically",
			false,
			"Baseline planning failed: %s" % baseline.issues
		)
	var signature := CampaignStateFixtures.state_signature(baseline.new_state)
	for _iteration: int in range(100):
		var repeated = FactionTurnPlanner.plan_week(request)
		if not repeated.is_success() \
				or CampaignStateFixtures.state_signature(repeated.new_state) != signature:
			return _result(
				"faction planning repeats 100 times identically",
				false,
				"Stable faction/definition/problem ordering changed."
			)
	return _result("faction planning repeats 100 times identically", true, "")


func _origin_dedup_and_influence_boundary_test() -> Dictionary:
	var request = FactionPlannerFixtures.create_request()
	for contract in request.contract_definitions:
		contract.allow_agenda_origin = true
	var opening = FactionTurnPlanner.plan_week(request)
	if not opening.is_success():
		return _result(
			"origin dedup and exact influence boundary remain deterministic",
			false,
			"Opening planning failed: %s" % opening.issues
		)
	var candidate_counts: Dictionary[StringName, int] = {}
	var problem_origins_only := true
	for candidate in opening.candidates:
		if candidate.execution_mode != FactionIntentCandidate.MODE_CONTRACT_PROPOSAL:
			continue
		candidate_counts[candidate.source_definition_id] = (
			candidate_counts.get(candidate.source_definition_id, 0) + 1
		)
		if candidate.origin_type != ContractOfferState.ORIGIN_PROBLEM:
			problem_origins_only = false
	var boundary_state = opening.new_state.duplicate_state()
	var boundary_faction: StringName = boundary_state.pending_contracts[0].sponsor_faction_id
	boundary_state.factions[boundary_faction].influence = 4
	var below_request = FactionPlannerFixtures.create_request(boundary_state)
	var boundary_action_ids: Array[StringName] = []
	for faction in below_request.faction_definitions:
		if faction.id == boundary_faction:
			boundary_action_ids.append_array(faction.weekly_action_ids)
	for action in below_request.action_definitions:
		if boundary_action_ids.has(action.id):
			action.influence_cost = 5
	var below = FactionTurnPlanner.plan_week(below_request)
	boundary_state.factions[boundary_faction].influence = 5
	var exact_request = FactionPlannerFixtures.create_request(boundary_state)
	for action in exact_request.action_definitions:
		if boundary_action_ids.has(action.id):
			action.influence_cost = 5
	var exact = FactionTurnPlanner.plan_week(exact_request)
	var unique_sources: bool = (
		candidate_counts.size() == request.contract_definitions.size()
	)
	for count: int in candidate_counts.values():
		unique_sources = unique_sources and count == 1
	var below_has_faction := false
	for commitment in below.new_commitments:
		if commitment.faction_id == boundary_faction:
			below_has_faction = true
	var exact_has_faction := false
	for commitment in exact.new_commitments:
		if commitment.faction_id == boundary_faction:
			exact_has_faction = true
	return _result(
		"origin dedup and exact influence boundary remain deterministic",
		below.is_success() and exact.is_success() \
			and unique_sources and problem_origins_only \
			and not below_has_faction and exact_has_faction,
		"Expected one problem source per template and cost-1/cost eligibility boundary."
	)


func _commitment_resolution_projection_test() -> Dictionary:
	var opening = FactionTurnPlanner.plan_week(
		FactionPlannerFixtures.create_request()
	)
	var planned = FactionTurnPlanner.plan_week(
		FactionPlannerFixtures.create_request(opening.new_state)
	)
	if not planned.is_success():
		return _result(
			"committed actions project once without a second influence charge",
			false,
			"Could not create commitments: %s" % planned.issues
		)
	var request = FactionPlannerFixtures.create_request(planned.new_state)
	var resolution = FactionTurnPlanner.resolve_commitments(
		planned.new_state,
		planned.new_state.week_index,
		request.action_definitions
	)
	var influence_operations := 0
	for operation in resolution.operations:
		if operation.target_kind == &"faction" and operation.field_id == &"influence":
			influence_operations += 1
	var advanced_state = planned.new_state.duplicate_state()
	advanced_state.week_index += 1
	var committed = CampaignTransaction.apply(
		advanced_state,
		resolution.operations
	)
	var repeated = FactionTurnPlanner.resolve_commitments(
		committed.new_state if committed.is_success() else advanced_state,
		planned.new_state.week_index,
		request.action_definitions
	)
	return _result(
		"committed actions project once without a second influence charge",
		resolution.is_success() \
			and resolution.updated_commitments.size() == 3 \
			and resolution.world_events.size() == 3 \
			and influence_operations == 0 \
			and committed.is_success() \
			and committed.new_state.faction_action_commitments[0].status \
				== &"resolved" \
			and repeated.updated_commitments.is_empty(),
		"Expected one event per due commitment and no resolution-time influence change."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else message}
