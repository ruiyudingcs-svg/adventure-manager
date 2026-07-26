class_name ProblemUrgencyCalculator
extends RefCounted

const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const ProblemUrgencyRule = preload(
	"res://game/domain/situations/problem_urgency_rule.gd"
)
const ProblemUrgencyResult = preload(
	"res://game/domain/situations/problem_urgency_result.gd"
)
const WorldConditionEvaluator = preload(
	"res://game/domain/situations/world_condition_evaluator.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)


## Derives urgency without retaining or mutating campaign state.
static func calculate(
	current_week: int,
	definition: WorldProblemDefinition,
	problem_state: WorldProblemState,
	situation_state: SituationState,
	world_events: Array[WorldEventState] = [],
	contract_history: Array[ContractHistoryEntry] = []
) -> ProblemUrgencyResult:
	if (
		current_week < 0
		or definition == null
		or problem_state == null
		or situation_state == null
		or definition.id != problem_state.definition_id
		or problem_state.opened_week < 0
		or current_week < problem_state.opened_week
	):
		return null

	var reasons: Array[ReasonEntry] = []
	var raw_score: int = definition.base_urgency
	_append_reason(
		reasons,
		&"problem_urgency_base",
		definition.id,
		definition.id,
		definition.base_urgency,
		{},
		&"player"
	)

	var matching_clock_rules: Array[ProblemUrgencyRule] = []
	var matching_phase_rules: Array[ProblemUrgencyRule] = []
	for rule: ProblemUrgencyRule in definition.urgency_rules:
		if not _urgency_rule_matches(
			rule,
			current_week,
			situation_state,
			world_events,
			contract_history
		):
			continue
		if _is_phase_rule(rule):
			matching_phase_rules.append(rule)
		else:
			matching_clock_rules.append(rule)
	matching_clock_rules.sort_custom(_rule_less)
	matching_phase_rules.sort_custom(_rule_less)
	for rule: ProblemUrgencyRule in matching_clock_rules:
		raw_score += rule.urgency_delta
		_append_rule_reason(reasons, rule, definition.id)

	var age_weeks: int = current_week - problem_state.opened_week
	var age_pressure: int = mini(
		age_weeks * definition.age_urgency_per_week,
		definition.age_urgency_cap
	)
	raw_score += age_pressure
	_append_reason(
		reasons,
		&"problem_urgency_age",
		definition.id,
		definition.id,
		age_pressure,
		{"age_weeks": age_weeks},
		&"player"
	)

	var remaining_turns: int = -1
	var deadline_pressure: int = 0
	if problem_state.response_deadline_week >= 0:
		remaining_turns = problem_state.response_deadline_week - current_week + 1
		if remaining_turns == 2:
			deadline_pressure = 10
		elif remaining_turns == 1:
			deadline_pressure = 25
	raw_score += deadline_pressure
	_append_reason(
		reasons,
		&"problem_urgency_deadline",
		definition.id,
		definition.id,
		deadline_pressure,
		{"remaining_turns": remaining_turns},
		&"player"
	)

	for rule: ProblemUrgencyRule in matching_phase_rules:
		raw_score += rule.urgency_delta
		_append_rule_reason(reasons, rule, definition.id)

	var score: int = clampi(raw_score, 0, 100)
	return ProblemUrgencyResult.create(
		definition.id,
		current_week,
		score,
		_band_for_score(score),
		remaining_turns,
		reasons
	)


static func _urgency_rule_matches(
	rule: ProblemUrgencyRule,
	current_week: int,
	state: SituationState,
	world_events: Array[WorldEventState],
	contract_history: Array[ContractHistoryEntry]
) -> bool:
	if rule == null:
		return false
	for condition in rule.all_conditions:
		if not WorldConditionEvaluator.is_met(
			condition,
			current_week,
			state,
			world_events,
			contract_history
		):
			return false
	return true


static func _is_phase_rule(rule: ProblemUrgencyRule) -> bool:
	for condition in rule.all_conditions:
		if condition.type == &"phase_is":
			return true
	return false


static func _rule_less(left: ProblemUrgencyRule, right: ProblemUrgencyRule) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	return String(left.id) < String(right.id)


static func _append_rule_reason(
	reasons: Array[ReasonEntry],
	rule: ProblemUrgencyRule,
	problem_id: StringName
) -> void:
	_append_reason(
		reasons,
		rule.reason_code,
		rule.id,
		problem_id,
		rule.urgency_delta,
		{},
		rule.visibility
	)


static func _append_reason(
	reasons: Array[ReasonEntry],
	code: StringName,
	source_id: StringName,
	target_id: StringName,
	amount: int,
	parameters: Dictionary,
	visibility: StringName
) -> void:
	if amount == 0:
		return
	var reason := ReasonEntry.create(
		code,
		&"world_problem_urgency",
		source_id,
		target_id,
		float(amount),
		StringName("reason.%s" % code),
		parameters,
		&"situation",
		visibility
	)
	if reason != null:
		reasons.append(reason)


static func _band_for_score(score: int) -> StringName:
	if score <= 19:
		return ProblemUrgencyResult.BAND_LOW
	if score <= 39:
		return ProblemUrgencyResult.BAND_GUARDED
	if score <= 59:
		return ProblemUrgencyResult.BAND_HIGH
	if score <= 79:
		return ProblemUrgencyResult.BAND_SEVERE
	return ProblemUrgencyResult.BAND_CRITICAL
