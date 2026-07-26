class_name WeeklyMessageProjector
extends RefCounted

const StableSeed = preload("res://game/core/random/stable_seed.gd")
const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const MessageRequest = preload(
	"res://game/domain/messages/message_request.gd"
)
const MessageState = preload("res://game/domain/messages/message_state.gd")
const StateOperation = preload("res://game/core/result/state_operation.gd")
const StateChange = preload("res://game/core/result/state_change.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)

const REASON_MESSAGE_CREATED: StringName = &"message_projected"
const REASON_MESSAGE_READ: StringName = &"message_marked_read"
const SOURCE_MESSAGES: int = 2000

const CATEGORY_ORDER: Dictionary = {
	MessageRequest.CATEGORY_UPKEEP: 0,
	MessageRequest.CATEGORY_WORLD_EVENT: 1,
	MessageRequest.CATEGORY_CONTRACT_OFFER: 2,
	MessageRequest.CATEGORY_CONTRACT_LIFECYCLE: 3,
	MessageRequest.CATEGORY_FACTION_ACTION: 4,
	MessageRequest.CATEGORY_CONTRACT_RESULT: 5,
	MessageRequest.CATEGORY_WEEK_SUMMARY: 6,
}


class MessageProjectionResult extends RefCounted:
	var operations: Array[StateOperation]
	var created_messages: Array[MessageState]
	var state_changes: Array[StateChange]
	var new_state: CampaignState
	var issues: PackedStringArray

	func is_success() -> bool:
		return new_state != null and issues.is_empty()


## Projects only after a caller exposes a successful committed preview state.
## The returned state includes messages; callers publish it only after success.
static func project_requests(
	base_state: CampaignState,
	committed_result: Variant,
	requests: Array[MessageRequest]
) -> MessageProjectionResult:
	var result := MessageProjectionResult.new()
	if base_state == null:
		result.issues.append("Message projection requires CampaignState.")
	if committed_result == null \
			or not committed_result.has_method("is_success") \
			or not committed_result.call("is_success") \
			or committed_result.get("new_state") == null:
		result.issues.append("Messages require a successful committed result.")
	if not result.issues.is_empty():
		return result
	result.issues.append_array(base_state.validate())

	var ordered: Array[MessageRequest] = []
	for request: MessageRequest in requests:
		if request == null:
			result.issues.append("MessageRequest cannot be null.")
			continue
		var issues: PackedStringArray = request.validate()
		result.issues.append_array(issues)
		ordered.append(request.duplicate_value())
	if not result.issues.is_empty():
		return result
	ordered.sort_custom(_request_less)

	var existing_by_id: Dictionary[StringName, MessageState] = {}
	var next_sort_order := 0
	for message: MessageState in base_state.message_history:
		existing_by_id[message.instance_id] = message
		if message.week_index == base_state.week_index:
			next_sort_order = maxi(next_sort_order, message.sort_order + 1)

	var request_signature_by_id: Dictionary[StringName, String] = {}
	var accepted_requests: Array[MessageRequest] = []
	for request: MessageRequest in ordered:
		var instance_id := _message_id(
			base_state.week_index,
			request.source_type,
			request.source_id,
			request.category
		)
		var request_signature: String = _request_content_signature(request)
		if request_signature_by_id.has(instance_id):
			if request_signature_by_id[instance_id] != request_signature:
				result.issues.append(
					"Conflicting MessageRequests produce ID %s." % instance_id
				)
			continue
		request_signature_by_id[instance_id] = request_signature
		accepted_requests.append(request)
	if not result.issues.is_empty():
		return result

	for request: MessageRequest in accepted_requests:
		var instance_id := _message_id(
			base_state.week_index,
			request.source_type,
			request.source_id,
			request.category
		)
		var candidate_sort: int = (
			existing_by_id[instance_id].sort_order
			if existing_by_id.has(instance_id)
			else next_sort_order
		)
		var message := MessageState.new(
			instance_id,
			base_state.week_index,
			request.category,
			request.source_type,
			request.source_id,
			request.title_key,
			request.body_key,
			request.parameters,
			request.importance,
			candidate_sort,
			false
		)
		var validation: PackedStringArray = message.validate()
		if not validation.is_empty():
			result.issues.append_array(validation)
			continue
		if existing_by_id.has(instance_id):
			if existing_by_id[instance_id].content_signature() \
					!= message.content_signature():
				result.issues.append(
					"Existing message %s has conflicting content." % instance_id
				)
			continue
		next_sort_order += 1
		result.created_messages.append(message.duplicate_state())
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_MESSAGE_HISTORY,
			StateOperation.OP_APPEND_RECORD,
			message,
			REASON_MESSAGE_CREATED,
			SOURCE_MESSAGES + candidate_sort
		))
	if not result.issues.is_empty():
		result.operations.clear()
		result.created_messages.clear()
		return result
	var transaction = CampaignTransaction.apply(base_state, result.operations)
	if not transaction.is_success():
		result.issues.append_array(transaction.issues)
		result.operations.clear()
		result.created_messages.clear()
		return result
	result.new_state = transaction.new_state
	result.state_changes = transaction.state_changes
	return result


static func mark_read(
	base_state: CampaignState,
	message_id: StringName
) -> MessageProjectionResult:
	var result := MessageProjectionResult.new()
	if base_state == null:
		result.issues.append("mark_read requires CampaignState.")
		return result
	var target: MessageState
	for message: MessageState in base_state.message_history:
		if message.instance_id == message_id:
			target = message
			break
	if target == null:
		result.issues.append("Unknown message ID: %s." % message_id)
		return result
	if not target.is_read:
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_MESSAGE,
			message_id,
			CampaignTransaction.FIELD_IS_READ,
			StateOperation.OP_SET_ID,
			CampaignTransaction.VALUE_READ,
			REASON_MESSAGE_READ,
			SOURCE_MESSAGES
		))
	var transaction = CampaignTransaction.apply(base_state, result.operations)
	if not transaction.is_success():
		result.issues.append_array(transaction.issues)
		result.operations.clear()
		return result
	result.new_state = transaction.new_state
	result.state_changes = transaction.state_changes
	return result


static func _message_id(
	week_index: int,
	source_type: StringName,
	source_id: StringName,
	category: StringName
) -> StringName:
	var digest := StableSeed.derive(0, [
		&"message",
		StringName(str(week_index)),
		source_type,
		source_id,
		category,
	])
	return StringName("message_%08x" % digest)


static func _request_less(left: MessageRequest, right: MessageRequest) -> bool:
	if left.trace_order != right.trace_order:
		return left.trace_order < right.trace_order
	var left_category: int = CATEGORY_ORDER[left.category]
	var right_category: int = CATEGORY_ORDER[right.category]
	if left_category != right_category:
		return left_category < right_category
	for pair: Array in [
		[String(left.source_type), String(right.source_type)],
		[String(left.source_id), String(right.source_id)],
		[String(left.title_key), String(right.title_key)],
	]:
		if pair[0] != pair[1]:
			return pair[0] < pair[1]
	return left.signature() < right.signature()


static func _request_content_signature(request: MessageRequest) -> String:
	var content := request.duplicate_value()
	content.trace_order = 0
	return content.signature()
