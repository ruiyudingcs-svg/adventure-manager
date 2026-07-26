class_name ContractOfferState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const ContractInstantiationSnapshot = preload(
	"res://game/domain/contracts/contract_instantiation_snapshot.gd"
)

const STATUS_PENDING: StringName = &"pending"
const STATUS_ACCEPTED: StringName = &"accepted"
const STATUS_RESOLVED: StringName = &"resolved"
const STATUS_DECLINED: StringName = &"declined"
const STATUS_EXPIRED: StringName = &"expired"
const STATUS_NPC_COMPLETED: StringName = &"npc_completed"
const STATUS_ESCALATED: StringName = &"escalated"
const ALLOWED_STATUSES: Array[StringName] = [
	STATUS_PENDING,
	STATUS_ACCEPTED,
	STATUS_RESOLVED,
	STATUS_DECLINED,
	STATUS_EXPIRED,
	STATUS_NPC_COMPLETED,
	STATUS_ESCALATED,
]

const ORIGIN_PROBLEM: StringName = &"problem"
const ORIGIN_FOLLOWUP: StringName = &"followup"
const ORIGIN_AGENDA: StringName = &"agenda"
const ALLOWED_ORIGIN_TYPES: Array[StringName] = [
	ORIGIN_PROBLEM,
	ORIGIN_FOLLOWUP,
	ORIGIN_AGENDA,
]

const RELATION_TIER_STANDARD: StringName = &"standard"
const RELATION_TIER_FAVORABLE: StringName = &"favorable"
const RELATION_TIER_TRUSTED: StringName = &"trusted"
const ALLOWED_RELATION_TIERS: Array[StringName] = [
	RELATION_TIER_STANDARD,
	RELATION_TIER_FAVORABLE,
	RELATION_TIER_TRUSTED,
]

const MIN_RELATION: int = -100
const MAX_RELATION: int = 100

var instance_id: StringName
var definition_id: StringName
var sponsor_faction_id: StringName
var origin_type: StringName
var related_problem_id: StringName
var target_lock_key: StringName
var offered_week: int
var expires_week: int
var offered_reward: int
var applied_relation_tier: StringName
var sponsor_relation_snapshot: int
var problem_urgency_at_offer: int
var generation_reason_entries: Array[ReasonEntry]
var locked_seed: int
var instantiation_snapshot: ContractInstantiationSnapshot
var status: StringName
var resolved_week: int
var terminal_reason_code: StringName


static func create(
	p_instance_id: StringName,
	p_definition_id: StringName,
	p_sponsor_faction_id: StringName,
	p_origin_type: StringName,
	p_related_problem_id: StringName,
	p_target_lock_key: StringName,
	p_offered_week: int,
	p_expires_week: int,
	p_offered_reward: int,
	p_applied_relation_tier: StringName,
	p_sponsor_relation_snapshot: int,
	p_problem_urgency_at_offer: int,
	p_generation_reason_entries: Array[ReasonEntry],
	p_locked_seed: int,
	p_instantiation_snapshot: ContractInstantiationSnapshot,
	p_status: StringName = STATUS_PENDING,
	p_resolved_week: int = -1,
	p_terminal_reason_code: StringName = &""
) -> ContractOfferState:
	if not validate_values(
		p_instance_id,
		p_definition_id,
		p_sponsor_faction_id,
		p_origin_type,
		p_related_problem_id,
		p_target_lock_key,
		p_offered_week,
		p_expires_week,
		p_offered_reward,
		p_applied_relation_tier,
		p_sponsor_relation_snapshot,
		p_problem_urgency_at_offer,
		p_generation_reason_entries,
		p_locked_seed,
		p_instantiation_snapshot,
		p_status,
		p_resolved_week,
		p_terminal_reason_code
	).is_empty():
		return null
	return ContractOfferState.new(
		p_instance_id,
		p_definition_id,
		p_sponsor_faction_id,
		p_origin_type,
		p_related_problem_id,
		p_target_lock_key,
		p_offered_week,
		p_expires_week,
		p_offered_reward,
		p_applied_relation_tier,
		p_sponsor_relation_snapshot,
		p_problem_urgency_at_offer,
		p_generation_reason_entries,
		p_locked_seed,
		p_instantiation_snapshot,
		p_status,
		p_resolved_week,
		p_terminal_reason_code
	)


