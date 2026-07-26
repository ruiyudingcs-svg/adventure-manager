class_name CampaignTransaction
extends RefCounted

const CampaignState = preload(
	"res://game/domain/campaign/campaign_state.gd"
)
const AdventurerState = preload(
	"res://game/domain/adventurers/adventurer_state.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const ContractPlanState = preload(
	"res://game/domain/contracts/contract_plan_state.gd"
)
const FactionActionCommitmentState = preload(
	"res://game/domain/factions/faction_action_commitment_state.gd"
)
const MessageState = preload("res://game/domain/messages/message_state.gd")
const StateOperation = preload("res://game/core/result/state_operation.gd")
const StateChange = preload("res://game/core/result/state_change.gd")
const StableId = preload("res://game/core/ids/stable_id.gd")

const TARGET_GUILD: StringName = &"guild"
const TARGET_ADVENTURER: StringName = &"adventurer"
const TARGET_FACTION: StringName = &"faction"
const TARGET_SITUATION: StringName = &"situation"
const TARGET_CLOCK: StringName = &"clock"
const TARGET_PROBLEM: StringName = &"problem"
const TARGET_CAMPAIGN: StringName = &"campaign"
const TARGET_CONTRACT_OFFER: StringName = &"contract_offer"
const TARGET_FACTION_ACTION_COMMITMENT: StringName = &"faction_action_commitment"
const TARGET_MESSAGE: StringName = &"message"

const ID_GUILD: StringName = &"guild"
const ID_CAMPAIGN: StringName = &"campaign"

const FIELD_GOLD: StringName = &"gold"
const FIELD_REPUTATION: StringName = &"reputation"
const FIELD_BASE_COHESION: StringName = &"base_cohesion"
const FIELD_WEEKLY_MAINTENANCE: StringName = &"weekly_maintenance"
const FIELD_FATIGUE: StringName = &"fatigue"
const FIELD_MORALE: StringName = &"morale"
const FIELD_INJURY_SEVERITY: StringName = &"injury_severity"
const FIELD_RECOVERY_WEEKS: StringName = &"recovery_weeks_remaining"
const FIELD_AVAILABILITY: StringName = &"availability"
const FIELD_RELATION: StringName = &"relation"
const FIELD_INFLUENCE: StringName = &"influence"
const FIELD_PHASE_ID: StringName = &"phase_id"
const FIELD_TRIGGERED_RULE_IDS: StringName = &"triggered_rule_ids"
const FIELD_UNLOCKED_CONTRACT_IDS: StringName = &"unlocked_contract_ids"
const FIELD_ENDING_ID: StringName = &"ending_id"
const FIELD_VALUE: StringName = &"value"
const FIELD_STATUS: StringName = &"status"
const FIELD_OPENED_WEEK: StringName = &"opened_week"
const FIELD_RESPONSE_DEADLINE_WEEK: StringName = &"response_deadline_week"
const FIELD_CLOSED_WEEK: StringName = &"closed_week"
const FIELD_SOURCE_EVENT_ID: StringName = &"source_event_id"
const FIELD_RESOLUTION_REASON_CODE: StringName = &"resolution_reason_code"
const FIELD_CONTRACT_HISTORY: StringName = &"contract_history"
const FIELD_WORLD_EVENTS: StringName = &"world_events"
const FIELD_PENDING_CONTRACTS: StringName = &"pending_contracts"
const FIELD_ACTIVE_PLAN: StringName = &"active_plan"
const FIELD_DECLINED_OFFER_WEEK: StringName = &"declined_offer_week"
const FIELD_FACTION_ACTION_COMMITMENTS: StringName = &"faction_action_commitments"
const FIELD_RESOLVED_WEEK: StringName = &"resolved_week"
const FIELD_TERMINAL_REASON_CODE: StringName = &"terminal_reason_code"
const FIELD_WORLD_EVENT_IDS: StringName = &"world_event_ids"
const FIELD_WEEK_INDEX: StringName = &"week_index"
const FIELD_RECENT_ASSIGNMENT_COUNT: StringName = &"recent_assignment_count"
const FIELD_RECENT_NEGLECT_COUNT: StringName = &"recent_neglect_count"
const FIELD_MESSAGE_HISTORY: StringName = &"message_history"
const FIELD_IS_READ: StringName = &"is_read"

const VALUE_AVAILABLE: StringName = &"available"
const VALUE_UNAVAILABLE: StringName = &"unavailable"
const VALUE_READ: StringName = &"read"
const VALUE_UNREAD: StringName = &"unread"


class CampaignTransactionResult extends RefCounted:
	var new_state: CampaignState
	var state_changes: Array[StateChange]
	var issues: PackedStringArray

	func is_success() -> bool:
		return new_state != null and issues.is_empty()


