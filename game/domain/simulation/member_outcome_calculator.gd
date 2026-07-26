class_name MemberOutcomeCalculator
extends RefCounted

const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const ResolutionTrace = preload("res://game/domain/contracts/resolution_trace.gd")
const ContractOutcomeDefinition = preload("res://game/domain/contracts/contract_outcome_definition.gd")
const ClauseResult = preload("res://game/domain/contracts/clause_result.gd")
const MemberOutcome = preload("res://game/domain/contracts/member_outcome.gd")
const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const MethodTagDefinition = preload("res://game/domain/contracts/method_tag_definition.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const StableSeed = preload("res://game/core/random/stable_seed.gd")


static func calculate_injuries(
	contract: EffectiveContract,
	plan: ContractPlan,
	trace: ResolutionTrace,
	operational_outcome: ContractOutcomeDefinition,
	contract_seed: int
) -> Array[MemberOutcome]:
	var outcomes: Array[MemberOutcome] = []
	var protection: int = _protection_reduction(plan)
	var supply_any: int = _supply_modifier(plan, &"injury_any")
	var supply_heavy: int = _supply_modifier(plan, &"injury_heavy")
	var approach_multiplier: float = (
		0.70 if plan.approach == &"cautious" else (
			1.30 if plan.approach == &"aggressive" else 1.0
		)
	)
	var sorted_members: Array[AdventurerSnapshot] = []
	for member: AdventurerSnapshot in plan.members:
		sorted_members.append(member)
	sorted_members.sort_custom(func(left: AdventurerSnapshot, right: AdventurerSnapshot) -> bool:
		return String(left.id) < String(right.id)
	)
	for member: AdventurerSnapshot in sorted_members:
		var check_risk: int = _check_injury_risk(trace, member.id)
		var fatigue_risk: int = fatigue_risk_for(member.fatigue)
		var common_risk: int = contract.risk_level * 5 \
			+ check_risk \
			+ operational_outcome.injury_risk_modifier \
			+ fatigue_risk \
			- protection
		var any_chance: int = clampi(common_risk + supply_any, 0, 100)
		var heavy_base: int = clampi(roundi(common_risk * 0.40) + supply_heavy, 0, 100)
		var heavy_chance: int = mini(
			any_chance,
			clampi(roundi(heavy_base * approach_multiplier), 0, 100)
		)
		var fragments: Array[StringName] = [&"injury", member.id]
		var injury_seed: int = StableSeed.derive(contract_seed, fragments)
		var rng: RandomNumberGenerator = StableSeed.create_rng(contract_seed, fragments)
		var roll: int = rng.randi_range(1, 100)
		var injury_result: StringName = &"none"
		var severity_after: int = member.injury_severity
		var recovery_after: int = member.recovery_weeks_remaining
		var available_after: bool = member.is_available
		if roll <= heavy_chance:
			injury_result = &"heavy"
			severity_after = mini(100, maxi(80, member.injury_severity + 40))
			recovery_after = maxi(member.recovery_weeks_remaining, 3)
			available_after = false
		elif roll <= any_chance:
			injury_result = &"light"
			severity_after = mini(79, maxi(30, member.injury_severity + 20))
			recovery_after = maxi(member.recovery_weeks_remaining, 1)
		var reasons: Array[ReasonEntry] = [
			_reason(&"injury_contract_risk", contract.definition_id, member.id, contract.risk_level * 5),
			_reason(&"injury_check_risk", contract.definition_id, member.id, check_risk),
			_reason(&"injury_operational_tier", contract.definition_id, member.id, operational_outcome.injury_risk_modifier),
			_reason(&"injury_current_fatigue", contract.definition_id, member.id, fatigue_risk),
			_reason(&"injury_team_protection", contract.definition_id, member.id, -protection),
			_reason(&"injury_supply_any", contract.definition_id, member.id, supply_any),
			_reason(&"injury_supply_heavy", contract.definition_id, member.id, supply_heavy),
			_reason(&"injury_any_chance", contract.definition_id, member.id, any_chance),
			_reason(&"injury_heavy_base", contract.definition_id, member.id, heavy_base),
			_reason(&"injury_approach_multiplier", plan.approach, member.id, approach_multiplier),
			_reason(&"injury_heavy_chance", contract.definition_id, member.id, heavy_chance),
			_reason(&"injury_seed", contract.definition_id, member.id, injury_seed),
			_reason(&"injury_roll", contract.definition_id, member.id, roll),
			_reason(&"injury_result", injury_result, member.id, 0),
		]
		outcomes.append(MemberOutcome.create(
			member.id,
			0,
			injury_result,
			injury_seed,
			roll,
			any_chance,
			heavy_chance,
			severity_after,
			recovery_after,
			available_after,
			0,
			0.0,
			reasons
		))
	return outcomes


static func finalize(
	contract: EffectiveContract,
	plan: ContractPlan,
	trace: ResolutionTrace,
	injury_outcomes: Array[MemberOutcome],
	clause_results: Array[ClauseResult],
	final_outcome: ContractOutcomeDefinition
) -> Array[MemberOutcome]:
	var result: Array[MemberOutcome] = []
	var actual_ideology: IdeologyVector = _actual_ideology(trace, clause_results)
	var actual_method: IdeologyVector = _actual_method(
		trace.used_method_tags,
		contract.method_tag_definitions
	)
	var approach_fatigue: int = (
		1 if plan.approach == &"cautious" else (
			3 if plan.approach == &"aggressive" else 0
		)
	)
	var supply_reduction: int = -_supply_modifier(plan, &"fatigue")
	for injury: MemberOutcome in injury_outcomes:
		var member: AdventurerSnapshot = _find_member(plan, injury.member_id)
		var check_fatigue: int = _check_fatigue(trace, member.id)
		var unscaled_fatigue: int = maxi(
			0,
			contract.base_fatigue + approach_fatigue + check_fatigue - supply_reduction
		)
		var fatigue_gain: int = roundi(unscaled_fatigue * final_outcome.fatigue_multiplier)
		var fatigue_delta: int = mini(fatigue_gain, 100 - member.fatigue)
		var evaluation: float = clampf(
			member.values.dot(actual_ideology) / 5.0
			+ member.values.dot(actual_method) / 5.0,
			-40.0,
			40.0
		)
		var requested_morale: int = morale_delta_for(evaluation)
		var morale_after: int = clampi(member.morale + requested_morale, 0, 100)
		var morale_delta: int = morale_after - member.morale
		var reasons: Array[ReasonEntry] = []
		for reason: ReasonEntry in injury.reason_entries:
			reasons.append(reason.duplicate_value())
		reasons.append(_reason(
			&"fatigue_unscaled",
			contract.definition_id,
			member.id,
			unscaled_fatigue
		))
		reasons.append(_reason(
			&"fatigue_final_multiplier",
			contract.definition_id,
			member.id,
			final_outcome.fatigue_multiplier
		))
		reasons.append(_reason(
			&"fatigue_delta",
			contract.definition_id,
			member.id,
			fatigue_delta
		))
		reasons.append(_reason(
			&"post_mission_evaluation",
			contract.definition_id,
			member.id,
			evaluation
		))
		if morale_delta != 0:
			reasons.append(_reason(
				&"morale_delta",
				contract.definition_id,
				member.id,
				morale_delta
			))
		result.append(MemberOutcome.create(
			injury.member_id,
			fatigue_delta,
			injury.injury_result,
			injury.injury_seed,
			injury.injury_roll,
			injury.any_injury_chance,
			injury.heavy_injury_chance,
			injury.injury_severity_after,
			injury.recovery_weeks_after,
			injury.is_available_after,
			morale_delta,
			evaluation,
			reasons
		))
	return result


static func fatigue_risk_for(current_fatigue: int) -> int:
	if current_fatigue >= 80:
		return 12
	if current_fatigue >= 60:
		return 7
	if current_fatigue >= 30:
		return 3
	return 0


static func protection_band(capability: int) -> int:
	if capability >= 80:
		return 3
	if capability >= 60:
		return 2
	if capability >= 40:
		return 1
	return 0


static func morale_delta_for(evaluation: float) -> int:
	if evaluation >= 20.0:
		return 3
	if evaluation >= 5.0:
		return 1
	if evaluation <= -20.0:
		return -3
	if evaluation <= -5.0:
		return -1
	return 0


static func _protection_reduction(plan: ContractPlan) -> int:
	var maximum_frontline: int = 0
	var maximum_support: int = 0
	for member: AdventurerSnapshot in plan.members:
		maximum_frontline = maxi(maximum_frontline, member.capabilities.frontline)
		maximum_support = maxi(maximum_support, member.capabilities.support)
	return protection_band(maximum_frontline) + protection_band(maximum_support)


static func _check_injury_risk(trace: ResolutionTrace, member_id: StringName) -> int:
	var total: int = 0
	for effect in trace.pending_member_effects:
		if effect.type == &"injury_risk" \
			and (effect.target_id.is_empty() or effect.target_id == member_id):
			total += effect.amount
	return total


static func _check_fatigue(trace: ResolutionTrace, member_id: StringName) -> int:
	var total: int = 0
	for effect in trace.pending_member_effects:
		if effect.type == &"fatigue" \
			and (effect.target_id.is_empty() or effect.target_id == member_id):
			total += effect.amount
	return total


static func _supply_modifier(plan: ContractPlan, target_type: StringName) -> int:
	var total: int = 0
	for supply in plan.selected_supplies:
		for modifier in supply.modifiers:
			if modifier.target_type == target_type:
				total += modifier.amount
	return total


static func _actual_ideology(
	trace: ResolutionTrace,
	clause_results: Array[ClauseResult]
) -> IdeologyVector:
	var values: Array[int] = [0, 0, 0, 0, 0]
	for phase_result in trace.phase_results:
		var impact: IdeologyVector = phase_result.check_result.ideology_impact
		values[0] += impact.protect_life
		values[1] += impact.respect_authority
		values[2] += impact.seek_knowledge
		values[3] += impact.pursue_profit
		values[4] += impact.taboo_tolerance
	for clause: ClauseResult in clause_results:
		values[0] += clause.ideology_impact.protect_life
		values[1] += clause.ideology_impact.respect_authority
		values[2] += clause.ideology_impact.seek_knowledge
		values[3] += clause.ideology_impact.pursue_profit
		values[4] += clause.ideology_impact.taboo_tolerance
	return IdeologyVector.create_task_accumulation(
		clampi(values[0], -10, 10),
		clampi(values[1], -10, 10),
		clampi(values[2], -10, 10),
		clampi(values[3], -10, 10),
		clampi(values[4], -10, 10)
	)


static func _actual_method(
	used_tags: Array[StringName],
	definitions: Array[MethodTagDefinition]
) -> IdeologyVector:
	var definition_map: Dictionary[StringName, MethodTagDefinition] = {}
	for definition: MethodTagDefinition in definitions:
		if definition != null:
			definition_map[definition.id] = definition
	var values: Array[int] = [0, 0, 0, 0, 0]
	var visited: Array[StringName] = []
	for tag: StringName in used_tags:
		if visited.has(tag):
			continue
		visited.append(tag)
		var definition: MethodTagDefinition = definition_map.get(tag)
		if definition == null:
			continue
		values[0] += definition.ideology_vector.protect_life
		values[1] += definition.ideology_vector.respect_authority
		values[2] += definition.ideology_vector.seek_knowledge
		values[3] += definition.ideology_vector.pursue_profit
		values[4] += definition.ideology_vector.taboo_tolerance
	return IdeologyVector.create_task_accumulation(
		clampi(values[0], -10, 10),
		clampi(values[1], -10, 10),
		clampi(values[2], -10, 10),
		clampi(values[3], -10, 10),
		clampi(values[4], -10, 10)
	)


static func _find_member(
	plan: ContractPlan,
	member_id: StringName
) -> AdventurerSnapshot:
	for member: AdventurerSnapshot in plan.members:
		if member.id == member_id:
			return member
	return null


static func _reason(
	code: StringName,
	source_id: StringName,
	target_id: StringName,
	amount: float
) -> ReasonEntry:
	return ReasonEntry.create(
		code,
		&"member_outcome",
		source_id,
		target_id,
		amount,
		&"",
		{},
		&"final",
		ReasonEntry.VISIBILITY_DEBUG
	)
