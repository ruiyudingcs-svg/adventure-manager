class_name ContractStageDefinition
extends RefCounted

const ContractCheckDefinition = preload("res://game/domain/contracts/contract_check_definition.gd")

const PHASES: Array[StringName] = [
	&"approach",
	&"main_action",
	&"special_objective",
	&"extraction",
]

var id: StringName
var phase: StringName
var check: ContractCheckDefinition


static func create(
	p_id: StringName,
	p_phase: StringName,
	p_check: ContractCheckDefinition
) -> ContractStageDefinition:
	return ContractStageDefinition.new(p_id, p_phase, p_check)


func _init(
	p_id: StringName,
	p_phase: StringName,
	p_check: ContractCheckDefinition
) -> void:
	id = p_id
	phase = p_phase
	check = p_check.duplicate_value() if p_check != null else null


func duplicate_value() -> ContractStageDefinition:
	return ContractStageDefinition.new(id, phase, check)