## Applies a complete operation batch to a deep copy and returns it only after
## full validation. This boundary must remain atomic because callers may retry.
static func apply(
	base_state: CampaignState,
	operations: Array[StateOperation]
) -> CampaignTransactionResult:
	var result := CampaignTransactionResult.new()
	if base_state == null:
		result.issues.append("CampaignTransaction requires a base state.")
		return result
	var base_issues: PackedStringArray = base_state.validate()
	if not base_issues.is_empty():
		result.issues.append_array(base_issues)
		return result

	var copied_operations: Array[StateOperation] = []
	for operation: StateOperation in operations:
		if operation == null:
			result.issues.append("StateOperation cannot be null.")
		else:
			copied_operations.append(operation.duplicate_value())
	if not result.issues.is_empty():
		return result

	copied_operations.sort_custom(_operation_less)
	result.issues.append_array(_validate_operations(base_state, copied_operations))
	if not result.issues.is_empty():
		return result
	result.issues.append_array(_validate_merge_conflicts(copied_operations))
	if not result.issues.is_empty():
		return result

	var temporary_state: CampaignState = base_state.duplicate_state()
	var grouped: Array[Array] = _group_operations(copied_operations)
	for group: Array[StateOperation] in grouped:
		var old_value: Variant = _read_field(temporary_state, group[0])
		var apply_issue: String = _apply_group(temporary_state, group)
		if not apply_issue.is_empty():
			result.issues.append(apply_issue)
			return result
		var new_value: Variant = _read_field(temporary_state, group[0])
		if old_value != new_value:
			result.state_changes.append(StateChange.create(
				group[0].target_id,
				_field_path(group[0]),
				old_value,
				new_value,
				_sorted_reason_codes(group)
			))

	var final_issues: PackedStringArray = temporary_state.validate()
	if not final_issues.is_empty():
		result.issues.append_array(final_issues)
		result.state_changes.clear()
		return result
	result.state_changes.sort_custom(_state_change_less)
	result.new_state = temporary_state
	return result


static func _validate_operations(
	state: CampaignState,
	operations: Array[StateOperation]
) -> PackedStringArray:
	var errors := PackedStringArray()
	for operation: StateOperation in operations:
		if not StateOperation.is_allowed_operation(operation.operation):
			errors.append("Unknown StateOperation operation: %s." % operation.operation)
			continue
		if operation.reason_code.is_empty():
			errors.append("StateOperation.reason_code is required.")
		if operation.source_order < 0:
			errors.append("StateOperation.source_order must be non-negative.")
		var field_issue: String = _validate_field_dispatch(state, operation)
		if not field_issue.is_empty():
			errors.append(field_issue)
	return errors


