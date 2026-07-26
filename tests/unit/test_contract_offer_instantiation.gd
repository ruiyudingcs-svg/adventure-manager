extends RefCounted

const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const ContractOfferFixtures = preload(
	"res://tests/fixtures/contract_offer_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_relation_boundaries_test(),
		_determinism_test(),
		_overlay_merge_and_order_test(),
		_locked_snapshot_and_effective_contract_test(),
		_duplicate_offer_state_validation_test(),
	]


func _relation_boundaries_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var expectations: Array[Array] = [
		[24, ContractOfferState.RELATION_TIER_STANDARD, 0, 1.00],
		[25, ContractOfferState.RELATION_TIER_FAVORABLE, 1, 1.10],
		[59, ContractOfferState.RELATION_TIER_FAVORABLE, 1, 1.10],
		[60, ContractOfferState.RELATION_TIER_TRUSTED, 2, 1.20],
	]
	for expected: Array in expectations:
		var request = ContractOfferFixtures.create_request(state, expected[0])
		var result = ContractOfferService.create_offer(request)
		if not result.is_success():
			return _result(
				"relation 24/25/59/60 locks duration and reward once",
				false,
				"Offer creation failed: %s" % result.issues
			)
		var offer = result.created_offer
		var definition = request.definition
		var expected_expires: int = (
			state.week_index + definition.offer_duration_weeks + expected[2] - 1
		)
		var expected_reward: int = roundi(
			float(definition.base_reward) * float(expected[3])
		)
		if offer.applied_relation_tier != expected[1] \
			or offer.expires_week != expected_expires \
			or offer.offered_reward != expected_reward \
			or offer.sponsor_relation_snapshot != expected[0]:
			return _result(
				"relation 24/25/59/60 locks duration and reward once",
				false,
				"Unexpected locked tier, expiry, reward, or exact relation."
			)
	return _result(
		"relation 24/25/59/60 locks duration and reward once",
		true,
		""
	)


func _determinism_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var request = ContractOfferFixtures.create_request(state, 25)
	var baseline = ContractOfferService.create_offer(request)
	if not baseline.is_success():
		return _result(
			"same offer request repeats 100 times",
			false,
			"Baseline creation failed: %s" % baseline.issues
		)
	var signature: String = baseline.created_offer.content_signature()
	for _iteration: int in range(100):
		var repeated = ContractOfferService.create_offer(request)
		if not repeated.is_success() \
			or repeated.created_offer.content_signature() != signature:
			return _result(
				"same offer request repeats 100 times",
				false,
				"Offer ID, seed, snapshot, or reason ordering changed."
			)
	return _result("same offer request repeats 100 times", true, "")


func _overlay_merge_and_order_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var catalog_request = ContractOfferFixtures.create_request(state)
	var check_id: StringName = catalog_request.definition.stages[0].check.id
	var rules: Array[ContractDefinition.OfferInstantiationRule] = [
		ContractOfferFixtures.rule(
			&"overlay_zeta", check_id, 10, &"intel", 3
		),
		ContractOfferFixtures.rule(
			&"overlay_alpha", check_id, 10, &"intel", 3
		),
		ContractOfferFixtures.rule(
			&"overlay_middle", check_id, 10, &"intel", 3
		),
	]
	var reversed: Array[ContractDefinition.OfferInstantiationRule] = rules.duplicate()
	reversed.reverse()
	var first = ContractOfferService.create_offer(
		ContractOfferFixtures.create_request(state, 0, rules)
	)
	var second = ContractOfferService.create_offer(
		ContractOfferFixtures.create_request(state, 0, reversed)
	)
	var passed: bool = first.is_success() \
		and second.is_success() \
		and first.created_offer.instantiation_snapshot.content_signature() \
			== second.created_offer.instantiation_snapshot.content_signature() \
		and first.created_offer.instantiation_snapshot.check_difficulty_deltas[0] \
			.difficulty_delta == 20 \
		and first.created_offer.instantiation_snapshot.initial_context \
			.get_value(&"intel") == 6
	return _result(
		"offer overlays merge then clamp independent of rule input order",
		passed,
		"Expected difficulty +20, intel 6, and identical sorted snapshots."
	)


func _locked_snapshot_and_effective_contract_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var request = ContractOfferFixtures.create_request(state, -50)
	var created = ContractOfferService.create_offer(request)
	if not created.is_success():
		return _result(
			"effective contract reads only locked offer data",
			false,
			"Offer creation failed: %s" % created.issues
		)
	var definitions = ContractOfferFixtures.create_planning_definitions()
	var definition = definitions.contract_definitions[
		ContractOfferFixtures.CONTRACT_ID
	]
	var before: String = definitions.content_signature()
	var effective = ContractOfferService.build_effective_contract(
		created.created_offer,
		definition,
		definitions.clauses,
		definitions.method_tag_definitions
	)
	state.factions[created.created_offer.sponsor_faction_id].relation = 100
	state.situation.clock_values[&"settlement_destruction"] = 100
	var rebuilt = ContractOfferService.build_effective_contract(
		created.created_offer,
		definition,
		definitions.clauses,
		definitions.method_tag_definitions
	)
	var passed: bool = effective != null \
		and rebuilt != null \
		and effective.offered_reward == rebuilt.offered_reward \
		and effective.sponsor_relation_snapshot == -50 \
		and definitions.content_signature() == before
	return _result(
		"effective contract reads only locked offer data",
		passed,
		"Current world changes must not alter reward, relation, overlay, or inputs."
	)


func _duplicate_offer_state_validation_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var created = ContractOfferService.create_offer(
		ContractOfferFixtures.create_request(state)
	)
	if not created.is_success():
		return _result(
			"campaign rejects duplicate offer IDs and target locks",
			false,
			"Offer creation failed: %s" % created.issues
		)
	var first = created.created_offer
	var duplicate_id = first.duplicate_state()
	state.pending_contracts.clear()
	state.pending_contracts.append(first)
	state.pending_contracts.append(duplicate_id)
	var id_rejected: bool = not state.validate().is_empty()
	var duplicate_lock = first.duplicate_state()
	duplicate_lock.instance_id = &"contract_offer_deadbeef"
	state.pending_contracts.clear()
	state.pending_contracts.append(first)
	state.pending_contracts.append(duplicate_lock)
	var lock_rejected: bool = not state.validate().is_empty()
	return _result(
		"campaign rejects duplicate offer IDs and target locks",
		id_rejected and lock_rejected,
		"Expected complete state validation to reject both duplicate forms."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
