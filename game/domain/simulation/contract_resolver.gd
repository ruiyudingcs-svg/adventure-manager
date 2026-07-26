class_name ContractResolver
extends RefCounted

const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const ContractStageDefinition = preload("res://game/domain/contracts/contract_stage_definition.gd")
const ContractCheckDefinition = preload("res://game/domain/contracts/contract_check_definition.gd")
const CheckOutcomeDefinition = preload("res://game/domain/contracts/check_outcome_definition.gd")
const CheckOutcomeTable = preload("res://game/domain/contracts/check_outcome_table.gd")
const ContractOutcomeDefinition = preload("res://game/domain/contracts/contract_outcome_definition.gd")
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const MissionModifier = preload("res://game/domain/contracts/mission_modifier.gd")
const CheckResult = preload("res://game/domain/contracts/check_result.gd")
const PhaseResult = preload("res://game/domain/contracts/phase_result.gd")
const ResolutionTrace = preload("res://game/domain/contracts/resolution_trace.gd")
const ContractResolution = preload("res://game/domain/contracts/contract_resolution.gd")
const MemberEffect = preload("res://game/domain/contracts/member_effect.gd")
const MemberOutcome = preload("res://game/domain/contracts/member_outcome.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const AttitudeResult = preload("res://game/domain/contracts/attitude_result.gd")
const ClauseResult = preload("res://game/domain/contracts/clause_result.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const TeamCapabilityCalculator = preload("res://game/domain/simulation/team_capability_calculator.gd")
const CheckScoreCalculator = preload("res://game/domain/simulation/check_score_calculator.gd")
const MissionContextReducer = preload("res://game/domain/simulation/mission_context_reducer.gd")
const ContractPlanValidator = preload("res://game/domain/simulation/contract_plan_validator.gd")
const AttitudeCalculator = preload("res://game/domain/simulation/attitude_calculator.gd")
const ClauseEvaluator = preload("res://game/domain/simulation/clause_evaluator.gd")
const MemberOutcomeCalculator = preload("res://game/domain/simulation/member_outcome_calculator.gd")
const RewardCalculator = preload("res://game/domain/simulation/reward_calculator.gd")

const WEIGHT_EPSILON: float = 0.0001
const CHECK_EXCEPTIONAL_THRESHOLD: int = 70
const CHECK_SUCCESS_THRESHOLD: int = 50
const CHECK_PARTIAL_THRESHOLD: int = 30
const CHECK_FAILURE_THRESHOLD: int = 10
const CONTRACT_EXCEPTIONAL_THRESHOLD: float = 80.0
const CONTRACT_SUCCESS_THRESHOLD: float = 60.0
const CONTRACT_PARTIAL_THRESHOLD: float = 40.0
const CONTRACT_FAILURE_THRESHOLD: float = 20.0
const TIERS: Array[StringName] = [
	&"severe",
	&"failure",
	&"partial",
	&"success",
	&"exceptional",
]


class ResolveResult extends RefCounted:
	var trace: ResolutionTrace
	var resolution: ContractResolution
	var errors: PackedStringArray


	func is_success() -> bool:
		return resolution != null and trace != null and errors.is_empty()


static func resolve(
	contract: EffectiveContract,
	plan: ContractPlan,
	contract_seed: int,
	guild_base_cohesion: int
) -> ResolveResult:
	var result := ResolveResult.new()
	var plan_validation: ContractPlanValidator.ValidationResult
	if contract != null and plan != null:
		plan_validation = ContractPlanValidator.validate(contract, plan)
	result.errors = validate_request(contract, plan, guild_base_cohesion)
	if plan_validation != null:
		result.errors.append_array(plan_validation.errors)
	if not result.errors.is_empty():
		return result

	var context: MissionContext = MissionContextReducer.apply(
		MissionContext.create_default(),
		contract.initial_context_deltas
	)
	context = MissionContextReducer.apply(context, _approach_context_deltas(plan.approach))
	var phase_results: Array[PhaseResult] = []
	var pending_member_effects: Array[MemberEffect] = []
	var pending_campaign_effects: Array[WorldEffect] = []
	var check_caps: Array[StringName] = []
	var strictest_check_cap: StringName = &""
	var ideology_impact: IdeologyVector = IdeologyVector.create_task_accumulation(0, 0, 0, 0, 0)
	var previous_check_tier: StringName = &""
	var contract_score: float = 0.0
	var supply_tags: Array[StringName] = _supply_tags(plan)

	for stage: ContractStageDefinition in contract.stages:
		var check: ContractCheckDefinition = stage.check
		var context_before: MissionContext = context.duplicate_value()
		var score_result: CheckScoreCalculator.ScoreResult = CheckScoreCalculator.calculate(
			check,
			stage.phase,
			plan.members,
			context_before,
			previous_check_tier,
			supply_tags,
			plan.approach,
			guild_base_cohesion,
			contract_seed
		)
		var attitude_results: Array[AttitudeResult] = []
		for member_index: int in range(plan.members.size()):
			attitude_results.append(AttitudeCalculator.calculate_for_check(
				contract,
				plan.members[member_index],
				check.method_tags,
				plan_validation.attitude_results[member_index]
			))
		var preparation_modifier: int = _preparation_modifier(plan, check.check_type)
		var approach_modifier: int = _approach_check_modifier(
			plan.approach,
			check.approach_profile
		)
		var attitude_modifier: float = AttitudeCalculator.check_modifier(attitude_results)
		var adjusted_reasons: Array[ReasonEntry] = _adjust_score_reasons(
			score_result.reason_entries,
			stage.phase,
			check.id,
			check.check_type,
			preparation_modifier,
			approach_modifier,
			attitude_modifier,
			attitude_results,
			plan
		)
		var adjusted_raw_score: float = score_result.raw_score \
			+ preparation_modifier \
			+ approach_modifier \
			+ attitude_modifier
		var adjusted_score: int = roundi(adjusted_raw_score)
		if absf(adjusted_score - adjusted_raw_score) > 0.000001:
			adjusted_reasons.append(_reason(
				&"score_rounding",
				&"rounding",
				check.id,
				&"",
				adjusted_score - adjusted_raw_score,
				stage.phase,
				ReasonEntry.VISIBILITY_DEBUG
			))
		var result_tier: StringName = tier_for_score(adjusted_score)
		var outcome: CheckOutcomeDefinition = check.outcome_table.get_outcome(result_tier)
		var check_result: CheckResult = CheckResult.create(
			check.id,
			stage.phase,
			check.check_type,
			adjusted_raw_score,
			adjusted_score,
			result_tier,
			check.result_weight,
			score_result.check_seed,
			check.method_tags,
			context_before,
			outcome.context_deltas,
			adjusted_reasons,
			outcome.member_effects,
			outcome.campaign_effects,
			outcome.ideology_impact,
			outcome.outcome_tags
		)
		phase_results.append(PhaseResult.create(stage.phase, check_result, adjusted_reasons))
		context = MissionContextReducer.apply(
			context,
			outcome.context_deltas,
			outcome.outcome_tags,
			check.method_tags
		)
		for effect: MemberEffect in outcome.member_effects:
			pending_member_effects.append(effect.duplicate_value())
		for effect: WorldEffect in outcome.campaign_effects:
			pending_campaign_effects.append(effect.duplicate_value())
		ideology_impact = ideology_impact.added_and_clamped_for_task(outcome.ideology_impact)
		contract_score += tier_points(result_tier) * check.result_weight
		if (result_tier == &"failure" or result_tier == &"severe") \
			and not check.failure_result_cap.is_empty():
			check_caps.append(check.failure_result_cap)
			strictest_check_cap = stricter_tier(strictest_check_cap, check.failure_result_cap)
		previous_check_tier = result_tier

	var initial_tier: StringName = tier_for_contract_score(contract_score)
	var operational_tier: StringName = stricter_tier(initial_tier, strictest_check_cap)
	result.trace = ResolutionTrace.create(
		phase_results,
		context,
		contract_score,
		initial_tier,
		check_caps,
		strictest_check_cap,
		pending_member_effects,
		pending_campaign_effects,
		ideology_impact,
		context.outcome_tags,
		context.used_method_tags
	)
	var operational_outcome: ContractOutcomeDefinition = (
		contract.final_outcome_table.get_outcome(operational_tier)
	)
	var injury_outcomes: Array[MemberOutcome] = MemberOutcomeCalculator.calculate_injuries(
		contract,
		plan,
		result.trace,
		operational_outcome,
		contract_seed
	)
	var clause_evaluation: ClauseEvaluator.EvaluationResult = ClauseEvaluator.evaluate(
		contract,
		plan,
		result.trace,
		injury_outcomes
	)
	if not clause_evaluation.errors.is_empty():
		result.errors.append_array(clause_evaluation.errors)
		result.trace = null
		return result
	var final_tier: StringName = stricter_tier(
		operational_tier,
		clause_evaluation.strictest_cap
	)
	var final_outcome: ContractOutcomeDefinition = contract.final_outcome_table.get_outcome(final_tier)
	var reward_result: RewardCalculator.RewardResult = RewardCalculator.calculate(
		contract.offered_reward,
		final_outcome,
		clause_evaluation.clause_results,
		contract.definition_id
	)
	var member_outcomes: Array[MemberOutcome] = MemberOutcomeCalculator.finalize(
		contract,
		plan,
		result.trace,
		injury_outcomes,
		clause_evaluation.clause_results,
		final_outcome
	)
	var situation_outcomes: Array[WorldEffect] = []
	for effect: WorldEffect in pending_campaign_effects:
		situation_outcomes.append(effect.duplicate_value())
	for effect: WorldEffect in final_outcome.campaign_effects:
		situation_outcomes.append(effect.duplicate_value())
	var outcome_tags: Array[StringName] = []
	for tag: StringName in result.trace.outcome_tags:
		_append_unique(outcome_tags, tag)
	for clause_result: ClauseResult in clause_evaluation.clause_results:
		for tag: StringName in clause_result.outcome_tags:
			_append_unique(outcome_tags, tag)
		for effect in clause_result.effects:
			if effect.type == &"add_outcome_tag":
				_append_unique(outcome_tags, effect.tag_value)
	for tag: StringName in final_outcome.outcome_tags:
		_append_unique(outcome_tags, tag)
	var resolution_reasons: Array[ReasonEntry] = []
	for reason: ReasonEntry in plan_validation.reason_entries:
		resolution_reasons.append(reason.duplicate_value())
	for clause_result: ClauseResult in clause_evaluation.clause_results:
		for reason: ReasonEntry in clause_result.reason_entries:
			resolution_reasons.append(reason.duplicate_value())
	for reason: ReasonEntry in reward_result.reason_entries:
		resolution_reasons.append(reason.duplicate_value())
	for member_outcome: MemberOutcome in member_outcomes:
		for reason: ReasonEntry in member_outcome.reason_entries:
			resolution_reasons.append(reason.duplicate_value())
	var consumed_supply_ids: Array[StringName] = []
	var supply_cost_total: int = 0
	for supply in plan.selected_supplies:
		supply_cost_total += supply.cost
		if supply.consumed_on_use:
			consumed_supply_ids.append(supply.id)
	result.resolution = ContractResolution.create(
		contract.instance_id,
		initial_tier,
		operational_tier,
		final_tier,
		contract_score,
		phase_results,
		clause_evaluation.clause_results,
		context,
		reward_result.reward,
		supply_cost_total,
		member_outcomes,
		reward_result.sponsor_relation_delta,
		situation_outcomes,
		outcome_tags,
		resolution_reasons,
		consumed_supply_ids,
		plan_validation.attitude_results
	)
	return result


static func validate_request(
	contract: EffectiveContract,
	plan: ContractPlan,
	guild_base_cohesion: int
) -> PackedStringArray:
	var errors := PackedStringArray()
	if contract == null:
		errors.append("EffectiveContract is required.")
	if plan == null:
		errors.append("ContractPlan is required.")
	if contract == null or plan == null:
		return errors
	if guild_base_cohesion < 0 or guild_base_cohesion > 100:
		errors.append("guild_base_cohesion must be between 0 and 100.")
	if contract.offered_reward < 0 or contract.base_fatigue < 0:
		errors.append("EffectiveContract reward and base fatigue must be non-negative.")
	if contract.risk_level < 1 or contract.risk_level > 5:
		errors.append("EffectiveContract risk_level must be between 1 and 5.")
	if contract.sponsor_relation_snapshot < -100 or contract.sponsor_relation_snapshot > 100:
		errors.append("EffectiveContract sponsor relation snapshot must be between -100 and 100.")
	if contract.intent_ideology_vector == null:
		errors.append("EffectiveContract intent ideology vector is required.")
	for allowed_tag: StringName in contract.allowed_supply_tags:
		if not ContractPlanValidator.SUPPLY_TAGS.has(allowed_tag):
			errors.append("Unknown allowed supply tag: %s." % allowed_tag)

	errors.append_array(TeamCapabilityCalculator.validate_team(plan.members))
	errors.append_array(CheckScoreCalculator.validate_relationships(plan.members))
	errors.append_array(MissionContextReducer.validate_deltas(contract.initial_context_deltas))
	errors.append_array(ClauseEvaluator.validate_definitions(contract))

	if contract.stages.size() != ContractStageDefinition.PHASES.size():
		errors.append("EffectiveContract must contain exactly four stages.")
	var stage_ids: Dictionary[StringName, bool] = {}
	var check_ids: Dictionary[StringName, bool] = {}
	var weight_total: float = 0.0
	for index: int in range(contract.stages.size()):
		var stage: ContractStageDefinition = contract.stages[index]
		if stage == null:
			errors.append("Contract stage cannot be null.")
			continue
		if index >= ContractStageDefinition.PHASES.size() \
			or stage.phase != ContractStageDefinition.PHASES[index]:
			errors.append("Contract phases must be approach, main_action, special_objective, extraction.")
		if stage.id.is_empty():
			errors.append("Contract stage ID cannot be empty.")
		elif stage_ids.has(stage.id):
			errors.append("Contract stage IDs must be unique.")
		stage_ids[stage.id] = true
		if stage.check == null:
			errors.append("Each contract stage must contain exactly one check.")
			continue
		var check: ContractCheckDefinition = stage.check
		if check.id.is_empty():
			errors.append("Contract check ID cannot be empty.")
		elif check_ids.has(check.id):
			errors.append("Contract check IDs must be unique.")
		check_ids[check.id] = true
		if not ContractCheckDefinition.CHECK_TYPES.has(check.check_type):
			errors.append("Unknown check type: %s." % check.check_type)
		if not ContractCheckDefinition.APPROACH_PROFILES.has(check.approach_profile):
			errors.append("Unknown approach profile: %s." % check.approach_profile)
		if check.capability_weights == null:
			errors.append("Check capability weights are required.")
		if check.result_weight <= 0.0:
			errors.append("Each check result_weight must be greater than zero.")
		weight_total += check.result_weight
		if not check.failure_result_cap.is_empty() \
			and not CheckOutcomeTable.TIERS.has(check.failure_result_cap):
			errors.append("Unknown failure_result_cap: %s." % check.failure_result_cap)
		errors.append_array(_validate_modifiers(check.context_modifiers))
		errors.append_array(_validate_outcomes(check.outcome_table))
	if absf(weight_total - 1.0) > WEIGHT_EPSILON:
		errors.append("Check result weights must sum to 1.0 within epsilon %f." % WEIGHT_EPSILON)
	errors.append_array(_validate_final_outcomes(contract))
	return errors


static func tier_for_score(score: int) -> StringName:
	# Accepted Task017 balance pass: check bands are 70/50/30/10 while the
	# weighted contract bands remain 80/60/40/20. Keep these mappings distinct.
	if score >= CHECK_EXCEPTIONAL_THRESHOLD:
		return &"exceptional"
	if score >= CHECK_SUCCESS_THRESHOLD:
		return &"success"
	if score >= CHECK_PARTIAL_THRESHOLD:
		return &"partial"
	if score >= CHECK_FAILURE_THRESHOLD:
		return &"failure"
	return &"severe"


static func tier_for_contract_score(score: float) -> StringName:
	if score >= CONTRACT_EXCEPTIONAL_THRESHOLD:
		return &"exceptional"
	if score >= CONTRACT_SUCCESS_THRESHOLD:
		return &"success"
	if score >= CONTRACT_PARTIAL_THRESHOLD:
		return &"partial"
	if score >= CONTRACT_FAILURE_THRESHOLD:
		return &"failure"
	return &"severe"


static func tier_points(tier: StringName) -> float:
	match tier:
		&"exceptional":
			return 100.0
		&"success":
			return 75.0
		&"partial":
			return 50.0
		&"failure":
			return 25.0
	return 0.0


static func stricter_tier(left: StringName, right: StringName) -> StringName:
	if left.is_empty():
		return right
	if right.is_empty():
		return left
	return left if _tier_rank(left) <= _tier_rank(right) else right


static func _approach_context_deltas(approach: StringName) -> Array[Dictionary]:
	var deltas: Array[Dictionary] = []
	if approach == &"cautious":
		deltas.append(MissionContext.create_delta(&"time_pressure", 1, &"approach_cautious"))
	elif approach == &"aggressive":
		deltas.append(MissionContext.create_delta(&"alert_level", 1, &"approach_aggressive"))
		deltas.append(MissionContext.create_delta(&"team_strain", 1, &"approach_aggressive"))
		deltas.append(MissionContext.create_delta(
			&"collateral_pressure",
			1,
			&"approach_aggressive"
		))
	return deltas


static func _approach_check_modifier(
	approach: StringName,
	profile: StringName
) -> int:
	if approach == &"cautious":
		return 3 if profile == &"careful" else (-3 if profile == &"forceful" else 0)
	if approach == &"aggressive":
		return -3 if profile == &"careful" else (5 if profile == &"forceful" else 0)
	return 0


static func _preparation_modifier(
	plan: ContractPlan,
	check_type: StringName
) -> int:
	var total: int = 0
	for supply in plan.selected_supplies:
		for modifier in supply.modifiers:
			if modifier.target_type == &"check" and modifier.match_tag == check_type:
				total += modifier.amount
	return total


static func _supply_tags(plan: ContractPlan) -> Array[StringName]:
	var tags: Array[StringName] = []
	for supply in plan.selected_supplies:
		for tag: StringName in supply.tags:
			_append_unique(tags, tag)
	return tags


static func _adjust_score_reasons(
	base_reasons: Array[ReasonEntry],
	phase: StringName,
	check_id: StringName,
	check_type: StringName,
	preparation_modifier: int,
	approach_modifier: int,
	attitude_modifier: float,
	attitudes: Array[AttitudeResult],
	plan: ContractPlan
) -> Array[ReasonEntry]:
	var reasons: Array[ReasonEntry] = []
	for reason: ReasonEntry in base_reasons:
		if reason.code != &"score_rounding":
			reasons.append(reason.duplicate_value())
	if preparation_modifier != 0:
		for supply in plan.selected_supplies:
			for modifier in supply.modifiers:
				if modifier.target_type == &"check" \
					and modifier.match_tag == check_type \
					and modifier.amount != 0:
					reasons.append(_reason(
						modifier.reason_code,
						&"preparation",
						supply.id,
						check_id,
						modifier.amount,
						phase,
						ReasonEntry.VISIBILITY_PLAYER
					))
	if approach_modifier != 0:
		reasons.append(_reason(
			&"approach_modifier",
			&"approach",
			plan.approach,
			check_id,
			approach_modifier,
			phase,
			ReasonEntry.VISIBILITY_PLAYER
		))
	if absf(attitude_modifier) > 0.000001:
		for attitude: AttitudeResult in attitudes:
			var member_amount: float = 0.0
			match attitude.status:
				&"enthusiastic":
					member_amount = 0.5
				&"reluctant":
					member_amount = -0.75
				&"opposed":
					member_amount = -1.5
			if absf(member_amount) > 0.000001:
				reasons.append(_reason(
					&"member_attitude_modifier",
					&"attitude",
					attitude.member_id,
					check_id,
					member_amount,
					phase,
					ReasonEntry.VISIBILITY_PLAYER
				))
	return reasons


static func _validate_modifiers(modifiers: Array[MissionModifier]) -> PackedStringArray:
	var errors := PackedStringArray()
	for modifier: MissionModifier in modifiers:
		if modifier == null:
			errors.append("MissionModifier cannot be null.")
			continue
		if not MissionModifier.CONDITION_TYPES.has(modifier.condition_type):
			errors.append("Unknown MissionModifier condition: %s." % modifier.condition_type)
		elif modifier.condition_type == &"context_gte" \
			or modifier.condition_type == &"context_lte":
			if not MissionContext.CONTEXT_KEYS.has(modifier.operand):
				errors.append("Unknown MissionContext key: %s." % modifier.operand)
			if modifier.threshold < 0 or modifier.threshold > 10:
				errors.append("MissionContext modifier threshold must be between 0 and 10.")
		elif modifier.condition_type == &"previous_check_tier_gte" \
			or modifier.condition_type == &"previous_check_tier_lte":
			if not CheckOutcomeTable.TIERS.has(modifier.operand):
				errors.append("Unknown previous check tier: %s." % modifier.operand)
		elif modifier.condition_type == &"approach_is" \
			and not ContractPlanValidator.APPROACHES.has(modifier.operand):
			errors.append("Unknown approach modifier operand: %s." % modifier.operand)
		if modifier.maximum_absolute_amount < 0:
			errors.append("MissionModifier maximum_absolute_amount cannot be negative.")
	return errors


static func _validate_outcomes(table: CheckOutcomeTable) -> PackedStringArray:
	var errors := PackedStringArray()
	if table == null:
		errors.append("CheckOutcomeTable is required.")
		return errors
	for tier: StringName in CheckOutcomeTable.TIERS:
		var outcome: CheckOutcomeDefinition = table.get_outcome(tier)
		if outcome == null:
			errors.append("CheckOutcomeTable must define tier %s." % tier)
			continue
		errors.append_array(MissionContextReducer.validate_deltas(outcome.context_deltas))
		if outcome.ideology_impact == null:
			errors.append("Check outcome ideology_impact is required.")
		for effect: MemberEffect in outcome.member_effects:
			if effect == null:
				errors.append("Check outcome MemberEffect cannot be null.")
			elif effect.type != &"injury_risk" and effect.type != &"fatigue":
				errors.append("Unknown check MemberEffect type: %s." % effect.type)
	return errors


static func _validate_final_outcomes(contract: EffectiveContract) -> PackedStringArray:
	var errors := PackedStringArray()
	if contract.final_outcome_table == null:
		errors.append("ContractOutcomeTable is required.")
		return errors
	var expected_injury: Dictionary[StringName, int] = {
		&"exceptional": -10,
		&"success": -5,
		&"partial": 0,
		&"failure": 10,
		&"severe": 20,
	}
	for tier: StringName in TIERS:
		var outcome: ContractOutcomeDefinition = contract.final_outcome_table.get_outcome(tier)
		if outcome == null:
			errors.append("ContractOutcomeTable must define tier %s." % tier)
		elif outcome.injury_risk_modifier != expected_injury[tier]:
			errors.append(
				"ContractOutcome %s injury_risk_modifier must be %d."
				% [tier, expected_injury[tier]]
			)
	return errors


static func _reason(
	code: StringName,
	category: StringName,
	source_id: StringName,
	target_id: StringName,
	amount: float,
	phase: StringName,
	visibility: StringName
) -> ReasonEntry:
	return ReasonEntry.create(
		code,
		category,
		source_id,
		target_id,
		amount,
		&"",
		{},
		phase,
		visibility
	)


static func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not values.has(value):
		values.append(value)


static func _tier_rank(tier: StringName) -> int:
	return TIERS.find(tier)
