extends RefCounted

const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const MessageRequest = preload(
	"res://game/domain/messages/message_request.gd"
)
const WeeklyMessageProjector = preload(
	"res://game/domain/simulation/weekly_message_projector.gd"
)


class CommittedResult extends RefCounted:
	var new_state
	var issues := PackedStringArray()

	func _init(p_new_state) -> void:
		new_state = p_new_state

	func is_success() -> bool:
		return new_state != null and issues.is_empty()


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_permutation_and_category_order_test(),
		_retry_noop_and_conflict_test(),
		_failed_commit_rejection_test(),
		_mark_read_dispatch_test(),
		_parameter_copy_and_type_test(),
		_projection_domain_purity_test(),
		_same_week_sort_continuation_test(),
	]


func _permutation_and_category_order_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var categories: Array[StringName] = [
		MessageRequest.CATEGORY_UPKEEP,
		MessageRequest.CATEGORY_WORLD_EVENT,
		MessageRequest.CATEGORY_CONTRACT_OFFER,
		MessageRequest.CATEGORY_CONTRACT_LIFECYCLE,
		MessageRequest.CATEGORY_FACTION_ACTION,
		MessageRequest.CATEGORY_CONTRACT_RESULT,
		MessageRequest.CATEGORY_WEEK_SUMMARY,
	]
	var requests: Array[MessageRequest] = []
	for index: int in range(categories.size()):
		requests.append(_request(
			categories[index],
			StringName("source_%d" % index),
			StringName("item_%d" % index)
		))
	var permuted_requests: Array[MessageRequest] = [
		requests[0],
		requests[3],
		requests[6],
	]
	var permutations: Array[Array] = []
	_permute(permuted_requests, 0, permutations)
	var expected := ""
	for raw: Array in permutations:
		var permutation: Array[MessageRequest] = []
		permutation.assign(raw)
		var projection = WeeklyMessageProjector.project_requests(
			state,
			CommittedResult.new(state),
			permutation
		)
		if not projection.is_success():
			return _result(
				"all request permutations use stable category order",
				false,
				"Projection failed: %s" % projection.issues
			)
		var signature := _message_signature(projection.new_state)
		if expected.is_empty():
			expected = signature
		elif signature != expected:
			return _result(
				"all request permutations use stable category order",
				false,
				"Permutation changed message identity/order."
			)
	var ordered_categories: Array[StringName] = []
	var final_projection = WeeklyMessageProjector.project_requests(
		state,
		CommittedResult.new(state),
		requests
	)
	for message in final_projection.new_state.message_history:
		ordered_categories.append(message.category)
	var passed: bool = ordered_categories == categories
	return _result(
		"all request permutations use stable category order",
		passed,
			"Expected fixed category order, got %s." % [ordered_categories]
	)


func _retry_noop_and_conflict_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var request := _request(
		MessageRequest.CATEGORY_CONTRACT_OFFER,
		&"contract_offer",
		&"offer_retry"
	)
	var first = WeeklyMessageProjector.project_requests(
		state,
		CommittedResult.new(state),
		[request, request.duplicate_value()]
	)
	if not first.is_success() or first.created_messages.size() != 1:
		return _result("message retries no-op and conflicts reject", false, "%s" % first.issues)
	var retry = WeeklyMessageProjector.project_requests(
		first.new_state,
		first,
		[request]
	)
	var conflict := MessageRequest.create(
		request.category,
		request.source_type,
		request.source_id,
		&"different_title",
		request.body_key,
		request.parameters,
		request.importance
	)
	var rejected = WeeklyMessageProjector.project_requests(
		first.new_state,
		first,
		[conflict]
	)
	var passed: bool = retry.is_success() \
		and retry.created_messages.is_empty() \
		and retry.new_state.message_history.size() == 1 \
		and not rejected.is_success() \
		and rejected.created_messages.is_empty() \
		and rejected.operations.is_empty()
	return _result(
		"message retries no-op and conflicts reject",
		passed,
		"Retry or conflict behavior was not atomic."
	)


func _failed_commit_rejection_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var failed := CommittedResult.new(null)
	var projected = WeeklyMessageProjector.project_requests(
		state,
		failed,
		[_request(MessageRequest.CATEGORY_UPKEEP, &"upkeep", &"weekly_upkeep")]
	)
	return _result(
		"failed committed results cannot create messages",
		not projected.is_success()
			and projected.operations.is_empty()
			and projected.created_messages.is_empty(),
		"Projection accepted a result without new_state."
	)


