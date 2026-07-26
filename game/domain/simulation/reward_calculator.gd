class_name RewardCalculator
extends RefCounted

const ContractOutcomeDefinition = preload("res://game/domain/contracts/contract_outcome_definition.gd")
const ClauseResult = preload("res://game/domain/contracts/clause_result.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")


class RewardResult extends RefCounted:
	var reward: int
	var clause_reward_percent_delta: int
	var reward_percent: int
	var sponsor_relation_delta: int
	var reason_entries: Array[ReasonEntry]


static func calculate(
	offered_reward: int,
	final_outcome: ContractOutcomeDefinition,
	clause_results: Array[ClauseResult],
	contract_id: StringName
) -> RewardResult:
	var result := RewardResult.new()
	var raw_reward_percent_delta: int = 0
	var clause_relation_delta: int = 0
	for clause: ClauseResult in clause_results:
		for effect in clause.effects:
			if effect.type == &"modify_reward_percent":
				raw_reward_percent_delta += effect.amount
			elif effect.type == &"modify_sponsor_relation":
				clause_relation_delta += effect.amount
	result.clause_reward_percent_delta = clampi(raw_reward_percent_delta, -100, 100)
	result.reward_percent = maxi(0, 100 + result.clause_reward_percent_delta)
	result.reward = maxi(0, roundi(
		offered_reward
		* final_outcome.reward_multiplier
		* result.reward_percent
		/ 100.0
	))
	result.sponsor_relation_delta = clampi(
		final_outcome.sponsor_relation_delta + clause_relation_delta,
		-20,
		20
	)
	result.reason_entries.append(ReasonEntry.create(
		&"contract_reward",
		&"reward",
		contract_id,
		&"",
		result.reward,
		&"",
		{
			"offered_reward": offered_reward,
			"reward_multiplier": final_outcome.reward_multiplier,
			"reward_percent": result.reward_percent,
		},
		&"final",
		ReasonEntry.VISIBILITY_PLAYER
	))
	if result.sponsor_relation_delta != 0:
		result.reason_entries.append(ReasonEntry.create(
			&"sponsor_relation_delta",
			&"relationship",
			contract_id,
			&"",
			result.sponsor_relation_delta,
			&"",
			{},
			&"final",
			ReasonEntry.VISIBILITY_PLAYER
		))
	return result