func _init(
	p_instance_id: StringName,
	p_definition_id: StringName,
	p_sponsor_faction_id: StringName,
	p_origin_type: StringName,
	p_related_problem_id: StringName,
	p_target_lock_key: StringName,
	p_offered_week: int,
	p_expires_week: int,
	p_offered_reward: int,
	p_applied_relation_tier: StringName,
	p_sponsor_relation_snapshot: int,
	p_problem_urgency_at_offer: int,
	p_generation_reason_entries: Array[ReasonEntry],
	p_locked_seed: int,
	p_instantiation_snapshot: ContractInstantiationSnapshot,
	p_status: StringName,
	p_resolved_week: int,
	p_terminal_reason_code: StringName
) -> void:
	instance_id = p_instance_id
	definition_id = p_definition_id
	sponsor_faction_id = p_sponsor_faction_id
	origin_type = p_origin_type
	related_problem_id = p_related_problem_id
	target_lock_key = p_target_lock_key
	offered_week = p_offered_week
	expires_week = p_expires_week
	offered_reward = p_offered_reward
	applied_relation_tier = p_applied_relation_tier
	sponsor_relation_snapshot = p_sponsor_relation_snapshot
	problem_urgency_at_offer = p_problem_urgency_at_offer
	for reason: ReasonEntry in p_generation_reason_entries:
		generation_reason_entries.append(
			reason.duplicate_value() if reason != null else null
		)
	locked_seed = p_locked_seed
	instantiation_snapshot = (
		p_instantiation_snapshot.duplicate_value()
		if p_instantiation_snapshot != null
		else null
	)
	status = p_status
	resolved_week = p_resolved_week
	terminal_reason_code = p_terminal_reason_code


static func validate_values(
	p_instance_id: StringName,
	p_definition_id: StringName,
	p_sponsor_faction_id: StringName,
	p_origin_type: StringName,
	p_related_problem_id: StringName,
	p_target_lock_key: StringName,
	p_offered_week: int,
	p_expires_week: int,
	p_offered_reward: int,
	p_applied_relation_tier: StringName,
	p_sponsor_relation_snapshot: int,
	p_problem_urgency_at_offer: int,
	p_generation_reason_entries: Array[ReasonEntry],
	p_locked_seed: int,
	p_instantiation_snapshot: ContractInstantiationSnapshot,
	p_status: StringName,
	p_resolved_week: int,
	p_terminal_reason_code: StringName
) -> PackedStringArray:
	var errors := PackedStringArray()
	for pair: Array in [
		[p_instance_id, "ContractOfferState.instance_id"],
		[p_definition_id, "ContractOfferState.definition_id"],
		[p_sponsor_faction_id, "ContractOfferState.sponsor_faction_id"],
	]:
		if not StableId.is_valid(pair[0]):
			errors.append(StableId.validation_error(pair[0], pair[1]))

	if not ALLOWED_ORIGIN_TYPES.has(p_origin_type):
		errors.append("ContractOfferState.origin_type is not allowed: %s." % p_origin_type)
	if p_origin_type == ORIGIN_PROBLEM:
		if not StableId.is_valid(p_related_problem_id):
			errors.append(StableId.validation_error(
				p_related_problem_id,
				"ContractOfferState.related_problem_id"
			))
	elif not p_related_problem_id.is_empty():
		errors.append(
			"Followup and agenda offers cannot have a related_problem_id."
		)

	if not is_valid_target_lock(p_target_lock_key):
		errors.append(
			"ContractOfferState.target_lock_key must contain exactly two "
			+ "lower snake_case ID segments separated by one period."
		)
	if p_offered_week < 0:
		errors.append("ContractOfferState.offered_week must be non-negative.")
	if p_expires_week < p_offered_week:
		errors.append(
			"ContractOfferState.expires_week cannot precede offered_week."
		)
	if p_offered_reward < 0:
		errors.append("ContractOfferState.offered_reward must be non-negative.")

	if not ALLOWED_RELATION_TIERS.has(p_applied_relation_tier):
		errors.append(
			"ContractOfferState.applied_relation_tier is not allowed: %s."
			% p_applied_relation_tier
		)
	if (
		p_sponsor_relation_snapshot < MIN_RELATION
		or p_sponsor_relation_snapshot > MAX_RELATION
	):
		errors.append(
			"ContractOfferState.sponsor_relation_snapshot must be between %d and %d."
			% [MIN_RELATION, MAX_RELATION]
		)
	elif p_applied_relation_tier != relation_tier_for(p_sponsor_relation_snapshot):
		errors.append(
			"ContractOfferState.applied_relation_tier does not match "
			+ "sponsor_relation_snapshot."
		)

	if p_problem_urgency_at_offer < 0 or p_problem_urgency_at_offer > 100:
		errors.append(
			"ContractOfferState.problem_urgency_at_offer must be between 0 and 100."
		)
	if (
		p_origin_type != ORIGIN_PROBLEM
		and p_problem_urgency_at_offer != 0
	):
		errors.append(
			"Followup and agenda offers must have zero problem urgency."
		)

	for reason: ReasonEntry in p_generation_reason_entries:
		if reason == null:
			errors.append(
				"ContractOfferState.generation_reason_entries contains null."
			)
	if p_locked_seed < 0:
		errors.append("ContractOfferState.locked_seed must be non-negative.")
	if p_instantiation_snapshot == null:
		errors.append(
			"ContractOfferState.instantiation_snapshot must not be null."
		)
	else:
		var snapshot_issues: PackedStringArray = p_instantiation_snapshot.validate()
		for issue: String in snapshot_issues:
			errors.append(
				"ContractOfferState.instantiation_snapshot: %s" % issue
			)
		if p_instantiation_snapshot.evaluated_week != p_offered_week:
			errors.append(
				"ContractOfferState snapshot week must equal offered_week."
			)

	if not ALLOWED_STATUSES.has(p_status):
		errors.append("ContractOfferState.status is not allowed: %s." % p_status)
	var is_terminal: bool = (
		p_status == STATUS_RESOLVED
		or p_status == STATUS_DECLINED
		or p_status == STATUS_EXPIRED
		or p_status == STATUS_NPC_COMPLETED
		or p_status == STATUS_ESCALATED
	)
	if is_terminal:
		if p_resolved_week < p_offered_week:
			errors.append(
				"Terminal ContractOfferState requires a resolved_week "
				+ "not earlier than offered_week."
			)
		if not StableId.is_valid(p_terminal_reason_code):
			errors.append(StableId.validation_error(
				p_terminal_reason_code,
				"ContractOfferState.terminal_reason_code"
			))
	else:
		if p_resolved_week != -1:
			errors.append(
				"Non-terminal ContractOfferState.resolved_week must be -1."
			)
		if not p_terminal_reason_code.is_empty():
			errors.append(
				"Non-terminal ContractOfferState.terminal_reason_code must be empty."
			)
	return errors


