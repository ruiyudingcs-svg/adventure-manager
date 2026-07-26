class_name ClauseResult
extends RefCounted

const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const ContractEffect = preload("res://game/domain/contracts/contract_effect.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")

var clause_id: StringName
var category: StringName
var importance: StringName
var satisfied: bool
var evidence: Array[StringName]
var reason_entries: Array[ReasonEntry]
var effects: Array[ContractEffect]
var ideology_impact: IdeologyVector
var outcome_tags: Array[StringName]
var result_cap: StringName


static func create(
	p_clause_id: StringName,
	p_category: StringName,
	p_importance: StringName,
	p_satisfied: bool,
	p_evidence: Array[StringName],
	p_reason_entries: Array[ReasonEntry],
	p_effects: Array[ContractEffect],
	p_ideology_impact: IdeologyVector,
	p_outcome_tags: Array[StringName],
	p_result_cap: StringName
) -> ClauseResult:
	return ClauseResult.new(
		p_clause_id,
		p_category,
		p_importance,
		p_satisfied,
		p_evidence,
		p_reason_entries,
		p_effects,
		p_ideology_impact,
		p_outcome_tags,
		p_result_cap
	)


func _init(
	p_clause_id: StringName,
	p_category: StringName,
	p_importance: StringName,
	p_satisfied: bool,
	p_evidence: Array[StringName],
	p_reason_entries: Array[ReasonEntry],
	p_effects: Array[ContractEffect],
	p_ideology_impact: IdeologyVector,
	p_outcome_tags: Array[StringName],
	p_result_cap: StringName
) -> void:
	clause_id = p_clause_id
	category = p_category
	importance = p_importance
	satisfied = p_satisfied
	evidence.append_array(p_evidence)
	for reason: ReasonEntry in p_reason_entries:
		reason_entries.append(reason.duplicate_value())
	for effect: ContractEffect in p_effects:
		effects.append(effect.duplicate_value())
	ideology_impact = p_ideology_impact.duplicate_value()
	outcome_tags.append_array(p_outcome_tags)
	result_cap = p_result_cap


func duplicate_value() -> ClauseResult:
	return ClauseResult.new(
		clause_id,
		category,
		importance,
		satisfied,
		evidence,
		reason_entries,
		effects,
		ideology_impact,
		outcome_tags,
		result_cap
	)
