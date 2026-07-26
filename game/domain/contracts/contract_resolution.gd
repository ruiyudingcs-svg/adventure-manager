class_name ContractResolution
extends RefCounted

const PhaseResult = preload("res://game/domain/contracts/phase_result.gd")
const ClauseResult = preload("res://game/domain/contracts/clause_result.gd")
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const MemberOutcome = preload("res://game/domain/contracts/member_outcome.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const AttitudeResult = preload("res://game/domain/contracts/attitude_result.gd")

var contract_instance_id: StringName
var initial_result_tier: StringName
var operational_result_tier: StringName
var result_tier: StringName
var contract_score: float
var phase_results: Array[PhaseResult]
var clause_results: Array[ClauseResult]
var final_context: MissionContext
var reward: int
var supply_cost_total: int
var member_outcomes: Array[MemberOutcome]
var sponsor_relation_delta: int
var situation_outcomes: Array[WorldEffect]
var outcome_tags: Array[StringName]
var reason_entries: Array[ReasonEntry]
var consumed_supply_ids: Array[StringName]
var attitude_results: Array[AttitudeResult]
var state_changes: Array = []


static func create(
	p_contract_instance_id: StringName,
	p_initial_result_tier: StringName,
	p_operational_result_tier: StringName,
	p_result_tier: StringName,
	p_contract_score: float,
	p_phase_results: Array[PhaseResult],
	p_clause_results: Array[ClauseResult],
	p_final_context: MissionContext,
	p_reward: int,
	p_supply_cost_total: int,
	p_member_outcomes: Array[MemberOutcome],
	p_sponsor_relation_delta: int,
	p_situation_outcomes: Array[WorldEffect],
	p_outcome_tags: Array[StringName],
	p_reason_entries: Array[ReasonEntry],
	p_consumed_supply_ids: Array[StringName],
	p_attitude_results: Array[AttitudeResult]
) -> ContractResolution:
	return ContractResolution.new(
		p_contract_instance_id,
		p_initial_result_tier,
		p_operational_result_tier,
		p_result_tier,
		p_contract_score,
		p_phase_results,
		p_clause_results,
		p_final_context,
		p_reward,
		p_supply_cost_total,
		p_member_outcomes,
		p_sponsor_relation_delta,
		p_situation_outcomes,
		p_outcome_tags,
		p_reason_entries,
		p_consumed_supply_ids,
		p_attitude_results
	)


func _init(
	p_contract_instance_id: StringName,
	p_initial_result_tier: StringName,
	p_operational_result_tier: StringName,
	p_result_tier: StringName,
	p_contract_score: float,
	p_phase_results: Array[PhaseResult],
	p_clause_results: Array[ClauseResult],
	p_final_context: MissionContext,
	p_reward: int,
	p_supply_cost_total: int,
	p_member_outcomes: Array[MemberOutcome],
	p_sponsor_relation_delta: int,
	p_situation_outcomes: Array[WorldEffect],
	p_outcome_tags: Array[StringName],
	p_reason_entries: Array[ReasonEntry],
	p_consumed_supply_ids: Array[StringName],
	p_attitude_results: Array[AttitudeResult]
) -> void:
	contract_instance_id = p_contract_instance_id
	initial_result_tier = p_initial_result_tier
	operational_result_tier = p_operational_result_tier
	result_tier = p_result_tier
	contract_score = p_contract_score
	for value: PhaseResult in p_phase_results:
		phase_results.append(value.duplicate_value())
	for value: ClauseResult in p_clause_results:
		clause_results.append(value.duplicate_value())
	final_context = p_final_context.duplicate_value()
	reward = p_reward
	supply_cost_total = p_supply_cost_total
	for value: MemberOutcome in p_member_outcomes:
		member_outcomes.append(value.duplicate_value())
	sponsor_relation_delta = p_sponsor_relation_delta
	for value: WorldEffect in p_situation_outcomes:
		situation_outcomes.append(value.duplicate_value())
	outcome_tags.append_array(p_outcome_tags)
	for value: ReasonEntry in p_reason_entries:
		reason_entries.append(value.duplicate_value())
	consumed_supply_ids.append_array(p_consumed_supply_ids)
	for value: AttitudeResult in p_attitude_results:
		attitude_results.append(value.duplicate_value())
