class_name ContractClauseDefinition
extends RefCounted

const TraceCondition = preload("res://game/domain/contracts/trace_condition.gd")
const ContractEffect = preload("res://game/domain/contracts/contract_effect.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")

const CATEGORIES: Array[StringName] = [
	&"target_state",
	&"method",
	&"collateral",
	&"secrecy",
	&"delivery",
	&"efficiency",
	&"personnel_safety",
]
const IMPORTANCES: Array[StringName] = [&"mandatory", &"bonus"]

var id: StringName
var display_name_key: StringName
var description_key: StringName
var category: StringName
var importance: StringName
var all_conditions: Array[TraceCondition]
var success_effects: Array[ContractEffect]
var failure_effects: Array[ContractEffect]
var breach_result_cap: StringName
var success_ideology_impact: IdeologyVector
var failure_ideology_impact: IdeologyVector
var success_tags: Array[StringName]
var failure_tags: Array[StringName]
var priority: int


static func create(
	p_id: StringName,
	p_category: StringName,
	p_importance: StringName,
	p_all_conditions: Array[TraceCondition],
	p_success_effects: Array[ContractEffect],
	p_failure_effects: Array[ContractEffect],
	p_breach_result_cap: StringName,
	p_success_ideology_impact: IdeologyVector,
	p_failure_ideology_impact: IdeologyVector,
	p_success_tags: Array[StringName],
	p_failure_tags: Array[StringName],
	p_priority: int = 0,
	p_display_name_key: StringName = &"",
	p_description_key: StringName = &""
) -> ContractClauseDefinition:
	return ContractClauseDefinition.new(
		p_id,
		p_category,
		p_importance,
		p_all_conditions,
		p_success_effects,
		p_failure_effects,
		p_breach_result_cap,
		p_success_ideology_impact,
		p_failure_ideology_impact,
		p_success_tags,
		p_failure_tags,
		p_priority,
		p_display_name_key,
		p_description_key
	)


func _init(
	p_id: StringName,
	p_category: StringName,
	p_importance: StringName,
	p_all_conditions: Array[TraceCondition],
	p_success_effects: Array[ContractEffect],
	p_failure_effects: Array[ContractEffect],
	p_breach_result_cap: StringName,
	p_success_ideology_impact: IdeologyVector,
	p_failure_ideology_impact: IdeologyVector,
	p_success_tags: Array[StringName],
	p_failure_tags: Array[StringName],
	p_priority: int,
	p_display_name_key: StringName,
	p_description_key: StringName
) -> void:
	id = p_id
	category = p_category
	importance = p_importance
	for condition: TraceCondition in p_all_conditions:
		all_conditions.append(condition.duplicate_value() if condition != null else null)
	for effect: ContractEffect in p_success_effects:
		success_effects.append(effect.duplicate_value() if effect != null else null)
	for effect: ContractEffect in p_failure_effects:
		failure_effects.append(effect.duplicate_value() if effect != null else null)
	breach_result_cap = p_breach_result_cap
	success_ideology_impact = p_success_ideology_impact.duplicate_value()
	failure_ideology_impact = p_failure_ideology_impact.duplicate_value()
	success_tags.append_array(p_success_tags)
	failure_tags.append_array(p_failure_tags)
	priority = p_priority
	display_name_key = p_display_name_key
	description_key = p_description_key


func duplicate_value() -> ContractClauseDefinition:
	return ContractClauseDefinition.new(
		id,
		category,
		importance,
		all_conditions,
		success_effects,
		failure_effects,
		breach_result_cap,
		success_ideology_impact,
		failure_ideology_impact,
		success_tags,
		failure_tags,
		priority,
		display_name_key,
		description_key
	)