# Explicit match dispatch is the executable whitelist. Never replace it with
# Object.set(field_path), because operation data crosses a trust boundary.
static func _validate_field_dispatch(
	state: CampaignState,
	operation: StateOperation
) -> String:
	match operation.target_kind:
		TARGET_GUILD:
			if operation.target_id != ID_GUILD:
				return "Unknown guild target ID: %s." % operation.target_id
			if not [
				FIELD_GOLD,
				FIELD_REPUTATION,
				FIELD_BASE_COHESION,
				FIELD_WEEKLY_MAINTENANCE,
			].has(operation.field_id):
				return "Unknown guild field: %s." % operation.field_id
			return _require_add_int(operation)
		TARGET_ADVENTURER:
			if not state.adventurers.has(operation.target_id):
				return "Unknown adventurer target ID: %s." % operation.target_id
			if [
				FIELD_FATIGUE,
				FIELD_MORALE,
				FIELD_INJURY_SEVERITY,
				FIELD_RECOVERY_WEEKS,
				FIELD_RECENT_ASSIGNMENT_COUNT,
				FIELD_RECENT_NEGLECT_COUNT,
			].has(operation.field_id):
				return _require_add_int(operation)
			if operation.field_id == FIELD_AVAILABILITY:
				if operation.operation != StateOperation.OP_SET_ID:
					return "Adventurer availability requires set_id."
				if operation.value != VALUE_AVAILABLE and operation.value != VALUE_UNAVAILABLE:
					return "Adventurer availability value is not allowed."
				return ""
			return "Unknown adventurer field: %s." % operation.field_id
		TARGET_FACTION:
			if not state.factions.has(operation.target_id):
				return "Unknown faction target ID: %s." % operation.target_id
			if operation.field_id != FIELD_RELATION and operation.field_id != FIELD_INFLUENCE:
				return "Unknown faction field: %s." % operation.field_id
			return _require_add_int(operation)
		TARGET_SITUATION:
			if operation.target_id != state.situation.definition_id:
				return "Unknown situation target ID: %s." % operation.target_id
			match operation.field_id:
				FIELD_PHASE_ID, FIELD_ENDING_ID:
					if operation.operation != StateOperation.OP_SET_ID:
						return "Situation field %s requires set_id." % operation.field_id
					if not StableId.is_valid(StringName(operation.value)):
						return "Situation set_id value must be a stable ID."
				FIELD_TRIGGERED_RULE_IDS, FIELD_UNLOCKED_CONTRACT_IDS:
					if (
						operation.operation != StateOperation.OP_ADD_UNIQUE
						and operation.operation != StateOperation.OP_REMOVE_UNIQUE
					):
						return "Situation collection field requires add_unique or remove_unique."
					if not StableId.is_valid(StringName(operation.value)):
						return "Situation collection value must be a stable ID."
				_:
					return "Unknown situation field: %s." % operation.field_id
			return ""
		TARGET_CLOCK:
			if not state.situation.clock_values.has(operation.target_id):
				return "Unknown clock target ID: %s." % operation.target_id
			if operation.field_id != FIELD_VALUE:
				return "Unknown clock field: %s." % operation.field_id
			return _require_add_int(operation)
		TARGET_PROBLEM:
			if not state.situation.problems.has(operation.target_id):
				return "Unknown problem target ID: %s." % operation.target_id
			if [
				FIELD_OPENED_WEEK,
				FIELD_RESPONSE_DEADLINE_WEEK,
				FIELD_CLOSED_WEEK,
			].has(operation.field_id):
				return _require_add_int(operation)
			if operation.field_id == FIELD_STATUS:
				if operation.operation != StateOperation.OP_SET_ID:
					return "Problem status requires set_id."
				if not WorldProblemState.ALLOWED_STATUSES.has(StringName(operation.value)):
					return "Problem status value is not allowed."
				return ""
			if [
				FIELD_SOURCE_EVENT_ID,
				FIELD_RESOLUTION_REASON_CODE,
			].has(operation.field_id):
				if operation.operation != StateOperation.OP_SET_ID:
					return "Problem ID fields require set_id."
				var problem_id_value := StringName(operation.value)
				if not problem_id_value.is_empty() \
					and not StableId.is_valid(problem_id_value):
					return "Problem ID field value must be empty or a stable ID."
				return ""
			return "Unknown problem field: %s." % operation.field_id
		TARGET_CAMPAIGN:
			if operation.target_id != ID_CAMPAIGN:
				return "Unknown campaign target ID: %s." % operation.target_id
			if (
				operation.field_id == FIELD_CONTRACT_HISTORY
				and operation.operation == StateOperation.OP_APPEND_RECORD
				and operation.value is ContractHistoryEntry
			):
				return ""
			if (
				operation.field_id == FIELD_WORLD_EVENTS
				and operation.operation == StateOperation.OP_APPEND_RECORD
				and operation.value is WorldEventState
			):
				return ""
			if operation.field_id == FIELD_PENDING_CONTRACTS:
				if (
					operation.operation == StateOperation.OP_APPEND_RECORD
					and operation.value is ContractOfferState
				):
					return ""
				if (
					operation.operation == StateOperation.OP_REMOVE_UNIQUE
					and StableId.is_valid(StringName(operation.value))
				):
					return ""
			if operation.field_id == FIELD_ACTIVE_PLAN:
				if (
					operation.operation == StateOperation.OP_APPEND_RECORD
					and operation.value is ContractPlanState
				):
					return ""
				if (
					operation.operation == StateOperation.OP_REMOVE_UNIQUE
					and StableId.is_valid(StringName(operation.value))
				):
					return ""
			if operation.field_id == FIELD_DECLINED_OFFER_WEEK:
				return _require_add_int(operation)
			if operation.field_id == FIELD_WEEK_INDEX:
				var week_issue := _require_add_int(operation)
				if not week_issue.is_empty():
					return week_issue
				if int(operation.value) != 1:
					return "Campaign week_index may only advance by one."
				return ""
			if (
				operation.field_id == FIELD_FACTION_ACTION_COMMITMENTS
				and operation.operation == StateOperation.OP_APPEND_RECORD
				and operation.value is FactionActionCommitmentState
			):
				return ""
			if (
				operation.field_id == FIELD_MESSAGE_HISTORY
				and operation.operation == StateOperation.OP_APPEND_RECORD
				and operation.value is MessageState
			):
				return ""
			return "Unknown campaign field or incompatible operation: %s." % operation.field_id
		TARGET_CONTRACT_OFFER:
			var offer: ContractOfferState = _find_offer(state, operation.target_id)
			if offer == null:
				return "Unknown contract offer target ID: %s." % operation.target_id
			if operation.field_id == FIELD_STATUS:
				if operation.operation != StateOperation.OP_SET_ID:
					return "Contract offer status requires set_id."
				var next_status := StringName(operation.value)
				if not ContractOfferState.ALLOWED_STATUSES.has(next_status):
					return "Contract offer status value is not allowed."
				if not offer.can_transition_to(next_status):
					return "Illegal contract offer transition %s -> %s." % [
						offer.status,
						next_status,
					]
				return ""
			if operation.field_id == FIELD_RESOLVED_WEEK:
				return _require_add_int(operation)
			if operation.field_id == FIELD_TERMINAL_REASON_CODE:
				if operation.operation != StateOperation.OP_SET_ID:
					return "Contract offer terminal reason requires set_id."
				var reason_value := StringName(operation.value)
				if not reason_value.is_empty() and not StableId.is_valid(reason_value):
					return "Contract offer terminal reason must be empty or a stable ID."
				return ""
			return "Unknown contract offer field: %s." % operation.field_id
		TARGET_FACTION_ACTION_COMMITMENT:
			var commitment: FactionActionCommitmentState = _find_commitment(
				state,
				operation.target_id
			)
			if commitment == null:
				return "Unknown faction action commitment ID: %s." % operation.target_id
			if operation.field_id == FIELD_STATUS:
				if operation.operation != StateOperation.OP_SET_ID:
					return "Faction action status requires set_id."
				if StringName(operation.value) != \
					FactionActionCommitmentState.STATUS_RESOLVED:
					return "Faction action commitment may only transition to resolved."
				if commitment.status != FactionActionCommitmentState.STATUS_COMMITTED:
					return "Only committed faction actions can resolve."
				return ""
			if operation.field_id == FIELD_RESOLVED_WEEK:
				return _require_add_int(operation)
			if operation.field_id == FIELD_WORLD_EVENT_IDS:
				if operation.operation != StateOperation.OP_ADD_UNIQUE:
					return "Faction action event IDs require add_unique."
				if not StableId.is_valid(StringName(operation.value)):
					return "Faction action event ID must be stable."
				return ""
			return "Unknown faction action commitment field: %s." % operation.field_id
		TARGET_MESSAGE:
			if _find_message(state, operation.target_id) == null:
				return "Unknown message target ID: %s." % operation.target_id
			if operation.field_id != FIELD_IS_READ:
				return "Unknown message field: %s." % operation.field_id
			if operation.operation != StateOperation.OP_SET_ID:
				return "Message read state requires set_id."
			if StringName(operation.value) != VALUE_READ:
				return "Message read state may only transition to read."
			return ""
		_:
			return "Unknown StateOperation target kind: %s." % operation.target_kind
	return ""


