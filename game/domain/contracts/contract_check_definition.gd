class_name ContractCheckDefinition
extends RefCounted

const CapabilityWeights = preload("res://game/domain/contracts/capability_weights.gd")
const MissionModifier = preload("res://game/domain/contracts/mission_modifier.gd")
const CheckOutcomeTable = preload("res://game/domain/contracts/check_outcome_table.gd")

const CHECK_TYPES: Array[StringName] = [
	&"navigation",
	&"reconnaissance",
	&"confrontation",
	&"protection",
	&"rescue",
	&"ritual",
	&"salvage",
	&"extraction",
]
const APPROACH_PROFILES: Array[StringName] = [&"careful", &"forceful", &"neutral"]

var id: StringName
var check_type: StringName
var capability_weights: CapabilityWeights
var difficulty: int
var result_weight: float
var failure_result_cap: StringName
var method_tags: Array[StringName]
var context_modifiers: Array[MissionModifier]
var approach_profile: StringName
var outcome_table: CheckOutcomeTable


static func create(
	p_id: StringName,
	p_check_type: StringName,
	p_capability_weights: CapabilityWeights,
	p_difficulty: int,
	p_result_weight: float,
	p_failure_result_cap: StringName,
	p_method_tags: Array[StringName],
	p_context_modifiers: Array[MissionModifier],
	p_approach_profile: StringName,
	p_outcome_table: CheckOutcomeTable
) -> ContractCheckDefinition:
	return ContractCheckDefinition.new(
		p_id,
		p_check_type,
		p_capability_weights,
		p_difficulty,
		p_result_weight,
		p_failure_result_cap,
		p_method_tags,
		p_context_modifiers,
		p_approach_profile,
		p_outcome_table
	)


func _init(
	p_id: StringName,
	p_check_type: StringName,
	p_capability_weights: CapabilityWeights,
	p_difficulty: int,
	p_result_weight: float,
	p_failure_result_cap: StringName,
	p_method_tags: Array[StringName],
	p_context_modifiers: Array[MissionModifier],
	p_approach_profile: StringName,
	p_outcome_table: CheckOutcomeTable
) -> void:
	id = p_id
	check_type = p_check_type
	capability_weights = p_capability_weights.duplicate_value() if p_capability_weights != null else null
	difficulty = p_difficulty
	result_weight = p_result_weight
	failure_result_cap = p_failure_result_cap
	method_tags.append_array(p_method_tags)
	for modifier: MissionModifier in p_context_modifiers:
		context_modifiers.append(modifier.duplicate_value())
	approach_profile = p_approach_profile
	outcome_table = p_outcome_table.duplicate_value() if p_outcome_table != null else null


func duplicate_value() -> ContractCheckDefinition:
	return ContractCheckDefinition.new(
		id,
		check_type,
		capability_weights,
		difficulty,
		result_weight,
		failure_result_cap,
		method_tags,
		context_modifiers,
		approach_profile,
		outcome_table
	)