func _mark_read_dispatch_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var projected = WeeklyMessageProjector.project_requests(
		state,
		CommittedResult.new(state),
		[_request(MessageRequest.CATEGORY_WORLD_EVENT, &"world_event", &"event_read")]
	)
	if not projected.is_success():
		return _result("mark_read changes only the selected message", false, "%s" % projected.issues)
	var message_id: StringName = projected.new_state.message_history[0].instance_id
	var marked = WeeklyMessageProjector.mark_read(projected.new_state, message_id)
	var passed: bool = marked.is_success() \
		and marked.new_state.message_history[0].is_read \
		and not projected.new_state.message_history[0].is_read \
		and marked.state_changes.size() == 1 \
		and marked.state_changes[0].reason_codes == [&"message_marked_read"]
	return _result(
		"mark_read changes only the selected message",
		passed,
		"Read dispatch mutated the base or omitted its audit reason."
	)


func _parameter_copy_and_type_test() -> Dictionary:
	var nested := {"values": [1, 2]}
	var request := MessageRequest.create(
		MessageRequest.CATEGORY_CONTRACT_OFFER,
		&"contract_offer",
		&"offer_visibility",
		&"message_title",
		&"message_body",
		nested
	)
	nested["values"].append(3)
	var detached: Dictionary = request.parameters
	detached["values"].append(4)
	var passed: bool = request.parameters["values"] == [1, 2] \
		and MessageRequest.create(
			MessageRequest.CATEGORY_UPKEEP,
			&"source",
			&"invalid_parameters",
			&"title",
			&"body",
			{"object": RefCounted.new()}
		) == null
	return _result(
		"parameters detach and reject object values",
		passed,
		"Mutable parameters aliased or unsupported values were accepted."
	)


func _projection_domain_purity_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var before: String = _domain_signature(state)
	var projection = WeeklyMessageProjector.project_requests(
		state,
		CommittedResult.new(state),
		[_request(MessageRequest.CATEGORY_WEEK_SUMMARY, &"week", &"week_0")]
	)
	var passed: bool = projection.is_success() \
		and _domain_signature(state) == before \
		and _domain_signature(projection.new_state) == before \
		and state.message_history.is_empty()
	return _result(
		"message projection leaves domain simulation state unchanged",
		passed,
		"Projection changed non-message campaign data or its input."
	)


func _same_week_sort_continuation_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var first = WeeklyMessageProjector.project_requests(
		state,
		CommittedResult.new(state),
		[_request(MessageRequest.CATEGORY_UPKEEP, &"upkeep", &"first")]
	)
	var second = WeeklyMessageProjector.project_requests(
		first.new_state,
		first,
		[_request(MessageRequest.CATEGORY_WEEK_SUMMARY, &"week", &"second")]
	)
	var passed: bool = second.is_success() \
		and second.new_state.message_history.size() == 2 \
		and second.new_state.message_history[0].sort_order == 0 \
		and second.new_state.message_history[1].sort_order == 1
	return _result(
		"new same-week messages continue existing sort order",
		passed,
		"Existing history was reordered or continuation was not consecutive."
	)


func _request(
	category: StringName,
	source_type: StringName,
	source_id: StringName
) -> MessageRequest:
	return MessageRequest.create(
		category,
		source_type,
		source_id,
		&"message_title",
		&"message_body",
		{"source_id": source_id},
		MessageRequest.IMPORTANCE_NORMAL
	)


func _permute(values: Array[MessageRequest], index: int, output: Array[Array]) -> void:
	if index == values.size():
		output.append(values.duplicate())
		return
	for cursor: int in range(index, values.size()):
		var copy: Array[MessageRequest] = []
		copy.assign(values)
		var held: MessageRequest = copy[index]
		copy[index] = copy[cursor]
		copy[cursor] = held
		_permute(copy, index + 1, output)


func _message_signature(state) -> String:
	var parts := PackedStringArray()
	for message in state.message_history:
		parts.append(message.signature())
	return "|".join(parts)


func _domain_signature(state) -> String:
	var copy = state.duplicate_state()
	copy.message_history.clear()
	return CampaignStateFixtures.state_signature(copy)


func _result(name: String, passed: bool, details: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": details}