static func _require_add_int(operation: StateOperation) -> String:
	if operation.operation != StateOperation.OP_ADD_INT:
		return "%s.%s requires add_int." % [operation.target_kind, operation.field_id]
	if typeof(operation.value) != TYPE_INT:
		return "add_int value must be an int."
	return ""


static func _validate_merge_conflicts(
	operations: Array[StateOperation]
) -> PackedStringArray:
	var errors := PackedStringArray()
	var groups: Array[Array] = _group_operations(operations)
	for raw_group: Array in groups:
		var group: Array[StateOperation] = []
		group.assign(raw_group)
		var set_signature: String = ""
		var set_found := false
		var collection_actions: Dictionary[String, StringName] = {}
		var record_signatures: Dictionary[StringName, String] = {}
		var record_actions: Dictionary[StringName, StringName] = {}
		for operation: StateOperation in group:
			match operation.operation:
				StateOperation.OP_SET_ID:
					var current_signature: String = var_to_str(operation.value)
					if set_found and set_signature != current_signature:
						errors.append("Conflicting set_id values for %s." % _field_path(operation))
					set_signature = current_signature
					set_found = true
				StateOperation.OP_ADD_UNIQUE, StateOperation.OP_REMOVE_UNIQUE:
					var value_key: String = var_to_str(operation.value)
					if (
						collection_actions.has(value_key)
						and collection_actions[value_key] != operation.operation
					):
						errors.append("Cannot add and remove the same value for %s." % _field_path(operation))
					collection_actions[value_key] = operation.operation
					if (
						operation.field_id == FIELD_PENDING_CONTRACTS
						or operation.field_id == FIELD_ACTIVE_PLAN
					):
						var removed_record_id := StringName(operation.value)
						if (
							record_actions.has(removed_record_id)
							and record_actions[removed_record_id] != operation.operation
						):
							errors.append(
								"Cannot append and remove record %s for %s."
								% [removed_record_id, _field_path(operation)]
							)
						record_actions[removed_record_id] = operation.operation
				StateOperation.OP_APPEND_RECORD:
					var record_id: StringName = _record_id(operation.value)
					var record_signature: String = _record_signature(operation.value)
					if (
						record_signatures.has(record_id)
						and record_signatures[record_id] != record_signature
					):
						errors.append("Conflicting record contents for ID %s." % record_id)
					record_signatures[record_id] = record_signature
					if (
						record_actions.has(record_id)
						and record_actions[record_id] != operation.operation
					):
						errors.append(
							"Cannot append and remove record %s for %s."
							% [record_id, _field_path(operation)]
						)
					record_actions[record_id] = operation.operation
	return errors


static func _group_operations(operations: Array[StateOperation]) -> Array[Array]:
	var groups: Array[Array] = []
	var active_key: String = ""
	for operation: StateOperation in operations:
		var key: String = _field_key(operation)
		if groups.is_empty() or key != active_key:
			var new_group: Array[StateOperation] = []
			groups.append(new_group)
			active_key = key
		groups[groups.size() - 1].append(operation)
	return groups


static func _apply_group(
	state: CampaignState,
	group: Array[StateOperation]
) -> String:
	var operation: StateOperation = group[0]
	if (
		operation.target_kind == TARGET_CAMPAIGN
		and (
			operation.field_id == FIELD_PENDING_CONTRACTS
			or operation.field_id == FIELD_ACTIVE_PLAN
		)
	):
		return _apply_singleton_or_record_collection(state, group)
	match operation.operation:
		StateOperation.OP_ADD_INT:
			var total_delta: int = 0
			for item: StateOperation in group:
				total_delta += int(item.value)
			# All deltas are summed before this single clamp, preserving cancellation.
			return _apply_numeric_delta(state, operation, total_delta)
		StateOperation.OP_SET_ID:
			return _apply_set(state, operation)
		StateOperation.OP_ADD_UNIQUE, StateOperation.OP_REMOVE_UNIQUE:
			return _apply_unique_values(state, group)
		StateOperation.OP_APPEND_RECORD:
			return _append_records(state, group)
	return "Unsupported merged operation: %s." % operation.operation


