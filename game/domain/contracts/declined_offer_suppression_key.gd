class_name DeclinedOfferSuppressionKey
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)

var definition_id: StringName
var origin_type: StringName
var related_problem_id: StringName
var target_lock_key: StringName


static func create(
	p_definition_id: StringName,
	p_origin_type: StringName,
	p_related_problem_id: StringName,
	p_target_lock_key: StringName
) -> DeclinedOfferSuppressionKey:
	var key := DeclinedOfferSuppressionKey.new(
		p_definition_id,
		p_origin_type,
		p_related_problem_id,
		p_target_lock_key
	)
	return key if key.validate().is_empty() else null


func _init(
	p_definition_id: StringName,
	p_origin_type: StringName,
	p_related_problem_id: StringName,
	p_target_lock_key: StringName
) -> void:
	definition_id = p_definition_id
	origin_type = p_origin_type
	related_problem_id = p_related_problem_id
	target_lock_key = p_target_lock_key


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(definition_id):
		errors.append(StableId.validation_error(
			definition_id,
			"DeclinedOfferSuppressionKey.definition_id"
		))
	if not ContractOfferState.ALLOWED_ORIGIN_TYPES.has(origin_type):
		errors.append("DeclinedOfferSuppressionKey.origin_type is not allowed.")
	if origin_type == ContractOfferState.ORIGIN_PROBLEM:
		if not StableId.is_valid(related_problem_id):
			errors.append(StableId.validation_error(
				related_problem_id,
				"DeclinedOfferSuppressionKey.related_problem_id"
			))
	elif not related_problem_id.is_empty():
		errors.append("Only problem-origin suppression keys may carry a problem ID.")
	if not ContractOfferState.is_valid_target_lock(target_lock_key):
		errors.append("DeclinedOfferSuppressionKey.target_lock_key is invalid.")
	return errors


func duplicate_value() -> DeclinedOfferSuppressionKey:
	return DeclinedOfferSuppressionKey.new(
		definition_id,
		origin_type,
		related_problem_id,
		target_lock_key
	)


func content_signature() -> String:
	return "%s|%s|%s|%s" % [
		definition_id,
		origin_type,
		related_problem_id,
		target_lock_key,
	]
