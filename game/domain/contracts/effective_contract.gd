class_name EffectiveContract
extends RefCounted

const ContractStageDefinition = preload("res://game/domain/contracts/contract_stage_definition.gd")
const ContractOutcomeTable = preload("res://game/domain/contracts/contract_outcome_table.gd")
const ContractClauseDefinition = preload("res://game/domain/contracts/contract_clause_definition.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const MethodTagDefinition = preload("res://game/domain/contracts/method_tag_definition.gd")

var instance_id: StringName
var definition_id: StringName
var offered_reward: int
var base_fatigue: int
var risk_level: int
var sponsor_relation_snapshot: int
var intent_ideology_vector: IdeologyVector
var expected_method_tags: Array[StringName]
var allowed_supply_tags: Array[StringName]
var stages: Array[ContractStageDefinition]
var clauses: Array[ContractClauseDefinition]
var initial_context_deltas: Array[Dictionary]
var final_outcome_table: ContractOutcomeTable
var method_tag_definitions: Array[MethodTagDefinition]


static func create_complete(
	p_instance_id: StringName,
	p_definition_id: StringName,
	p_offered_reward: int,
	p_base_fatigue: int,
	p_risk_level: int,
	p_sponsor_relation_snapshot: int,
	p_intent_ideology_vector: IdeologyVector,
	p_expected_method_tags: Array[StringName],
	p_allowed_supply_tags: Array[StringName],
	p_stages: Array[ContractStageDefinition],
	p_clauses: Array[ContractClauseDefinition],
	p_initial_context_deltas: Array[Dictionary],
	p_final_outcome_table: ContractOutcomeTable,
	p_method_tag_definitions: Array[MethodTagDefinition]
) -> EffectiveContract:
	return EffectiveContract.new(
		p_instance_id,
		p_definition_id,
		p_offered_reward,
		p_base_fatigue,
		p_risk_level,
		p_sponsor_relation_snapshot,
		p_intent_ideology_vector,
		p_expected_method_tags,
		p_allowed_supply_tags,
		p_stages,
		p_clauses,
		p_initial_context_deltas,
		p_final_outcome_table,
		p_method_tag_definitions
	)


func _init(
	p_instance_id: StringName,
	p_definition_id: StringName,
	p_offered_reward: int,
	p_base_fatigue: int,
	p_risk_level: int,
	p_sponsor_relation_snapshot: int,
	p_intent_ideology_vector: IdeologyVector,
	p_expected_method_tags: Array[StringName],
	p_allowed_supply_tags: Array[StringName],
	p_stages: Array[ContractStageDefinition],
	p_clauses: Array[ContractClauseDefinition],
	p_initial_context_deltas: Array[Dictionary],
	p_final_outcome_table: ContractOutcomeTable,
	p_method_tag_definitions: Array[MethodTagDefinition]
) -> void:
	instance_id = p_instance_id
	definition_id = p_definition_id
	offered_reward = p_offered_reward
	base_fatigue = p_base_fatigue
	risk_level = p_risk_level
	sponsor_relation_snapshot = p_sponsor_relation_snapshot
	intent_ideology_vector = (
		p_intent_ideology_vector.duplicate_value()
		if p_intent_ideology_vector != null
		else null
	)
	expected_method_tags.append_array(p_expected_method_tags)
	allowed_supply_tags.append_array(p_allowed_supply_tags)
	for stage: ContractStageDefinition in p_stages:
		stages.append(stage.duplicate_value() if stage != null else null)
	for clause: ContractClauseDefinition in p_clauses:
		clauses.append(clause.duplicate_value() if clause != null else null)
	for delta: Dictionary in p_initial_context_deltas:
		initial_context_deltas.append(delta.duplicate(true))
	final_outcome_table = (
		p_final_outcome_table.duplicate_value()
		if p_final_outcome_table != null
		else null
	)
	for definition: MethodTagDefinition in p_method_tag_definitions:
		method_tag_definitions.append(
			definition.duplicate_value() if definition != null else null
		)


func duplicate_value() -> EffectiveContract:
	return EffectiveContract.new(
		instance_id,
		definition_id,
		offered_reward,
		base_fatigue,
		risk_level,
		sponsor_relation_snapshot,
		intent_ideology_vector,
		expected_method_tags,
		allowed_supply_tags,
		stages,
		clauses,
		initial_context_deltas,
		final_outcome_table,
		method_tag_definitions
	)