static func _apply_numeric_delta(
	state: CampaignState,
	operation: StateOperation,
	delta: int
) -> String:
	match operation.target_kind:
		TARGET_GUILD:
			match operation.field_id:
				FIELD_GOLD:
					state.guild.gold = maxi(0, state.guild.gold + delta)
				FIELD_REPUTATION:
					state.guild.reputation = clampi(state.guild.reputation + delta, 0, 100)
				FIELD_BASE_COHESION:
					state.guild.base_cohesion = clampi(
						state.guild.base_cohesion + delta,
						0,
						100
					)
				FIELD_WEEKLY_MAINTENANCE:
					state.guild.weekly_maintenance = maxi(
						0,
						state.guild.weekly_maintenance + delta
					)
		TARGET_ADVENTURER:
			var member: AdventurerState = state.adventurers[operation.target_id]
			var fatigue: int = member.get_fatigue()
			var morale: int = member.get_morale()
			var injury: int = member.get_injury_severity()
			var recovery: int = member.get_recovery_weeks_remaining()
			var recent_assignment: int = member.get_recent_assignment_count()
			var recent_neglect: int = member.get_recent_neglect_count()
			match operation.field_id:
				FIELD_FATIGUE:
					fatigue = clampi(fatigue + delta, 0, 100)
				FIELD_MORALE:
					morale = clampi(morale + delta, 0, 100)
				FIELD_INJURY_SEVERITY:
					injury = clampi(injury + delta, 0, 100)
				FIELD_RECOVERY_WEEKS:
					recovery = maxi(0, recovery + delta)
				FIELD_RECENT_ASSIGNMENT_COUNT:
					recent_assignment = clampi(recent_assignment + delta, 0, 3)
				FIELD_RECENT_NEGLECT_COUNT:
					recent_neglect = clampi(recent_neglect + delta, 0, 3)
			state.adventurers[operation.target_id] = _replace_member(
				member,
				fatigue,
				morale,
				injury,
				recovery,
				member.get_is_available(),
				recent_assignment,
				recent_neglect
			)
		TARGET_FACTION:
			var faction = state.factions[operation.target_id]
			if operation.field_id == FIELD_RELATION:
				faction.relation = clampi(faction.relation + delta, -100, 100)
			else:
				faction.influence = clampi(faction.influence + delta, 0, 100)
		TARGET_CLOCK:
			state.situation.clock_values[operation.target_id] = clampi(
				state.situation.clock_values[operation.target_id] + delta,
				0,
				100
			)
		TARGET_PROBLEM:
			var problem = state.situation.problems[operation.target_id]
			match operation.field_id:
				FIELD_OPENED_WEEK:
					problem.opened_week += delta
				FIELD_RESPONSE_DEADLINE_WEEK:
					problem.response_deadline_week += delta
				FIELD_CLOSED_WEEK:
					problem.closed_week += delta
		TARGET_CAMPAIGN:
			if operation.field_id == FIELD_DECLINED_OFFER_WEEK:
				state.declined_offer_week += delta
			elif operation.field_id == FIELD_WEEK_INDEX:
				state.week_index += delta
			else:
				return "Numeric dispatch failed for %s." % _field_path(operation)
		TARGET_CONTRACT_OFFER:
			var offer: ContractOfferState = _find_offer(state, operation.target_id)
			if offer == null or operation.field_id != FIELD_RESOLVED_WEEK:
				return "Numeric dispatch failed for %s." % _field_path(operation)
			offer.resolved_week += delta
		TARGET_FACTION_ACTION_COMMITMENT:
			var commitment := _find_commitment(state, operation.target_id)
			if commitment == null or operation.field_id != FIELD_RESOLVED_WEEK:
				return "Numeric dispatch failed for %s." % _field_path(operation)
			commitment.resolved_week += delta
		_:
			return "Numeric dispatch failed for %s." % _field_path(operation)
	return ""


static func _apply_set(state: CampaignState, operation: StateOperation) -> String:
	match operation.target_kind:
		TARGET_ADVENTURER:
			var member: AdventurerState = state.adventurers[operation.target_id]
			state.adventurers[operation.target_id] = _replace_member(
				member,
				member.get_fatigue(),
				member.get_morale(),
				member.get_injury_severity(),
				member.get_recovery_weeks_remaining(),
				operation.value == VALUE_AVAILABLE
			)
		TARGET_SITUATION:
			if operation.field_id == FIELD_PHASE_ID:
				state.situation.phase_id = StringName(operation.value)
			else:
				state.situation.ending_id = StringName(operation.value)
		TARGET_PROBLEM:
			var problem = state.situation.problems[operation.target_id]
			match operation.field_id:
				FIELD_STATUS:
					problem.status = StringName(operation.value)
				FIELD_SOURCE_EVENT_ID:
					problem.source_event_id = StringName(operation.value)
				FIELD_RESOLUTION_REASON_CODE:
					problem.resolution_reason_code = StringName(operation.value)
		TARGET_CONTRACT_OFFER:
			var offer: ContractOfferState = _find_offer(state, operation.target_id)
			if offer == null:
				return "set_id dispatch failed for %s." % _field_path(operation)
			if operation.field_id == FIELD_STATUS:
				offer.status = StringName(operation.value)
			else:
				offer.terminal_reason_code = StringName(operation.value)
		TARGET_FACTION_ACTION_COMMITMENT:
			var commitment := _find_commitment(state, operation.target_id)
			if commitment == null or operation.field_id != FIELD_STATUS:
				return "set_id dispatch failed for %s." % _field_path(operation)
			commitment.status = StringName(operation.value)
		TARGET_MESSAGE:
			var message: MessageState = _find_message(state, operation.target_id)
			if message == null or operation.field_id != FIELD_IS_READ:
				return "set_id dispatch failed for %s." % _field_path(operation)
			message.is_read = true
		_:
			return "set_id dispatch failed for %s." % _field_path(operation)
	return ""


