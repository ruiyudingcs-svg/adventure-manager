class_name ClauseEvaluator
extends RefCounted

const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const ResolutionTrace = preload("res://game/domain/contracts/resolution_trace.gd")
const ContractClauseDefinition = preload("res://game/domain/contracts/contract_clause_definition.gd")
const TraceCondition = preload("res://game/domain/contracts/trace_condition.gd")
const ContractEffect = preload("res://game/domain/contracts/contract_effect.gd")
const ClauseResult = preload("res://game/domain/contracts/clause_result.gd")
const MemberOutcome = preload("res://game/domain/contracts/member_outcome.gd")
const MethodTagDefinition = preload("res://game/domain/contracts/method_tag_definition.gd")
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const CheckOutcomeTable = preload("res://game/domain/contracts/check_outcome_table.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

const TIERS: Array[StringName] = [
	&"severe",
	&"failure",
	&"partial",
	&"success",
	&"exceptional",
]


class EvaluationResult extends RefCounted:
	var clause_results: Array[ClauseResult]
	var strictest_cap: StringName
	var errors: PackedStringArray


static func evaluate(
	contract: EffectiveContract,
	plan: ContractPlan,
	trace: ResolutionTrace,
	member_outcomes: Array[MemberOutcome]
) -> EvaluationResult:
	var result := EvaluationResult.new()
	result.errors = validate_definitions(contract)
	if not result.errors.is_empty():
		return result
	var sorted_clauses: Array[ContractClauseDefinition] = []
	for clause: ContractClauseDefinition in contract.clauses:
		sorted_clauses.append(clause)
	sorted_clauses.sort_custom(_clause_precedes)
	for clause: ContractClauseDefinition in sorted_clauses:
		var evidence: Array[StringName] = []
		var satisfied: bool = true
		for condition: TraceCondition in clause.all_conditions:
			var condition_met: bool = _evaluate_condition(
				condition,
				plan,
				trace,
				member_outcomes
			)
			evidence.append(
				StringName("%s:%s" % [
					condition.type,
					"true" if condition_met else "false",
				])
			)
			if not condition_met:
				satisfied = false
		var effects: Array[ContractEffect] = []
		var ideology: IdeologyVector
		var tags: Array[StringName] = []
		var cap: StringName = &""
		if satisfied:
			for effect: ContractEffect in clause.success_effects:
				effects.append(effect.duplicate_value())
			ideology = clause.success_ideology_impact
			tags.append_array(clause.success_tags)
		else:
			for effect: ContractEffect in clause.failure_effects:
				effects.append(effect.duplicate_value())
			ideology = clause.failure_ideology_impact
			tags.append_array(clause.failure_tags)
			if clause.importance == &"mandatory":
				cap = clause.breach_result_cap
		var reasons: Array[ReasonEntry] = [
			ReasonEntry.create(
				&"clause_satisfied" if satisfied else &"clause_breached",
				&"clause",
				clause.id,
				contract.instance_id,
				0,
				&"",
				{"satisfied": satisfied},
				&"clause",
				ReasonEntry.VISIBILITY_PLAYER
			),
		]
		for effect: ContractEffect in effects:
			reasons.append(ReasonEntry.create(
				effect.reason_code if not effect.reason_code.is_empty() else effect.type,
				&"clause_effect",
				clause.id,
				contract.instance_id,
				effect.amount,
				StringName("contract_effect.%s" % effect.type),
				{"tag": effect.tag_value},
				&"clause",
				ReasonEntry.VISIBILITY_PLAYER
			))
		var clause_result: ClauseResult = ClauseResult.create(
			clause.id,
			clause.category,
			clause.importance,
			satisfied,
			evidence,
			reasons,
			effects,
			ideology,
			tags,
			cap
		)
		result.clause_results.append(clause_result)
		if not cap.is_empty() and (
			result.strictest_cap.is_empty()
			or _tier_rank(cap) < _tier_rank(result.strictest_cap)
		):
			result.strictest_cap = cap
	return result


static func validate_definitions(contract: EffectiveContract) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary[StringName, bool] = {}
	var check_ids: Dictionary[StringName, bool] = {}
	for stage in contract.stages:
		if stage != null and stage.check != null:
			check_ids[stage.check.id] = true
	for clause: ContractClauseDefinition in contract.clauses:
		if clause == null:
			errors.append("ContractClauseDefinition cannot be null.")
			continue
		if clause.id.is_empty():
			errors.append("Contract clause ID cannot be empty.")
		elif ids.has(clause.id):
			errors.append("Contract clause IDs must be unique.")
		ids[clause.id] = true
		if not ContractClauseDefinition.CATEGORIES.has(clause.category):
			errors.append("Unknown contract clause category: %s." % clause.category)
		if not ContractClauseDefinition.IMPORTANCES.has(clause.importance):
			errors.append("Unknown contract clause importance: %s." % clause.importance)
		if clause.importance == &"bonus" and (
			not clause.failure_effects.is_empty()
			or not clause.breach_result_cap.is_empty()
			or not clause.failure_tags.is_empty()
			or not _is_zero_vector(clause.failure_ideology_impact)
		):
			errors.append("Bonus clause %s cannot have failure consequences." % clause.id)
		if not clause.breach_result_cap.is_empty() \
			and not CheckOutcomeTable.TIERS.has(clause.breach_result_cap):
			errors.append("Unknown clause breach_result_cap: %s." % clause.breach_result_cap)
		for condition: TraceCondition in clause.all_conditions:
			if condition == null:
				errors.append("TraceCondition cannot be null.")
				continue
			if not TraceCondition.TYPES.has(condition.type):
				errors.append("Unknown TraceCondition type: %s." % condition.type)
			elif (condition.type == &"context_gte" or condition.type == &"context_lte") \
				and not MissionContext.CONTEXT_KEYS.has(condition.key):
				errors.append("Unknown TraceCondition context key: %s." % condition.key)
			elif (condition.type == &"check_tier_gte" or condition.type == &"check_tier_lte"):
				if not check_ids.has(condition.source_id):
					errors.append("Unknown TraceCondition check source: %s." % condition.source_id)
				if not TIERS.has(condition.tag_value):
					errors.append("Unknown TraceCondition tier: %s." % condition.tag_value)
		for effect: ContractEffect in clause.success_effects + clause.failure_effects:
			if effect == null:
				errors.append("ContractEffect cannot be null.")
			elif not ContractEffect.TYPES.has(effect.type):
				errors.append("Unknown ContractEffect type: %s." % effect.type)
			elif effect.type == &"add_outcome_tag" and effect.tag_value.is_empty():
				errors.append("add_outcome_tag requires tag_value.")
	return errors


static func _evaluate_condition(
	condition: TraceCondition,
	plan: ContractPlan,
	trace: ResolutionTrace,
	member_outcomes: Array[MemberOutcome]
) -> bool:
	var supply_tags: Array[StringName] = []
	for supply in plan.selected_supplies:
		for tag: StringName in supply.tags:
			if not supply_tags.has(tag):
				supply_tags.append(tag)
	match condition.type:
		&"selected_supply_tag_present":
			return supply_tags.has(condition.tag_value)
		&"selected_supply_tag_absent":
			return not supply_tags.has(condition.tag_value)
		&"approach_is":
			return plan.approach == condition.tag_value
		&"method_tag_used":
			return trace.used_method_tags.has(condition.tag_value)
		&"method_tag_not_used":
			return not trace.used_method_tags.has(condition.tag_value)
		&"outcome_tag_present":
			return trace.outcome_tags.has(condition.tag_value)
		&"outcome_tag_absent":
			return not trace.outcome_tags.has(condition.tag_value)
		&"check_tier_gte", &"check_tier_lte":
			var actual: StringName = &""
			for phase_result in trace.phase_results:
				if phase_result.check_result.check_id == condition.source_id:
					actual = phase_result.check_result.result_tier
					break
			if condition.type == &"check_tier_gte":
				return _tier_rank(actual) >= _tier_rank(condition.tag_value)
			return _tier_rank(actual) <= _tier_rank(condition.tag_value)
		&"context_gte":
			return trace.final_context.get_value(condition.key) >= condition.int_value
		&"context_lte":
			return trace.final_context.get_value(condition.key) <= condition.int_value
		&"member_heavy_injury_count_lte":
			var heavy_count: int = 0
			for outcome: MemberOutcome in member_outcomes:
				if outcome.injury_result == &"heavy":
					heavy_count += 1
			return heavy_count <= condition.int_value
	return false


static func _clause_precedes(
	left: ContractClauseDefinition,
	right: ContractClauseDefinition
) -> bool:
	if left.priority != right.priority:
		return left.priority < right.priority
	return String(left.id) < String(right.id)


static func _tier_rank(tier: StringName) -> int:
	return TIERS.find(tier)


static func _is_zero_vector(vector: IdeologyVector) -> bool:
	return vector != null \
		and vector.protect_life == 0 \
		and vector.respect_authority == 0 \
		and vector.seek_knowledge == 0 \
		and vector.pursue_profit == 0 \
		and vector.taboo_tolerance == 0
