class_name CheckOutcomeTable
extends RefCounted

const CheckOutcomeDefinition = preload("res://game/domain/contracts/check_outcome_definition.gd")

const TIERS: Array[StringName] = [
	&"exceptional",
	&"success",
	&"partial",
	&"failure",
	&"severe",
]

var _outcomes: Dictionary[StringName, CheckOutcomeDefinition] = {}


static func create(
	exceptional: CheckOutcomeDefinition,
	success: CheckOutcomeDefinition,
	partial: CheckOutcomeDefinition,
	failure: CheckOutcomeDefinition,
	severe: CheckOutcomeDefinition
) -> CheckOutcomeTable:
	return CheckOutcomeTable.new(exceptional, success, partial, failure, severe)


func _init(
	exceptional: CheckOutcomeDefinition,
	success: CheckOutcomeDefinition,
	partial: CheckOutcomeDefinition,
	failure: CheckOutcomeDefinition,
	severe: CheckOutcomeDefinition
) -> void:
	_outcomes[&"exceptional"] = exceptional.duplicate_value()
	_outcomes[&"success"] = success.duplicate_value()
	_outcomes[&"partial"] = partial.duplicate_value()
	_outcomes[&"failure"] = failure.duplicate_value()
	_outcomes[&"severe"] = severe.duplicate_value()


func get_outcome(tier: StringName) -> CheckOutcomeDefinition:
	var outcome: CheckOutcomeDefinition = _outcomes.get(tier)
	return null if outcome == null else outcome.duplicate_value()


func duplicate_value() -> CheckOutcomeTable:
	return CheckOutcomeTable.new(
		_outcomes[&"exceptional"],
		_outcomes[&"success"],
		_outcomes[&"partial"],
		_outcomes[&"failure"],
		_outcomes[&"severe"]
	)