static func _apply_unique_values(
	state: CampaignState,
	group: Array[StateOperation]
) -> String:
	var operation: StateOperation = group[0]
	var values: Array[StringName]
	if operation.target_kind == TARGET_FACTION_ACTION_COMMITMENT:
		var commitment := _find_commitment(state, operation.target_id)
		if commitment == null:
			return "Faction action commitment does not exist: %s." % operation.target_id
		values = commitment.world_event_ids
	elif operation.field_id == FIELD_TRIGGERED_RULE_IDS:
		values = state.situation.triggered_rule_ids
	else:
		values = state.situation.unlocked_contract_ids
	for item: StateOperation in group:
		var value: StringName = StringName(item.value)
		if item.operation == StateOperation.OP_ADD_UNIQUE:
			if not values.has(value):
				values.append(value)
		else:
			values.erase(value)
	values.sort_custom(_stable_id_less)
	return ""


static func _apply_singleton_or_record_collection(
	state: CampaignState,
	group: Array[StateOperation]
) -> String:
	var field_id: StringName = group[0].field_id
	for operation: StateOperation in group:
		if field_id == FIELD_PENDING_CONTRACTS:
			if operation.operation == StateOperation.OP_REMOVE_UNIQUE:
				var removed_id := StringName(operation.value)
				var removed := false
				for index: int in range(state.pending_contracts.size() - 1, -1, -1):
					if state.pending_contracts[index].instance_id == removed_id:
						var offer_issues: PackedStringArray = (
							state.pending_contracts[index].validate()
						)
						if not offer_issues.is_empty():
							return (
								"Cannot remove invalid contract offer %s: %s"
								% [removed_id, offer_issues[0]]
							)
						state.pending_contracts.remove_at(index)
						removed = true
				if not removed:
					return "Contract offer ID does not exist: %s." % removed_id
			elif operation.operation == StateOperation.OP_APPEND_RECORD:
				var incoming: ContractOfferState = operation.value
				for existing: ContractOfferState in state.pending_contracts:
					if existing.instance_id == incoming.instance_id:
						if existing.content_signature() == incoming.content_signature():
							incoming = null
							break
						return "Conflicting contract offer contents for ID %s." % existing.instance_id
				if incoming != null:
					state.pending_contracts.append(incoming.duplicate_state())
			else:
				return "Unsupported pending contract operation: %s." % operation.operation
		else:
			if operation.operation == StateOperation.OP_REMOVE_UNIQUE:
				var expected_id := StringName(operation.value)
				if state.active_plan == null:
					return "Campaign active plan is already empty."
				if state.active_plan.contract_instance_id != expected_id:
					return "Campaign active plan references a different contract offer."
				state.active_plan = null
			elif operation.operation == StateOperation.OP_APPEND_RECORD:
				var plan: ContractPlanState = operation.value
				if state.active_plan != null:
					if state.active_plan.content_signature() == plan.content_signature():
						continue
					return "Campaign active plan is already occupied."
				state.active_plan = plan.duplicate_state()
			else:
				return "Unsupported active plan operation: %s." % operation.operation
	return ""


static func _append_records(
	state: CampaignState,
	group: Array[StateOperation]
) -> String:
	var existing_ids: Dictionary[StringName, bool] = {}
	if group[0].field_id == FIELD_CONTRACT_HISTORY:
		for entry: ContractHistoryEntry in state.contract_history:
			existing_ids[entry.contract_instance_id] = true
	elif group[0].field_id == FIELD_WORLD_EVENTS:
		for event: WorldEventState in state.world_events:
			existing_ids[event.instance_id] = true
	elif group[0].field_id == FIELD_MESSAGE_HISTORY:
		for message: MessageState in state.message_history:
			existing_ids[message.instance_id] = true
	else:
		for commitment: FactionActionCommitmentState in state.faction_action_commitments:
			existing_ids[commitment.instance_id] = true
	var appended_ids: Dictionary[StringName, bool] = {}
	for operation: StateOperation in group:
		var record_id: StringName = _record_id(operation.value)
		if existing_ids.has(record_id):
			# Existing history makes a repeated command invalid rather than silently
			# idempotent, so rewards and member effects cannot be applied twice.
			return "Record ID already exists in campaign state: %s." % record_id
		if appended_ids.has(record_id):
			continue
		appended_ids[record_id] = true
		if operation.field_id == FIELD_CONTRACT_HISTORY:
			var entry: ContractHistoryEntry = operation.value
			state.contract_history.append(entry.duplicate_state())
		elif operation.field_id == FIELD_WORLD_EVENTS:
			var event: WorldEventState = operation.value
			state.world_events.append(event.duplicate_state())
		elif operation.field_id == FIELD_MESSAGE_HISTORY:
			var message: MessageState = operation.value
			state.message_history.append(message.duplicate_state())
		else:
			var commitment: FactionActionCommitmentState = operation.value
			state.faction_action_commitments.append(commitment.duplicate_state())
	if group[0].field_id == FIELD_MESSAGE_HISTORY:
		state.message_history.sort_custom(_message_less)
	return ""


