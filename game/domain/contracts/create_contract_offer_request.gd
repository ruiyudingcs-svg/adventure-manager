class_name CreateContractOfferRequest
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const ProblemUrgencyResult = preload(
	"res://game/domain/situations/problem_urgency_result.gd"
)
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)

const ORIGIN_PROBLEM: StringName = &"problem"
const ORIGIN_FOLLOWUP: StringName = &"followup"
const ORIGIN_AGENDA: StringName = &"agenda"
const ORIGIN_TYPES: Array[StringName] = [
	ORIGIN_PROBLEM,
	ORIGIN_FOLLOWUP,
	ORIGIN_AGENDA,
]

var definition: ContractDefinition
var offered_week: int
var origin_type: StringName
var related_problem_id: StringName
var sponsor_relation: int
var campaign_seed: int
var situation: SituationState
var world_events: Array[WorldEventState]
var problem_urgency: ProblemUrgencyResult
var generation_reason_entries: Array[ReasonEntry]
var existing_offers: Array[ContractOfferState]


static func create(
	p_definition: ContractDefinition,
	p_offered_week: int,
	p_origin_type: StringName,
	p_related_problem_id: StringName,
	p_sponsor_relation: int,
	p_campaign_seed: int,
	p_situation: SituationState,
	p_world_events: Array[WorldEventState],
	p_problem_urgency: ProblemUrgencyResult,
	p_generation_reason_entries: Array[ReasonEntry],
	p_existing_offers: Array[ContractOfferState]
) -> CreateContractOfferRequest:
	var request := CreateContractOfferRequest.new(
		p_definition,
		p_offered_week,
		p_origin_type,
		p_related_problem_id,
		p_sponsor_relation,
		p_campaign_seed,
		p_situation,
		p_world_events,
		p_problem_urgency,
		p_generation_reason_entries,
		p_existing_offers
	)
	if not request.validate().is_empty():
		return null
	return request


func _init(
	p_definition: ContractDefinition,
	p_offered_week: int,
	p_origin_type: StringName,
	p_related_problem_id: StringName,
	p_sponsor_relation: int,
	p_campaign_seed: int,
	p_situation: SituationState,
	p_world_events: Array[WorldEventState],
	p_problem_urgency: ProblemUrgencyResult,
	p_generation_reason_entries: Array[ReasonEntry],
	p_existing_offers: Array[ContractOfferState]
) -> void:
	definition = p_definition.duplicate_value() if p_definition != null else null
	offered_week = p_offered_week
	origin_type = p_origin_type
	related_problem_id = p_related_problem_id
	sponsor_relation = p_sponsor_relation
	campaign_seed = p_campaign_seed
	situation = p_situation.duplicate_state() if p_situation != null else null
	for event: WorldEventState in p_world_events:
		world_events.append(event.duplicate_state() if event != null else null)
	problem_urgency = (
		p_problem_urgency.duplicate_value()
		if p_problem_urgency != null
		else null
	)
	for reason: ReasonEntry in p_generation_reason_entries:
		generation_reason_entries.append(
			reason.duplicate_value() if reason != null else null
		)
	for offer: ContractOfferState in p_existing_offers:
		existing_offers.append(offer.duplicate_state() if offer != null else null)


