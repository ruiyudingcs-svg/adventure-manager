extends RefCounted

const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const StateOperation = preload("res://game/core/result/state_operation.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_deep_copy_commit_test(),
		_final_validation_rollback_test(),
		_operation_input_purity_test(),
		_same_record_dedupe_test(),
	]


func _deep_copy_commit_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var original_signature: String = CampaignStateFixtures.state_signature(state)
	var operations: Array[StateOperation] = [
		StateOperation.create(
			CampaignTransaction.TARGET_GUILD,
			CampaignTransaction.ID_GUILD,
			CampaignTransaction.FIELD_GOLD,
			StateOperation.OP_ADD_INT,
			25,
			&"test_income",
			1
		),
	]
	var applied = CampaignTransaction.apply(state, operations)
	if not applied.is_success():
		return _result(
			"transaction commits an isolated deep copy",
			false,
			"Unexpected issues: %s" % applied.issues
		)
	applied.new_state.guild.gold += 10
	var passed: bool = CampaignStateFixtures.state_signature(state) == original_signature \
		and state.guild.gold == 1000 \
		and applied.new_state.guild.gold == 1035
	return _result(
		"transaction commits an isolated deep copy",
		passed,
		"Mutating returned state must not affect the base state."
	)


func _final_validation_rollback_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var before: String = CampaignStateFixtures.state_signature(state)
	var invalid_history := ContractHistoryEntry.create_resolved(
		1,
		&"offer_missing_sponsor",
		&"contract_test",
		&"faction_missing",
		&"",
		[],
		[],
		&"balanced",
		&"success",
		10,
		[]
	)
	var operations: Array[StateOperation] = [
		StateOperation.create(
			CampaignTransaction.TARGET_GUILD,
			CampaignTransaction.ID_GUILD,
			CampaignTransaction.FIELD_GOLD,
			StateOperation.OP_ADD_INT,
			10,
			&"test_income",
			1
		),
		StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_CONTRACT_HISTORY,
			StateOperation.OP_APPEND_RECORD,
			invalid_history,
			&"test_history",
			2
		),
	]
	var applied = CampaignTransaction.apply(state, operations)
	var passed: bool = not applied.is_success() \
		and applied.new_state == null \
		and applied.state_changes.is_empty() \
		and CampaignStateFixtures.state_signature(state) == before
	return _result(
		"final reference failure rolls back every change",
		passed,
		"Expected missing sponsor reference to reject income and history together."
	)


func _operation_input_purity_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var operation := StateOperation.create(
		CampaignTransaction.TARGET_CLOCK,
		&"settlement_destruction",
		CampaignTransaction.FIELD_VALUE,
		StateOperation.OP_ADD_INT,
		7,
		&"test_clock",
		9
	)
	var operations: Array[StateOperation] = [operation]
	var applied = CampaignTransaction.apply(state, operations)
	var passed: bool = applied.is_success() \
		and operation.value == 7 \
		and operation.reason_code == &"test_clock" \
		and operation.source_order == 9 \
		and state.situation.clock_values[&"settlement_destruction"] == 10 \
		and applied.new_state.situation.clock_values[&"settlement_destruction"] == 17
	return _result(
		"transaction does not mutate StateOperation inputs",
		passed,
		"Expected operation and base clock to remain unchanged."
	)


func _same_record_dedupe_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var history := ContractHistoryEntry.create_resolved(
		1,
		&"offer_same_record",
		&"contract_test",
		&"faction_free_adventurers",
		&"",
		[],
		[],
		&"balanced",
		&"success",
		10,
		[]
	)
	var operation := StateOperation.create(
		CampaignTransaction.TARGET_CAMPAIGN,
		CampaignTransaction.ID_CAMPAIGN,
		CampaignTransaction.FIELD_CONTRACT_HISTORY,
		StateOperation.OP_APPEND_RECORD,
		history,
		&"test_history",
		1
	)
	var operations: Array[StateOperation] = [
		operation,
		operation.duplicate_value(),
	]
	var applied = CampaignTransaction.apply(state, operations)
	var passed: bool = applied.is_success() \
		and applied.new_state.contract_history.size() == 1
	return _result(
		"identical records in one batch dedupe by stable ID",
		passed,
		"Expected one history record."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