static func _read_field(state: CampaignState, operation: StateOperation) -> Variant:
	match operation.target_kind:
		TARGET_GUILD:
			match operation.field_id:
				FIELD_GOLD:
					return state.guild.gold
				FIELD_REPUTATION:
					return state.guild.reputation
				FIELD_BASE_COHESION:
					return state.guild.base_cohesion
				FIELD_WEEKLY_MAINTENANCE:
					return state.guild.weekly_maintenance
		TARGET_ADVENTURER:
			var member: AdventurerState = state.adventurers[operation.target_id]
			match operation.field_id:
				FIELD_FATIGUE:
					return member.get_fatigue()
				FIELD_MORALE:
					return member.get_morale()
				FIELD_INJURY_SEVERITY:
					return member.get_injury_severity()
				FIELD_RECOVERY_WEEKS:
					return member.get_recovery_weeks_remaining()
				FIELD_AVAILABILITY:
					return (
						VALUE_AVAILABLE
						if member.get_is_available()
						else VALUE_UNAVAILABLE
					)
				FIELD_RECENT_ASSIGNMENT_COUNT:
					return member.get_recent_assignment_count()
				FIELD_RECENT_NEGLECT_COUNT:
					return member.get_recent_neglect_count()
		TARGET_FACTION:
			var faction = state.factions[operation.target_id]
			return faction.relation if operation.field_id == FIELD_RELATION else faction.influence
		TARGET_SITUATION:
			match operation.field_id:
				FIELD_PHASE_ID:
					return state.situation.phase_id
				FIELD_TRIGGERED_RULE_IDS:
					return state.situation.triggered_rule_ids.duplicate()
				FIELD_UNLOCKED_CONTRACT_IDS:
					return state.situation.unlocked_contract_ids.duplicate()
				FIELD_ENDING_ID:
					return state.situation.ending_id
		TARGET_CLOCK:
			return state.situation.clock_values[operation.target_id]
		TARGET_PROBLEM:
			var problem = state.situation.problems[operation.target_id]
			match operation.field_id:
				FIELD_STATUS:
					return problem.status
				FIELD_OPENED_WEEK:
					return problem.opened_week
				FIELD_RESPONSE_DEADLINE_WEEK:
					return problem.response_deadline_week
				FIELD_CLOSED_WEEK:
					return problem.closed_week
				FIELD_SOURCE_EVENT_ID:
					return problem.source_event_id
				FIELD_RESOLUTION_REASON_CODE:
					return problem.resolution_reason_code
		TARGET_CAMPAIGN:
			if operation.field_id == FIELD_WEEK_INDEX:
				return state.week_index
			if operation.field_id == FIELD_CONTRACT_HISTORY:
				return _history_signatures(state.contract_history)
			if operation.field_id == FIELD_WORLD_EVENTS:
				return _event_signatures(state.world_events)
			if operation.field_id == FIELD_PENDING_CONTRACTS:
				return _offer_signatures(state.pending_contracts)
			if operation.field_id == FIELD_ACTIVE_PLAN:
				return (
					""
					if state.active_plan == null
					else state.active_plan.content_signature()
				)
			if operation.field_id == FIELD_FACTION_ACTION_COMMITMENTS:
				return _commitment_signatures(state.faction_action_commitments)
			if operation.field_id == FIELD_MESSAGE_HISTORY:
				return _message_signatures(state.message_history)
			return state.declined_offer_week
		TARGET_CONTRACT_OFFER:
			var offer: ContractOfferState = _find_offer(state, operation.target_id)
			if offer == null:
				return null
			match operation.field_id:
				FIELD_STATUS:
					return offer.status
				FIELD_RESOLVED_WEEK:
					return offer.resolved_week
				FIELD_TERMINAL_REASON_CODE:
					return offer.terminal_reason_code
		TARGET_FACTION_ACTION_COMMITMENT:
			var commitment := _find_commitment(state, operation.target_id)
			if commitment == null:
				return null
			match operation.field_id:
				FIELD_STATUS:
					return commitment.status
				FIELD_RESOLVED_WEEK:
					return commitment.resolved_week
				FIELD_WORLD_EVENT_IDS:
					return commitment.world_event_ids.duplicate()
		TARGET_MESSAGE:
			var message: MessageState = _find_message(state, operation.target_id)
			if message == null:
				return null
			return VALUE_READ if message.is_read else VALUE_UNREAD
	return null


static func _replace_member(
	member: AdventurerState,
	fatigue: int,
	morale: int,
	injury: int,
	recovery: int,
	is_available: bool,
	recent_assignment_count: int = -1,
	recent_neglect_count: int = -1
) -> AdventurerState:
	return AdventurerState.create(
		member.definition_id,
		fatigue,
		morale,
		injury,
		recovery,
		member.get_growth_xp(),
		is_available,
		member.get_relationship_deltas(),
		(
			member.get_recent_assignment_count()
			if recent_assignment_count < 0
			else recent_assignment_count
		),
		(
			member.get_recent_neglect_count()
			if recent_neglect_count < 0
			else recent_neglect_count
		)
	)


static func _history_signatures(entries: Array[ContractHistoryEntry]) -> PackedStringArray:
	var signatures := PackedStringArray()
	for entry: ContractHistoryEntry in entries:
		signatures.append(entry.content_signature())
	return signatures


