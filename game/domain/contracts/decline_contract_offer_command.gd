class_name DeclineContractOfferCommand
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

var contract_offer_id: StringName


static func create(p_contract_offer_id: StringName) -> DeclineContractOfferCommand:
	return DeclineContractOfferCommand.new(p_contract_offer_id)


func _init(p_contract_offer_id: StringName) -> void:
	contract_offer_id = p_contract_offer_id


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(contract_offer_id):
		errors.append(StableId.validation_error(
			contract_offer_id,
			"DeclineContractOfferCommand.contract_offer_id"
		))
	return errors


func duplicate_value() -> DeclineContractOfferCommand:
	return DeclineContractOfferCommand.new(contract_offer_id)


func content_signature() -> String:
	return String(contract_offer_id)
