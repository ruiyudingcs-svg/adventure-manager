class_name PhaseResult
extends RefCounted

const CheckResult = preload("res://game/domain/contracts/check_result.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

var phase: StringName
var check_result: CheckResult
var reason_entries: Array[ReasonEntry]


static func create(
	p_phase: StringName,
	p_check_result: CheckResult,
	p_reason_entries: Array[ReasonEntry]
) -> PhaseResult:
	return PhaseResult.new(p_phase, p_check_result, p_reason_entries)


func _init(
	p_phase: StringName,
	p_check_result: CheckResult,
	p_reason_entries: Array[ReasonEntry]
) -> void:
	phase = p_phase
	check_result = p_check_result.duplicate_value()
	for reason: ReasonEntry in p_reason_entries:
		reason_entries.append(reason.duplicate_value())


func duplicate_value() -> PhaseResult:
	return PhaseResult.new(phase, check_result, reason_entries)