## Validates the detached planning snapshot without consulting DataCatalog.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("CreateContractOfferRequest.definition is required.")
	else:
		if not StableId.is_valid(definition.id):
			errors.append(StableId.validation_error(
				definition.id,
				"CreateContractOfferRequest.definition.id"
			))
		if not StableId.is_valid(definition.sponsor_faction_id):
			errors.append(StableId.validation_error(
				definition.sponsor_faction_id,
				"CreateContractOfferRequest.definition.sponsor_faction_id"
			))
		if not ContractOfferState.is_valid_target_lock(definition.target_lock_key):
			errors.append(
				"ContractDefinition.target_lock_key must contain exactly two "
				+ "lower snake_case ID segments separated by one period."
			)
		if definition.base_reward < 0:
			errors.append("ContractDefinition.base_reward must be non-negative.")
		if definition.offer_duration_weeks < 1:
			errors.append("ContractDefinition.offer_duration_weeks must be at least one.")
	if offered_week < 0:
		errors.append("CreateContractOfferRequest.offered_week must be non-negative.")
	if not ORIGIN_TYPES.has(origin_type):
		errors.append("CreateContractOfferRequest.origin_type is not allowed: %s." % origin_type)
	if sponsor_relation < -100 or sponsor_relation > 100:
		errors.append(
			"CreateContractOfferRequest.sponsor_relation must be between -100 and 100."
		)
	if situation == null:
		errors.append("CreateContractOfferRequest.situation is required.")
	else:
		errors.append_array(situation.validate())

	if origin_type == ORIGIN_PROBLEM:
		if not StableId.is_valid(related_problem_id):
			errors.append(StableId.validation_error(
				related_problem_id,
				"CreateContractOfferRequest.related_problem_id"
			))
		if problem_urgency == null:
			errors.append("Problem-origin offers require ProblemUrgencyResult.")
		else:
			if problem_urgency.problem_id != related_problem_id:
				errors.append(
					"ProblemUrgencyResult.problem_id must match related_problem_id."
				)
			if problem_urgency.evaluated_week != offered_week:
				errors.append(
					"ProblemUrgencyResult.evaluated_week must match offered_week."
				)
			if problem_urgency.score < 0 or problem_urgency.score > 100:
				errors.append("ProblemUrgencyResult.score must be between 0 and 100.")
			if not [
				ProblemUrgencyResult.BAND_LOW,
				ProblemUrgencyResult.BAND_GUARDED,
				ProblemUrgencyResult.BAND_HIGH,
				ProblemUrgencyResult.BAND_SEVERE,
				ProblemUrgencyResult.BAND_CRITICAL,
			].has(problem_urgency.band):
				errors.append("ProblemUrgencyResult.band is not allowed.")
		if (
			definition != null
			and definition.related_problem_id != related_problem_id
		):
			errors.append(
				"Problem-origin related_problem_id must match the ContractDefinition anchor."
			)
	elif origin_type == ORIGIN_FOLLOWUP or origin_type == ORIGIN_AGENDA:
		if not related_problem_id.is_empty():
			errors.append("Followup and agenda offers cannot carry a related problem.")
		if problem_urgency != null:
			errors.append("Followup and agenda offers cannot carry ProblemUrgencyResult.")

	var event_ids: Dictionary[StringName, bool] = {}
	for event: WorldEventState in world_events:
		if event == null:
			errors.append("CreateContractOfferRequest.world_events cannot contain null.")
			continue
		errors.append_array(event.validate())
		if event_ids.has(event.instance_id):
			errors.append("Duplicate world event ID: %s." % event.instance_id)
		event_ids[event.instance_id] = true

	for reason: ReasonEntry in generation_reason_entries:
		if reason == null:
			errors.append(
				"CreateContractOfferRequest.generation_reason_entries cannot contain null."
			)
		elif reason.code.is_empty():
			errors.append("Generation reasons require a stable reason code.")
		elif not StableId.is_valid(reason.code):
			errors.append(StableId.validation_error(
				reason.code,
				"CreateContractOfferRequest generation reason code"
			))

	var offer_ids: Dictionary[StringName, bool] = {}
	for offer: ContractOfferState in existing_offers:
		if offer == null:
			errors.append("CreateContractOfferRequest.existing_offers cannot contain null.")
			continue
		errors.append_array(offer.validate())
		if offer_ids.has(offer.instance_id):
			errors.append("Duplicate existing Offer ID: %s." % offer.instance_id)
		offer_ids[offer.instance_id] = true
	return errors


func duplicate_value() -> CreateContractOfferRequest:
	return CreateContractOfferRequest.new(
		definition,
		offered_week,
		origin_type,
		related_problem_id,
		sponsor_relation,
		campaign_seed,
		situation,
		world_events,
		problem_urgency,
		generation_reason_entries,
		existing_offers
	)


