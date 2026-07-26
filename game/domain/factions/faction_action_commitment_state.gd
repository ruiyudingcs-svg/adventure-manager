## Persisted reservation for one delayed faction action.
class_name FactionActionCommitmentState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

const STATUS_COMMITTED: StringName = &"committed"
const STATUS_RESOLVED: StringName = &"resolved"
const ALLOWED_STATUSES: Array[StringName] = [STATUS_COMMITTED, STATUS_RESOLVED]

var instance_id: StringName
var faction_id: StringName
var action_definition_id: StringName
var target_problem_id: StringName
var target_lock_key: StringName
var committed_week: int
var resolves_at_week: int
var reserved_influence: int
var commitment_reason_entries: Array[ReasonEntry]
var status: StringName
var resolved_week: int
var world_event_ids: Array[StringName]


static func create(
	p_instance_id: StringName,
	p_faction_id: StringName,
	p_action_definition_id: StringName,
	p_target_problem_id: StringName,
	p_target_lock_key: StringName,
	p_committed_week: int,
	p_reserved_influence: int,
	p_commitment_reason_entries: Array[ReasonEntry]
) -> FactionActionCommitmentState:
	var value := FactionActionCommitmentState.new(
		p_instance_id,
		p_faction_id,
		p_action_definition_id,
		p_target_problem_id,
		p_target_lock_key,
		p_committed_week,
		p_committed_week + 1,
		p_reserved_influence,
		p_commitment_reason_entries,
		STATUS_COMMITTED,
		-1,
		[]
	)
	return value if value.validate().is_empty() else null


func _init(
	p_instance_id: StringName,
	p_faction_id: StringName,
	p_action_definition_id: StringName,
	p_target_problem_id: StringName,
	p_target_lock_key: StringName,
	p_committed_week: int,
	p_resolves_at_week: int,
	p_reserved_influence: int,
	p_commitment_reason_entries: Array[ReasonEntry],
	p_status: StringName,
	p_resolved_week: int,
	p_world_event_ids: Array[StringName]
) -> void:
	instance_id = p_instance_id
	faction_id = p_faction_id
	action_definition_id = p_action_definition_id
	target_problem_id = p_target_problem_id
	target_lock_key = p_target_lock_key
	committed_week = p_committed_week
	resolves_at_week = p_resolves_at_week
	reserved_influence = p_reserved_influence
	for reason: ReasonEntry in p_commitment_reason_entries:
		commitment_reason_entries.append(
			reason.duplicate_value() if reason != null else null
		)
	status = p_status
	resolved_week = p_resolved_week
	world_event_ids.append_array(p_world_event_ids)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for pair: Array in [
		[instance_id, "instance_id"],
		[faction_id, "faction_id"],
		[action_definition_id, "action_definition_id"],
		[target_problem_id, "target_problem_id"],
	]:
		if not StableId.is_valid(pair[0]):
			errors.append(StableId.validation_error(
				pair[0],
				"FactionActionCommitmentState.%s" % pair[1]
			))
	if not _is_valid_target_lock(target_lock_key):
		errors.append(
			"FactionActionCommitmentState.target_lock_key must contain one or two stable ID segments."
		)
	if committed_week < 0 or resolves_at_week != committed_week + 1:
		errors.append(
			"FactionActionCommitmentState resolves_at_week must equal committed_week + 1."
		)
	if reserved_influence < 0 or reserved_influence > 100:
		errors.append(
			"FactionActionCommitmentState.reserved_influence must be between 0 and 100."
		)
	if not ALLOWED_STATUSES.has(status):
		errors.append("FactionActionCommitmentState.status is not allowed.")
	if status == STATUS_COMMITTED:
		if resolved_week != -1 or not world_event_ids.is_empty():
			errors.append("Committed faction actions cannot have resolution data.")
	elif resolved_week != resolves_at_week:
		errors.append(
			"Resolved faction actions must resolve at their locked resolves_at_week."
		)
	var seen_events: Dictionary[StringName, bool] = {}
	for event_id: StringName in world_event_ids:
		if not StableId.is_valid(event_id):
			errors.append(StableId.validation_error(
				event_id,
				"FactionActionCommitmentState.world_event_ids item"
			))
		if seen_events.has(event_id):
			errors.append("Faction action commitment contains duplicate event IDs.")
		seen_events[event_id] = true
	for reason: ReasonEntry in commitment_reason_entries:
		if reason == null:
			errors.append("Commitment reasons cannot contain null.")
	return errors


func duplicate_state() -> FactionActionCommitmentState:
	return FactionActionCommitmentState.new(
		instance_id,
		faction_id,
		action_definition_id,
		target_problem_id,
		target_lock_key,
		committed_week,
		resolves_at_week,
		reserved_influence,
		commitment_reason_entries,
		status,
		resolved_week,
		world_event_ids
	)


func duplicate_value() -> FactionActionCommitmentState:
	return duplicate_state()


func content_signature() -> String:
	var reason_parts := PackedStringArray()
	for reason: ReasonEntry in commitment_reason_entries:
		reason_parts.append(_reason_signature(reason))
	return "%s|%s|%s|%s|%s|%d|%d|%d|%s|%d|%s|%s" % [
		instance_id,
		faction_id,
		action_definition_id,
		target_problem_id,
		target_lock_key,
		committed_week,
		resolves_at_week,
		reserved_influence,
		status,
		resolved_week,
		world_event_ids,
		reason_parts,
	]


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
			entries.append("%s=%s" % [
				_stable_variant_signature(key),
				_stable_variant_signature(dictionary[key]),
			])
		entries.sort()
		return "{%s}" % ",".join(entries)
	if value is Array:
		var values: Array = value
		var items := PackedStringArray()
		for item: Variant in values:
			items.append(_stable_variant_signature(item))
		return "[%s]" % ",".join(items)
	return "%s:%s" % [typeof(value), str(value)]


static func _is_valid_target_lock(value: StringName) -> bool:
	var parts: PackedStringArray = String(value).split(".", false)
	if parts.size() == 1:
		return StableId.is_valid(value)
	return parts.size() == 2 \
		and StableId.is_valid(StringName(parts[0])) \
		and StableId.is_valid(StringName(parts[1]))
