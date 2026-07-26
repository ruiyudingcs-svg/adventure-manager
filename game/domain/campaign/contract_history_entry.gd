class_name ContractHistoryEntry
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const StateChange = preload("res://game/core/result/state_change.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

const ORIGIN_PROBLEM: StringName = &"problem"
const ORIGIN_FOLLOWUP: StringName = &"followup"
const ORIGIN_AGENDA: StringName = &"agenda"
const ALLOWED_ORIGIN_TYPES: Array[StringName] = [
	ORIGIN_PROBLEM,
	ORIGIN_FOLLOWUP,
	ORIGIN_AGENDA,
]

const STATUS_RESOLVED: StringName = &"resolved"
const STATUS_DECLINED: StringName = &"declined"
const STATUS_EXPIRED: StringName = &"expired"
const STATUS_NPC_COMPLETED: StringName = &"npc_completed"
const STATUS_ESCALATED: StringName = &"escalated"
const ALLOWED_TERMINAL_STATUSES: Array[StringName] = [
	STATUS_RESOLVED,
	STATUS_DECLINED,
	STATUS_EXPIRED,
	STATUS_NPC_COMPLETED,
	STATUS_ESCALATED,
]

var week_index: int
var offered_week: int
var contract_instance_id: StringName
var contract_definition_id: StringName
var sponsor_faction_id: StringName
var origin_type: StringName
var related_problem_id: StringName
var target_lock_key: StringName
var terminal_status: StringName
var terminal_reason_code: StringName
var member_ids: Array[StringName]
var supply_ids: Array[StringName]
var approach: StringName
var result_tier: StringName
var reward_received: int
var trace_summary: Dictionary
var state_changes: Array[StateChange]
var world_event_ids: Array[StringName]
var generation_reason_entries: Array[ReasonEntry]


## Builds the Task007 resolved-history record without introducing Offer state.
static func create_resolved(
	p_week_index: int,
	p_contract_instance_id: StringName,
	p_contract_definition_id: StringName,
	p_sponsor_faction_id: StringName,
	p_related_problem_id: StringName,
	p_member_ids: Array[StringName],
	p_supply_ids: Array[StringName],
	p_approach: StringName,
	p_result_tier: StringName,
	p_reward_received: int,
	p_outcome_tags: Array[StringName],
	p_world_event_ids: Array[StringName] = []
) -> ContractHistoryEntry:
	var summary: Dictionary = {"outcome_tags": p_outcome_tags.duplicate()}
	var entry := ContractHistoryEntry.new(
		p_week_index,
		p_week_index,
		p_contract_instance_id,
		p_contract_definition_id,
		p_sponsor_faction_id,
		ORIGIN_PROBLEM if not p_related_problem_id.is_empty() else ORIGIN_AGENDA,
		p_related_problem_id,
		&"",
		STATUS_RESOLVED,
		&"contract_resolved",
		p_member_ids,
		p_supply_ids,
		p_approach,
		p_result_tier,
		p_reward_received,
		summary,
		[],
		p_world_event_ids,
		[]
	)
	if not entry.validate().is_empty():
		return null
	return entry


func _init(
	p_week_index: int,
	p_offered_week: int,
	p_contract_instance_id: StringName,
	p_contract_definition_id: StringName,
	p_sponsor_faction_id: StringName,
	p_origin_type: StringName,
	p_related_problem_id: StringName,
	p_target_lock_key: StringName,
	p_terminal_status: StringName,
	p_terminal_reason_code: StringName,
	p_member_ids: Array[StringName],
	p_supply_ids: Array[StringName],
	p_approach: StringName,
	p_result_tier: StringName,
	p_reward_received: int,
	p_trace_summary: Dictionary,
	p_state_changes: Array[StateChange],
	p_world_event_ids: Array[StringName],
	p_generation_reason_entries: Array[ReasonEntry]
) -> void:
	week_index = p_week_index
	offered_week = p_offered_week
	contract_instance_id = p_contract_instance_id
	contract_definition_id = p_contract_definition_id
	sponsor_faction_id = p_sponsor_faction_id
	origin_type = p_origin_type
	related_problem_id = p_related_problem_id
	target_lock_key = p_target_lock_key
	terminal_status = p_terminal_status
	terminal_reason_code = p_terminal_reason_code
	member_ids.append_array(p_member_ids)
	supply_ids.append_array(p_supply_ids)
	approach = p_approach
	result_tier = p_result_tier
	reward_received = p_reward_received
	trace_summary = p_trace_summary.duplicate(true)
	for change: StateChange in p_state_changes:
		state_changes.append(
			change.duplicate_value() if change != null else null
		)
	world_event_ids.append_array(p_world_event_ids)
	for reason: ReasonEntry in p_generation_reason_entries:
		generation_reason_entries.append(
			reason.duplicate_value() if reason != null else null
		)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if week_index < 0 or offered_week < 0:
		errors.append("ContractHistoryEntry week values must be non-negative.")
	elif offered_week > week_index:
		errors.append("ContractHistoryEntry.offered_week cannot exceed week_index.")
	for pair: Array in [
		[contract_instance_id, "contract_instance_id"],
		[contract_definition_id, "contract_definition_id"],
		[sponsor_faction_id, "sponsor_faction_id"],
		[terminal_reason_code, "terminal_reason_code"],
	]:
		if not StableId.is_valid(pair[0]):
			errors.append(StableId.validation_error(
				pair[0],
				"ContractHistoryEntry.%s" % pair[1]
			))
	if not ALLOWED_ORIGIN_TYPES.has(origin_type):
		errors.append(
			"ContractHistoryEntry.origin_type is not allowed: %s." % origin_type
		)
	if not ALLOWED_TERMINAL_STATUSES.has(terminal_status):
		errors.append(
			"ContractHistoryEntry.terminal_status is not allowed: %s."
			% terminal_status
		)
	if origin_type == ORIGIN_PROBLEM and not StableId.is_valid(related_problem_id):
		errors.append(StableId.validation_error(
			related_problem_id,
			"ContractHistoryEntry.related_problem_id"
		))
	elif (
		origin_type != ORIGIN_PROBLEM
		and not related_problem_id.is_empty()
	):
		errors.append(
			"Followup and agenda history cannot have a related_problem_id."
		)
	if not target_lock_key.is_empty() and not _is_valid_target_lock(target_lock_key):
		errors.append(
			"ContractHistoryEntry.target_lock_key must contain one or two stable ID segments."
		)
	if reward_received < 0:
		errors.append("ContractHistoryEntry.reward_received must be non-negative.")
	if terminal_status == STATUS_RESOLVED:
		for pair: Array in [
			[approach, "approach"],
			[result_tier, "result_tier"],
		]:
			if not StableId.is_valid(pair[0]):
				errors.append(StableId.validation_error(
					pair[0],
					"ContractHistoryEntry.%s" % pair[1]
				))
	else:
		if not member_ids.is_empty() or not supply_ids.is_empty():
			errors.append(
				"Unaccepted ContractHistoryEntry cannot contain members or supplies."
			)
		if not approach.is_empty() or not result_tier.is_empty():
			errors.append(
				"Unaccepted ContractHistoryEntry approach and result_tier must be empty."
			)
		if reward_received != 0:
			errors.append(
				"Unaccepted ContractHistoryEntry.reward_received must be zero."
			)
	_append_unique_ids(errors, member_ids, "member_ids")
	_append_unique_ids(errors, supply_ids, "supply_ids")
	_append_unique_ids(errors, world_event_ids, "world_event_ids")
	for change: StateChange in state_changes:
		if change == null:
			errors.append("ContractHistoryEntry.state_changes cannot contain null.")
	for reason: ReasonEntry in generation_reason_entries:
		if reason == null:
			errors.append(
				"ContractHistoryEntry.generation_reason_entries cannot contain null."
			)
	return errors


func duplicate_state() -> ContractHistoryEntry:
	return ContractHistoryEntry.new(
		week_index,
		offered_week,
		contract_instance_id,
		contract_definition_id,
		sponsor_faction_id,
		origin_type,
		related_problem_id,
		target_lock_key,
		terminal_status,
		terminal_reason_code,
		member_ids,
		supply_ids,
		approach,
		result_tier,
		reward_received,
		trace_summary,
		state_changes,
		world_event_ids,
		generation_reason_entries
	)


func content_signature() -> String:
	var change_signatures := PackedStringArray()
	for change: StateChange in state_changes:
		change_signatures.append(_state_change_signature(change))
	var reason_signatures := PackedStringArray()
	for reason: ReasonEntry in generation_reason_entries:
		reason_signatures.append(_reason_signature(reason))
	return _stable_variant_signature([
		week_index,
		offered_week,
		contract_instance_id,
		contract_definition_id,
		sponsor_faction_id,
		origin_type,
		related_problem_id,
		target_lock_key,
		terminal_status,
		terminal_reason_code,
		member_ids,
		supply_ids,
		approach,
		result_tier,
		reward_received,
		trace_summary,
		change_signatures,
		world_event_ids,
		reason_signatures,
	])


static func _append_unique_ids(
	errors: PackedStringArray,
	values: Array[StringName],
	field_name: String
) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for value: StringName in values:
		if not StableId.is_valid(value):
			errors.append(StableId.validation_error(
				value,
				"ContractHistoryEntry.%s item" % field_name
			))
		if seen.has(value):
			errors.append("ContractHistoryEntry.%s contains duplicate %s." % [field_name, value])
		seen[value] = true


static func _is_valid_target_lock(value: StringName) -> bool:
	var parts: PackedStringArray = String(value).split(".", false)
	if parts.size() == 1:
		return StableId.is_valid(value)
	return parts.size() == 2 \
		and StableId.is_valid(StringName(parts[0])) \
		and StableId.is_valid(StringName(parts[1]))


static func _state_change_signature(change: StateChange) -> String:
	if change == null:
		return "<null>"
	return _stable_variant_signature([
		change.target_id,
		change.field_path,
		change.old_value,
		change.new_value,
		change.reason_codes,
	])


static func _reason_signature(reason: ReasonEntry) -> String:
	if reason == null:
		return "<null>"
	return _stable_variant_signature([
		reason.code,
		reason.category,
		reason.source_id,
		reason.target_id,
		reason.amount,
		reason.localization_key,
		reason.parameters,
		reason.phase,
		reason.visibility,
	])


static func _stable_variant_signature(value: Variant) -> String:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var entries := PackedStringArray()
		for key: Variant in dictionary:
			entries.append(
				"%s=%s" % [
					_stable_variant_signature(key),
					_stable_variant_signature(dictionary[key]),
				]
			)
		entries.sort()
		return "{%s}" % ",".join(entries)
	if value is Array:
		var values: Array = value
		var items := PackedStringArray()
		for item: Variant in values:
			items.append(_stable_variant_signature(item))
		return "[%s]" % ",".join(items)
	return "%s:%s" % [typeof(value), str(value)]
