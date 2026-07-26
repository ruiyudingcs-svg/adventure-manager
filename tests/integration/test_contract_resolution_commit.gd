extends RefCounted

const StateOperation = preload("res://game/core/result/state_operation.gd")
const ContractResolver = preload(
	"res://game/domain/simulation/contract_resolver.gd"
)
const ContractResolutionProjector = preload(
	"res://game/domain/simulation/contract_resolution_projector.gd"
)
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const BaselineContractFixtures = preload(
	"res://tests/fixtures/baseline_contract_fixtures.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_supply_cost_lock_test(),
		_all_baselines_commit_test(),
		_insufficient_gold_test(),
		_atomic_world_member_rollback_test(),
		_duplicate_submission_test(),
	]


func _supply_cost_lock_test() -> Dictionary:
	var expected_costs: Array[int] = [22, 20, 0]
	var requests: Array[Dictionary] = _baseline_requests()
	for index: int in range(requests.size()):
		var resolved = _resolve(requests[index])
		if not resolved.is_success() \
			or resolved.resolution.supply_cost_total != expected_costs[index]:
			return _result(
				"resolver locks selected supply total without deduction",
				false,
				"Expected locked costs 22, 20, and 0."
			)
	return _result(
		"resolver locks selected supply total without deduction",
		true,
		""
	)


func _all_baselines_commit_test() -> Dictionary:
	for request: Dictionary in _baseline_requests():
		var state = CampaignStateFixtures.create_baseline_state()
		var before: String = CampaignStateFixtures.state_signature(state)
		var resolved = _resolve(request)
		if not resolved.is_success():
			return _result(
				"three baseline resolutions commit atomically",
				false,
				"Baseline resolution failed."
			)
		var resolution = resolved.resolution
		var resolution_before: String = _resolution_signature(resolution)
		var sponsor_id: StringName = CampaignStateFixtures.sponsor_for_contract(
			request["contract"].definition_id
		)
		var projection = ContractResolutionProjector.project(
			state,
			resolution,
			sponsor_id,
			request["contract"].definition_id
		)
		if not projection.is_success():
			return _result(
				"three baseline resolutions commit atomically",
				false,
				"Projection issues: %s" % projection.issues
			)
		var committed = CampaignTransaction.apply(state, projection.operations)
		if not committed.is_success():
			return _result(
				"three baseline resolutions commit atomically",
				false,
				"Commit issues: %s" % committed.issues
			)
		var expected_gold: int = (
			1000 + resolution.reward - resolution.supply_cost_total
		)
		if committed.new_state.guild.gold != expected_gold \
			or committed.new_state.contract_history.size() != 1 \
			or committed.new_state.factions[sponsor_id].relation \
				!= resolution.sponsor_relation_delta \
			or CampaignStateFixtures.state_signature(state) != before \
			or _resolution_signature(resolution) != resolution_before:
			return _result(
				"three baseline resolutions commit atomically",
				false,
				"Gold, relation, history, or input purity did not match."
			)
		for outcome in resolution.member_outcomes:
			var member = committed.new_state.adventurers[outcome.member_id]
			var member_before = state.adventurers[outcome.member_id]
			if member.get_fatigue() \
					!= clampi(member_before.get_fatigue() + outcome.fatigue_delta, 0, 100) \
				or member.get_morale() \
					!= clampi(member_before.get_morale() + outcome.morale_delta, 0, 100) \
				or member.get_injury_severity() != outcome.injury_severity_after \
				or member.get_recovery_weeks_remaining() != outcome.recovery_weeks_after \
				or member.get_is_available() != outcome.is_available_after:
				return _result(
					"three baseline resolutions commit atomically",
					false,
					"Member outcome did not commit for %s." % outcome.member_id
				)
	return _result(
		"three baseline resolutions commit atomically",
		true,
		""
	)


func _insufficient_gold_test() -> Dictionary:
	var request: Dictionary = BaselineContractFixtures.create_binding_request()
	var resolved = _resolve(request)
	var state = CampaignStateFixtures.create_baseline_state(19)
	var before: String = CampaignStateFixtures.state_signature(state)
	var projection = ContractResolutionProjector.project(
		state,
		resolved.resolution,
		&"faction_arcane_guild",
		request["contract"].definition_id
	)
	var passed: bool = not projection.is_success() \
		and projection.operations.is_empty() \
		and CampaignStateFixtures.state_signature(state) == before
	return _result(
		"locked supply cost must be affordable before reward",
		passed,
		"Expected 19 gold to reject a locked cost of 20 with no mutation."
	)


func _atomic_world_member_rollback_test() -> Dictionary:
	var request: Dictionary = BaselineContractFixtures.create_north_request()
	var resolved = _resolve(request)
	var state = CampaignStateFixtures.create_baseline_state()
	var before: String = CampaignStateFixtures.state_signature(state)
	var projection = ContractResolutionProjector.project(
		state,
		resolved.resolution,
		&"faction_free_adventurers",
		request["contract"].definition_id
	)
	projection.operations.append(StateOperation.create(
		CampaignTransaction.TARGET_CLOCK,
		&"clock_missing",
		CampaignTransaction.FIELD_VALUE,
		StateOperation.OP_ADD_INT,
		10,
		&"invalid_world_target",
		600
	))
	var committed = CampaignTransaction.apply(state, projection.operations)
	var passed: bool = not committed.is_success() \
		and committed.new_state == null \
		and CampaignStateFixtures.state_signature(state) == before
	return _result(
		"illegal world target rolls back member and guild effects",
		passed,
		"Expected the complete projected batch to fail without mutation."
	)


func _duplicate_submission_test() -> Dictionary:
	var request: Dictionary = BaselineContractFixtures.create_corpse_request()
	var resolved = _resolve(request)
	var state = CampaignStateFixtures.create_baseline_state()
	var projection = ContractResolutionProjector.project(
		state,
		resolved.resolution,
		&"faction_necrotic_collective",
		request["contract"].definition_id
	)
	var first = CampaignTransaction.apply(state, projection.operations)
	if not first.is_success():
		return _result(
			"duplicate contract submission is rejected",
			false,
			"First commit unexpectedly failed: %s" % first.issues
		)
	var before_retry: String = CampaignStateFixtures.state_signature(first.new_state)
	var retry = CampaignTransaction.apply(first.new_state, projection.operations)
	var passed: bool = not retry.is_success() \
		and retry.new_state == null \
		and CampaignStateFixtures.state_signature(first.new_state) == before_retry
	return _result(
		"duplicate contract submission is rejected",
		passed,
		"Existing history ID must reject the whole repeated transaction."
	)


func _baseline_requests() -> Array[Dictionary]:
	return [
		BaselineContractFixtures.create_north_request(),
		BaselineContractFixtures.create_binding_request(),
		BaselineContractFixtures.create_corpse_request(),
	]


func _resolve(request: Dictionary):
	return ContractResolver.resolve(
		request["contract"],
		request["plan"],
		request["seed"],
		request["guild_base_cohesion"]
	)


func _resolution_signature(resolution) -> String:
	var members := PackedStringArray()
	for outcome in resolution.member_outcomes:
		members.append("%s:%d:%d:%d:%s" % [
			outcome.member_id,
			outcome.fatigue_delta,
			outcome.morale_delta,
			outcome.injury_severity_after,
			outcome.is_available_after,
		])
	return "%s|%d|%d|%s|%s|%d" % [
		resolution.contract_instance_id,
		resolution.reward,
		resolution.supply_cost_total,
		resolution.consumed_supply_ids,
		members,
		resolution.situation_outcomes.size(),
	]


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
