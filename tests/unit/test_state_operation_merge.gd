extends RefCounted

const StateOperation = preload("res://game/core/result/state_operation.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_numeric_merge_and_order_test(),
		_reason_order_test(),
		_collection_dedupe_test(),
		_conflict_tests(),
		_unknown_dispatch_tests(),
	]


func _numeric_merge_and_order_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state(100)
	var operations: Array[StateOperation] = [
		_op(
			CampaignTransaction.TARGET_GUILD,
			CampaignTransaction.ID_GUILD,
			CampaignTransaction.FIELD_GOLD,
			StateOperation.OP_ADD_INT,
			-250,
			&"large_cost",
			20
		),
		_op(
			CampaignTransaction.TARGET_GUILD,
			CampaignTransaction.ID_GUILD,
			CampaignTransaction.FIELD_GOLD,
			StateOperation.OP_ADD_INT,
			100,
			&"reward",
			10
		),
	]
	var forward = CampaignTransaction.apply(state, operations)
	operations.reverse()
	var reverse = CampaignTransaction.apply(state, operations)
	var passed: bool = forward.is_success() \
		and reverse.is_success() \
		and forward.new_state.guild.gold == 0 \
		and reverse.new_state.guild.gold == 0 \
		and _change_signatures(forward.state_changes) == _change_signatures(reverse.state_changes)
	return _result(
		"numeric deltas merge then clamp once independent of input order",
		passed,
		"Expected both orderings to produce gold 0 and identical audit changes."
	)


func _reason_order_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var operations: Array[StateOperation] = [
		_op(
			CampaignTransaction.TARGET_CLOCK,
			&"dragon_exhaustion",
			CampaignTransaction.FIELD_VALUE,
			StateOperation.OP_ADD_INT,
			1,
			&"reason_z",
			20
		),
		_op(
			CampaignTransaction.TARGET_CLOCK,
			&"dragon_exhaustion",
			CampaignTransaction.FIELD_VALUE,
			StateOperation.OP_ADD_INT,
			2,
			&"reason_b",
			10
		),
		_op(
			CampaignTransaction.TARGET_CLOCK,
			&"dragon_exhaustion",
			CampaignTransaction.FIELD_VALUE,
			StateOperation.OP_ADD_INT,
			3,
			&"reason_a",
			10
		),
	]
	var applied = CampaignTransaction.apply(state, operations)
	var expected: Array[StringName] = [&"reason_a", &"reason_b", &"reason_z"]
	var passed: bool = applied.is_success() \
		and applied.state_changes.size() == 1 \
		and applied.state_changes[0].reason_codes == expected
	return _result(
		"reason codes use source order then stable reason code",
		passed,
		"Expected reason_a, reason_b, reason_z; got %s."
			% [applied.state_changes[0].reason_codes if applied.state_changes.size() == 1 else []]
	)


func _collection_dedupe_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var operation := _op(
		CampaignTransaction.TARGET_SITUATION,
		state.situation.definition_id,
		CampaignTransaction.FIELD_UNLOCKED_CONTRACT_IDS,
		StateOperation.OP_ADD_UNIQUE,
		&"contract_test_unlock",
		&"unlock_contract",
		600
	)
	var operations: Array[StateOperation] = [
		operation,
		operation.duplicate_value(),
	]
	var applied = CampaignTransaction.apply(state, operations)
	var passed: bool = applied.is_success() \
		and applied.new_state.situation.unlocked_contract_ids == [
			&"contract_test_unlock",
		]
	return _result(
		"same collection request is stably deduplicated",
		passed,
		"Expected one unlocked contract ID."
	)


func _conflict_tests() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var different_sets: Array[StateOperation] = [
		_op(
			CampaignTransaction.TARGET_SITUATION,
			state.situation.definition_id,
			CampaignTransaction.FIELD_PHASE_ID,
			StateOperation.OP_SET_ID,
			&"phase_open_conflict",
			&"phase_one",
			600
		),
		_op(
			CampaignTransaction.TARGET_SITUATION,
			state.situation.definition_id,
			CampaignTransaction.FIELD_PHASE_ID,
			StateOperation.OP_SET_ID,
			&"phase_final_window",
			&"phase_two",
			600
		),
	]
	var add_remove: Array[StateOperation] = [
		_op(
			CampaignTransaction.TARGET_SITUATION,
			state.situation.definition_id,
			CampaignTransaction.FIELD_TRIGGERED_RULE_IDS,
			StateOperation.OP_ADD_UNIQUE,
			&"trigger_test",
			&"add_trigger",
			600
		),
		_op(
			CampaignTransaction.TARGET_SITUATION,
			state.situation.definition_id,
			CampaignTransaction.FIELD_TRIGGERED_RULE_IDS,
			StateOperation.OP_REMOVE_UNIQUE,
			&"trigger_test",
			&"remove_trigger",
			600
		),
	]
	var event_one := WorldEventState.create(
		&"event_duplicate",
		&"event_first",
		1,
		&"offer_test",
		&"",
		[&"first_reason"]
	)
	var event_two := WorldEventState.create(
		&"event_duplicate",
		&"event_second",
		1,
		&"offer_test",
		&"",
		[&"second_reason"]
	)
	var records: Array[StateOperation] = [
		_op(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_WORLD_EVENTS,
			StateOperation.OP_APPEND_RECORD,
			event_one,
			&"first_reason",
			600
		),
		_op(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_WORLD_EVENTS,
			StateOperation.OP_APPEND_RECORD,
			event_two,
			&"second_reason",
			600
		),
	]
	var passed: bool = not CampaignTransaction.apply(state, different_sets).is_success() \
		and not CampaignTransaction.apply(state, add_remove).is_success() \
		and not CampaignTransaction.apply(state, records).is_success()
	return _result(
		"set, add-remove, and record conflicts reject the batch",
		passed,
		"Expected all three documented conflict types to fail."
	)


func _unknown_dispatch_tests() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var candidates: Array[StateOperation] = [
		_op(&"unknown_kind", &"x", &"gold", StateOperation.OP_ADD_INT, 1, &"test", 1),
		_op(
			CampaignTransaction.TARGET_FACTION,
			&"faction_missing",
			CampaignTransaction.FIELD_RELATION,
			StateOperation.OP_ADD_INT,
			1,
			&"test",
			1
		),
		_op(
			CampaignTransaction.TARGET_GUILD,
			CampaignTransaction.ID_GUILD,
			&"unknown_field",
			StateOperation.OP_ADD_INT,
			1,
			&"test",
			1
		),
		_op(
			CampaignTransaction.TARGET_GUILD,
			CampaignTransaction.ID_GUILD,
			CampaignTransaction.FIELD_GOLD,
			&"unknown_operation",
			1,
			&"test",
			1
		),
	]
	for candidate: StateOperation in candidates:
		var one: Array[StateOperation] = [candidate]
		if CampaignTransaction.apply(state, one).is_success():
			return _result(
				"unknown dispatch inputs are rejected",
				false,
				"An unknown kind, target, field, or operation was accepted."
			)
	return _result(
		"unknown dispatch inputs are rejected",
		true,
		""
	)


func _op(
	target_kind: StringName,
	target_id: StringName,
	field_id: StringName,
	operation: StringName,
	value: Variant,
	reason_code: StringName,
	source_order: int
) -> StateOperation:
	return StateOperation.create(
		target_kind,
		target_id,
		field_id,
		operation,
		value,
		reason_code,
		source_order
	)


func _change_signatures(changes: Array) -> PackedStringArray:
	var signatures := PackedStringArray()
	for change in changes:
		signatures.append(change.signature())
	return signatures


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