func validate() -> PackedStringArray:
	return validate_values(
		instance_id,
		definition_id,
		sponsor_faction_id,
		origin_type,
		related_problem_id,
		target_lock_key,
		offered_week,
		expires_week,
		offered_reward,
		applied_relation_tier,
		sponsor_relation_snapshot,
		problem_urgency_at_offer,
		generation_reason_entries,
		locked_seed,
		instantiation_snapshot,
		status,
		resolved_week,
		terminal_reason_code
	)


func duplicate_state() -> ContractOfferState:
	return ContractOfferState.new(
		instance_id,
		definition_id,
		sponsor_faction_id,
		origin_type,
		related_problem_id,
		target_lock_key,
		offered_week,
		expires_week,
		offered_reward,
		applied_relation_tier,
		sponsor_relation_snapshot,
		problem_urgency_at_offer,
		generation_reason_entries,
		locked_seed,
		instantiation_snapshot,
		status,
		resolved_week,
		terminal_reason_code
	)


func remaining_turns(current_week: int) -> int:
	return expires_week - current_week + 1


func can_transition_to(next_status: StringName) -> bool:
	return is_valid_transition(status, next_status)


static func is_valid_transition(
	current_status: StringName,
	next_status: StringName
) -> bool:
	if current_status == STATUS_PENDING:
		return (
			next_status == STATUS_ACCEPTED
			or next_status == STATUS_DECLINED
			or next_status == STATUS_EXPIRED
			or next_status == STATUS_NPC_COMPLETED
			or next_status == STATUS_ESCALATED
		)
	if current_status == STATUS_ACCEPTED:
		return next_status == STATUS_RESOLVED
	return false


static func relation_tier_for(relation: int) -> StringName:
	if relation >= 60:
		return RELATION_TIER_TRUSTED
	if relation >= 25:
		return RELATION_TIER_FAVORABLE
	return RELATION_TIER_STANDARD


static func is_valid_target_lock(value: StringName) -> bool:
	var segments: PackedStringArray = String(value).split(".", true)
	if segments.size() == 1:
		return StableId.is_valid(value)
	return (
		segments.size() == 2
		and StableId.is_valid(StringName(segments[0]))
		and StableId.is_valid(StringName(segments[1]))
	)


func content_signature() -> String:
	var reason_parts := PackedStringArray()
	for reason: ReasonEntry in generation_reason_entries:
		reason_parts.append(_reason_signature(reason))
	return "%s|%s|%s|%s|%s|%s|%d|%d|%d|%s|%d|%d|%s|%d|%s|%s|%d|%s" % [
		instance_id,
		definition_id,
		sponsor_faction_id,
		origin_type,
		related_problem_id,
		target_lock_key,
		offered_week,
		expires_week,
		offered_reward,
		applied_relation_tier,
		sponsor_relation_snapshot,
		problem_urgency_at_offer,
		reason_parts,
		locked_seed,
		(
			"<null>"
			if instantiation_snapshot == null
			else instantiation_snapshot.content_signature()
		),
		status,
		resolved_week,
		terminal_reason_code,
	]


static func _reason_signature(reason: ReasonEntry) -> String:
	if reason == null:
		return "<null>"
	return "%s:%s:%s:%s:%s:%s:%s:%s:%s" % [
		reason.code,
		reason.category,
		reason.source_id,
		reason.target_id,
		reason.amount,
		reason.localization_key,
		_stable_variant_signature(reason.parameters),
		reason.phase,
		reason.visibility,
	]


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