static func _event_signatures(events: Array[WorldEventState]) -> PackedStringArray:
	var signatures := PackedStringArray()
	for event: WorldEventState in events:
		signatures.append(event.content_signature())
	return signatures


static func _offer_signatures(offers: Array[ContractOfferState]) -> PackedStringArray:
	var signatures := PackedStringArray()
	for offer: ContractOfferState in offers:
		signatures.append(offer.content_signature())
	return signatures


static func _commitment_signatures(
	commitments: Array[FactionActionCommitmentState]
) -> PackedStringArray:
	var signatures := PackedStringArray()
	for commitment: FactionActionCommitmentState in commitments:
		signatures.append(commitment.content_signature())
	return signatures


static func _message_signatures(messages: Array[MessageState]) -> PackedStringArray:
	var signatures := PackedStringArray()
	for message: MessageState in messages:
		signatures.append(message.signature())
	return signatures


static func _record_id(record: Variant) -> StringName:
	if record is ContractHistoryEntry:
		return record.contract_instance_id
	if record is WorldEventState:
		return record.instance_id
	if record is ContractOfferState:
		return record.instance_id
	if record is ContractPlanState:
		return record.contract_instance_id
	if record is FactionActionCommitmentState:
		return record.instance_id
	if record is MessageState:
		return record.instance_id
	return &""


static func _record_signature(record: Variant) -> String:
	if (
		record is ContractHistoryEntry
		or record is WorldEventState
		or record is ContractOfferState
		or record is ContractPlanState
		or record is FactionActionCommitmentState
		or record is MessageState
	):
		return record.content_signature()
	return ""


static func _find_offer(
	state: CampaignState,
	instance_id: StringName
) -> ContractOfferState:
	for offer: ContractOfferState in state.pending_contracts:
		if offer != null and offer.instance_id == instance_id:
			return offer
	return null


static func _find_commitment(
	state: CampaignState,
	instance_id: StringName
) -> FactionActionCommitmentState:
	for commitment: FactionActionCommitmentState in state.faction_action_commitments:
		if commitment != null and commitment.instance_id == instance_id:
			return commitment
	return null


static func _find_message(
	state: CampaignState,
	instance_id: StringName
) -> MessageState:
	for message: MessageState in state.message_history:
		if message != null and message.instance_id == instance_id:
			return message
	return null


static func _sorted_reason_codes(group: Array[StateOperation]) -> Array[StringName]:
	var ordered: Array[StateOperation] = []
	for operation: StateOperation in group:
		if operation.operation == StateOperation.OP_ADD_INT and int(operation.value) == 0:
			continue
		ordered.append(operation)
	ordered.sort_custom(_reason_less)
	var reasons: Array[StringName] = []
	for operation: StateOperation in ordered:
		if not reasons.has(operation.reason_code):
			reasons.append(operation.reason_code)
	return reasons


static func _operation_less(left: StateOperation, right: StateOperation) -> bool:
	var left_key: String = "%s|%s|%s|%s|%s|%010d|%s" % [
		_target_sort_key(left.target_kind),
		left.target_id,
		left.field_id,
		left.operation,
		_value_sort_key(left.value),
		left.source_order,
		left.reason_code,
	]
	var right_key: String = "%s|%s|%s|%s|%s|%010d|%s" % [
		_target_sort_key(right.target_kind),
		right.target_id,
		right.field_id,
		right.operation,
		_value_sort_key(right.value),
		right.source_order,
		right.reason_code,
	]
	return left_key < right_key


static func _target_sort_key(target_kind: StringName) -> String:
	# Offer fields must reach their complete terminal values before a later
	# pending-contract removal validates and archives that transient record.
	if target_kind == TARGET_CONTRACT_OFFER:
		return "0_contract_offer"
	if target_kind == TARGET_FACTION_ACTION_COMMITMENT:
		return "0_faction_action_commitment"
	return "1_%s" % target_kind


static func _reason_less(left: StateOperation, right: StateOperation) -> bool:
	if left.source_order != right.source_order:
		return left.source_order < right.source_order
	return String(left.reason_code) < String(right.reason_code)


static func _state_change_less(left: StateChange, right: StateChange) -> bool:
	if left.field_path != right.field_path:
		return left.field_path < right.field_path
	return String(left.target_id) < String(right.target_id)


static func _message_less(left: MessageState, right: MessageState) -> bool:
	if left.week_index != right.week_index:
		return left.week_index < right.week_index
	if left.sort_order != right.sort_order:
		return left.sort_order < right.sort_order
	return String(left.instance_id) < String(right.instance_id)


static func _stable_id_less(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)


static func _field_key(operation: StateOperation) -> String:
	return "%s|%s|%s" % [
		operation.target_kind,
		operation.target_id,
		operation.field_id,
	]


static func _field_path(operation: StateOperation) -> String:
	return "%s.%s.%s" % [
		operation.target_kind,
		operation.target_id,
		operation.field_id,
	]


static func _value_sort_key(value: Variant) -> String:
	if (
		value is ContractHistoryEntry
		or value is WorldEventState
		or value is ContractOfferState
		or value is ContractPlanState
		or value is FactionActionCommitmentState
		or value is MessageState
	):
		return _record_signature(value)
	return var_to_str(value)
