class_name ContractOutcomeTable
extends RefCounted

const ContractOutcomeDefinition = preload("res://game/domain/contracts/contract_outcome_definition.gd")

var _outcomes: Dictionary[StringName, ContractOutcomeDefinition] = {}


static func create(
	exceptional: ContractOutcomeDefinition,
	success: ContractOutcomeDefinition,
partial: ContractOutcomeDefinition,
	failure: ContractOutcomeDefinition,
	severe: ContractOutcomeDefinition
) -> ContractOutcomeTable:
	return ContractOutcomeTable.new(exceptional, success, partial, failure, severe)


func _init(
	exceptional: ContractOutcomeDefinition,
	success: ContractOutcomeDefinition,
	partial: ContractOutcomeDefinition,
	failure: ContractOutcomeDefinition,
	severe: ContractOutcomeDefinition
) -> void:
	_outcomes[&"exceptional"] = exceptional.duplicate_value()
	_outcomes[&"success"] = success.duplicate_value()
	_outcomes[&"partial"] = partial.duplicate_value()
	_outcomes[&"failure"] = failure.duplicate_value()
	_outcomes[&"severe"] = severe.duplicate_value()


func get_outcome(tier: StringName) -> ContractOutcomeDefinition:
	var outcome: ContractOutcomeDefinition = _outcomes.get(tier)
	return null if outcome == null else outcome.duplicate_value()


func duplicate_value() -> ContractOutcomeTable:
	return ContractOutcomeTable.new(
		_outcomes[&"exceptional"],
		_outcomes[&"success"],
		_outcomes[&"partial"],
		_outcomes[&"failure"],
		_outcomes[&"severe"]
	)