func content_signature() -> String:
	var event_parts := PackedStringArray()
	for event: WorldEventState in world_events:
		event_parts.append(event.content_signature() if event != null else "<null>")
	var reason_parts := PackedStringArray()
	for reason: ReasonEntry in generation_reason_entries:
		reason_parts.append(_reason_signature(reason))
	var offer_parts := PackedStringArray()
	for offer: ContractOfferState in existing_offers:
		offer_parts.append(offer.content_signature() if offer != null else "<null>")
	return "%s|%d|%s|%s|%d|%d|%s|%s|%s|%s|%s" % [
		_definition_signature(),
		offered_week,
		origin_type,
		related_problem_id,
		sponsor_relation,
		campaign_seed,
		_situation_signature(),
		event_parts,
		problem_urgency.signature() if problem_urgency != null else "",
		reason_parts,
		offer_parts,
	]


func _definition_signature() -> String:
	if definition == null:
		return "<null>"
	var rule_parts := PackedStringArray()
	for rule in definition.instantiation_rules:
		if rule == null:
			rule_parts.append("<null>")
			continue
		var condition_parts := PackedStringArray()
		for condition in rule.all_conditions:
			condition_parts.append(
				"<null>" if condition == null else "%s:%s:%d:%s" % [
					condition.type,
					condition.target_id,
					condition.int_value,
					condition.tag_value,
				]
			)
		var effect_parts := PackedStringArray()
		for effect in rule.effects:
			effect_parts.append(
				"<null>" if effect == null else "%s:%s:%d" % [
					effect.type,
					effect.target_id,
					effect.amount,
				]
			)
		rule_parts.append("%s:%s:%s:%s" % [
			rule.id,
			condition_parts,
			effect_parts,
			rule.reason_code,
		])
	return "%s:%s:%s:%s:%s:%s:%s:%d:%d:%d:%d:%s:%s:%s" % [
		definition.id,
		definition.sponsor_faction_id,
		definition.related_problem_id,
		definition.target_lock_key,
		definition.repeat_policy,
		definition.clause_ids,
		definition.allowed_supply_tags,
		definition.base_reward,
		definition.base_fatigue,
		definition.risk_level,
		definition.offer_duration_weeks,
		definition.expected_method_tags,
		rule_parts,
		definition.unhandled_policy,
	]


func _situation_signature() -> String:
	if situation == null:
		return "<null>"
	var clock_ids: Array[StringName] = []
	clock_ids.assign(situation.clock_values.keys())
	clock_ids.sort()
	var clock_parts := PackedStringArray()
	for clock_id: StringName in clock_ids:
		clock_parts.append("%s:%d" % [clock_id, situation.clock_values[clock_id]])
	var problem_ids: Array[StringName] = []
	problem_ids.assign(situation.problems.keys())
	problem_ids.sort()
	var problem_parts := PackedStringArray()
	for problem_id: StringName in problem_ids:
		var problem = situation.problems[problem_id]
		problem_parts.append(
			"%s:%s:%d:%d:%d:%s:%s" % [
				problem_id,
				problem.status,
				problem.opened_week,
				problem.response_deadline_week,
				problem.closed_week,
				problem.source_event_id,
				problem.resolution_reason_code,
			]
		)
	return "%s:%s:%s:%s:%s:%s:%s" % [
		situation.definition_id,
		situation.phase_id,
		clock_parts,
		situation.triggered_rule_ids,
		situation.unlocked_contract_ids,
		problem_parts,
		situation.ending_id,
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
		_variant_signature(reason.parameters),
		reason.phase,
		reason.visibility,
	]


static func _variant_signature(value: Variant) -> String:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var keys: Array = dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			return str(left) < str(right)
		)
		var parts := PackedStringArray()
		for key: Variant in keys:
			parts.append("%s=%s" % [key, _variant_signature(dictionary[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts := PackedStringArray()
		for item: Variant in value:
			parts.append(_variant_signature(item))
		return "[%s]" % ",".join(parts)
	return str(value)
