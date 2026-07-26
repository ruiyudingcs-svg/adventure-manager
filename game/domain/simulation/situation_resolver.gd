class_name SituationResolver
extends RefCounted

const SituationDefinition = preload(
	"res://game/domain/situations/situation_definition.gd"
)
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const WorldRule = preload("res://game/domain/situations/world_rule.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const EndingDefinition = preload(
	"res://game/domain/situations/ending_definition.gd"
)
const SituationPhaseDefinition = preload(
	"res://game/domain/situations/situation_phase_definition.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const StateOperation = preload("res://game/core/result/state_operation.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const ProblemUrgencyCalculator = preload(
	"res://game/domain/simulation/problem_urgency_calculator.gd"
)
const ProblemUrgencyResult = preload(
	"res://game/domain/situations/problem_urgency_result.gd"
)
const WorldConditionEvaluator = preload(
	"res://game/domain/situations/world_condition_evaluator.gd"
)

const BOUNDARY_WEEK_START: StringName = &"week_start"
const BOUNDARY_WEEK_END: StringName = &"week_end"

const SOURCE_PASSIVE: int = 650
const SOURCE_DEADLINE: int = 675
const SOURCE_TRIGGER: int = 700
const SOURCE_PROBLEM: int = 750
const SOURCE_ENDING: int = 775


class ResolutionResult extends RefCounted:
	var operations: Array[StateOperation]
	var urgency_results: Array[ProblemUrgencyResult]
	var triggered_rule_ids: Array[StringName]
	var activated_problem_ids: Array[StringName]
	var resolved_problem_ids: Array[StringName]
	var escalated_problem_ids: Array[StringName]
	var created_world_event_ids: Array[StringName]
	var selected_ending_id: StringName
	var issues: PackedStringArray

	func is_success() -> bool:
		return issues.is_empty()

	func signature() -> String:
		var operation_parts := PackedStringArray()
		for operation: StateOperation in operations:
			operation_parts.append("%s:%s:%s:%s:%s:%s:%d" % [
				operation.target_kind,
				operation.target_id,
				operation.field_id,
				operation.operation,
				_value_signature(operation.value),
				operation.reason_code,
				operation.source_order,
			])
		var urgency_parts := PackedStringArray()
		for urgency: ProblemUrgencyResult in urgency_results:
			urgency_parts.append(urgency.signature())
		return "%s|%s|%s|%s|%s|%s|%s" % [
			operation_parts,
			urgency_parts,
			triggered_rule_ids,
			activated_problem_ids,
			resolved_problem_ids,
			escalated_problem_ids,
			selected_ending_id,
		]

	func _value_signature(value: Variant) -> String:
		if value is WorldEventState:
			return value.content_signature()
		if value is ContractHistoryEntry:
			return value.content_signature()
		return var_to_str(value)


class WorldSnapshot extends RefCounted:
	var situation: SituationState
	var world_events: Array[WorldEventState]
	var contract_history: Array[ContractHistoryEntry]

	func _init(
		p_situation: SituationState,
		p_world_events: Array[WorldEventState],
		p_contract_history: Array[ContractHistoryEntry]
	) -> void:
		situation = p_situation.duplicate_state()
		for event: WorldEventState in p_world_events:
			world_events.append(event.duplicate_state())
		for entry: ContractHistoryEntry in p_contract_history:
			contract_history.append(entry.duplicate_state())


class EffectProjection extends RefCounted:
	var operations: Array[StateOperation]
	var create_problem_reasons: Dictionary[StringName, StringName] = {}
	var resolve_problem_reasons: Dictionary[StringName, StringName] = {}
	var ending_candidates: Array[StringName]
	var event_ids: Array[StringName]
	var issues: PackedStringArray


## Compatibility entry point retained for Task008 callers. Week-start work is
## composed from the two public stages so old callers keep one non-recursive
## trigger batch while Task011 may insert Offer lifecycle between the stages.
static func resolve(
	current_week: int,
	definition: SituationDefinition,
	state: SituationState,
	world_events: Array[WorldEventState],
	contract_history: Array[ContractHistoryEntry],
	base_world_operations: Array[StateOperation],
	boundary: StringName
) -> ResolutionResult:
	if boundary != BOUNDARY_WEEK_START:
		return resolve_after_base_operations(
			current_week,
			definition,
			state,
			world_events,
			contract_history,
			base_world_operations,
			boundary
		)
	var prelude := resolve_week_start_prelude(
		current_week,
		definition,
		state,
		world_events,
		contract_history,
		base_world_operations
	)
	if not prelude.is_success():
		return prelude
	var post_base: Array[StateOperation] = []
	post_base.append_array(base_world_operations)
	post_base.append_array(prelude.operations)
	var post := resolve_after_base_operations(
		current_week,
		definition,
		state,
		world_events,
		contract_history,
		post_base,
		boundary
	)
	if not post.is_success():
		return post
	var result := ResolutionResult.new()
	result.operations.append_array(prelude.operations)
	result.operations.append_array(post.operations)
	_copy_resolution_metadata(post, result)
	return result


## Resolves only passive clocks and problem deadlines. Callers may preview these
## operations and run Offer lifecycle before invoking the post-base stage.
static func resolve_week_start_prelude(
	current_week: int,
	definition: SituationDefinition,
	state: SituationState,
	world_events: Array[WorldEventState],
	contract_history: Array[ContractHistoryEntry],
	base_world_operations: Array[StateOperation] = []
) -> ResolutionResult:
	var result := ResolutionResult.new()
	result.issues.append_array(_validate_request(
		current_week,
		definition,
		state,
		base_world_operations,
		BOUNDARY_WEEK_START
	))
	if not result.issues.is_empty():
		return result

	var snapshot := WorldSnapshot.new(state, world_events, contract_history)
	_apply_preview(snapshot, definition, base_world_operations)

	if current_week >= 2:
		var passive_operations: Array[StateOperation] = []
		var passive_index: int = 0
		for effect in definition.passive_weekly_effects:
			if effect.amount != 0:
				passive_operations.append(_numeric_operation(
					CampaignTransaction.TARGET_CLOCK,
					effect.clock_id,
					CampaignTransaction.FIELD_VALUE,
					effect.amount,
					effect.reason_code,
					SOURCE_PASSIVE + passive_index
				))
			passive_index += 1
		result.operations.append_array(passive_operations)
		_apply_preview(snapshot, definition, passive_operations)

	_resolve_deadlines(current_week, definition, snapshot, result)
	if not result.issues.is_empty():
		result.operations.clear()
	return result


## Resolves one locked trigger batch, problem transitions, ending and urgency
## after callers have supplied all earlier base operations for preview.
static func resolve_after_base_operations(
	current_week: int,
	definition: SituationDefinition,
	state: SituationState,
	world_events: Array[WorldEventState],
	contract_history: Array[ContractHistoryEntry],
	base_world_operations: Array[StateOperation],
	boundary: StringName
) -> ResolutionResult:
	var result := ResolutionResult.new()
	result.issues.append_array(_validate_request(
		current_week,
		definition,
		state,
		base_world_operations,
		boundary
	))
	if not result.issues.is_empty():
		return result
	var snapshot := WorldSnapshot.new(state, world_events, contract_history)
	_apply_preview(snapshot, definition, base_world_operations)

	var eligible_triggers: Array[WorldRule] = []
	for rule: WorldRule in definition.trigger_rules:
		if rule.once and snapshot.situation.triggered_rule_ids.has(rule.id):
			continue
		if WorldConditionEvaluator.rule_matches(
			rule,
			current_week,
			snapshot.situation,
			snapshot.world_events,
			snapshot.contract_history
		):
			eligible_triggers.append(rule)
	eligible_triggers.sort_custom(_world_rule_less)

	var forced_create: Dictionary[StringName, StringName] = {}
	var forced_resolve: Dictionary[StringName, StringName] = {}
	var ending_candidates: Array[StringName] = []
	var trigger_effect_operations: Array[StateOperation] = []
	for trigger_index: int in range(eligible_triggers.size()):
		var rule: WorldRule = eligible_triggers[trigger_index]
		result.triggered_rule_ids.append(rule.id)
		var trigger_source: int = SOURCE_TRIGGER + trigger_index
		var projection: EffectProjection = _project_effects(
			rule.effects,
			rule.id,
			&"",
			current_week,
			snapshot,
			trigger_source
		)
		result.issues.append_array(projection.issues)
		trigger_effect_operations.append_array(projection.operations)
		_merge_reason_map(forced_create, projection.create_problem_reasons)
		_merge_reason_map(forced_resolve, projection.resolve_problem_reasons)
		for ending_id: StringName in projection.ending_candidates:
			if not ending_candidates.has(ending_id):
				ending_candidates.append(ending_id)
		result.created_world_event_ids.append_array(projection.event_ids)
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_SITUATION,
			state.definition_id,
			CampaignTransaction.FIELD_TRIGGERED_RULE_IDS,
			StateOperation.OP_ADD_UNIQUE,
			rule.id,
			&"situation_triggered",
			trigger_source
		))
	result.operations.append_array(trigger_effect_operations)
	_apply_preview(snapshot, definition, trigger_effect_operations)
	_apply_preview(
		snapshot,
		definition,
		_filter_trigger_marker_operations(result.operations)
	)

	if not result.issues.is_empty():
		result.operations.clear()
		return result

	_resolve_problem_transitions(
		current_week,
		definition,
		snapshot,
		forced_create,
		forced_resolve,
		result
	)

	var selected_ending: EndingDefinition = _select_ending(
		current_week,
		definition,
		snapshot,
		ending_candidates
	)
	if selected_ending != null and snapshot.situation.ending_id.is_empty():
		result.selected_ending_id = selected_ending.id
		_coalesce_new_activations_for_terminal_boundary(state, snapshot, result)
		var ending_operations: Array[StateOperation] = [
			StateOperation.create(
				CampaignTransaction.TARGET_SITUATION,
				state.definition_id,
				CampaignTransaction.FIELD_ENDING_ID,
				StateOperation.OP_SET_ID,
				selected_ending.id,
				&"situation_ending_selected",
				SOURCE_ENDING
			),
			StateOperation.create(
				CampaignTransaction.TARGET_SITUATION,
				state.definition_id,
				CampaignTransaction.FIELD_PHASE_ID,
				StateOperation.OP_SET_ID,
				_terminal_phase_id(definition),
				&"situation_entered_terminal_phase",
				SOURCE_ENDING + 1
			),
		]
		for problem_id: StringName in _sorted_problem_ids(snapshot.situation):
			var problem: WorldProblemState = snapshot.situation.problems[problem_id]
			if problem.status != WorldProblemState.STATUS_ACTIVE:
				continue
			ending_operations.append_array(_problem_transition_operations(
				problem,
				WorldProblemState.STATUS_CLOSED,
				current_week,
				&"problem_closed_by_ending",
				&"",
				SOURCE_ENDING + 2
			))
		result.operations.append_array(ending_operations)
		_apply_preview(snapshot, definition, ending_operations)

	for problem_id: StringName in _sorted_problem_ids(snapshot.situation):
		var problem: WorldProblemState = snapshot.situation.problems[problem_id]
		if problem.status != WorldProblemState.STATUS_ACTIVE:
			continue
		var problem_definition: WorldProblemDefinition = _problem_definition(
			definition,
			problem_id
		)
		var urgency := ProblemUrgencyCalculator.calculate(
			current_week,
			problem_definition,
			problem,
			snapshot.situation,
			snapshot.world_events,
			snapshot.contract_history
		)
		if urgency != null:
			result.urgency_results.append(urgency)
	return result


static func _copy_resolution_metadata(
	source: ResolutionResult,
	target: ResolutionResult
) -> void:
	target.urgency_results = source.urgency_results
	target.triggered_rule_ids = source.triggered_rule_ids
	target.activated_problem_ids = source.activated_problem_ids
	target.resolved_problem_ids = source.resolved_problem_ids
	target.escalated_problem_ids = source.escalated_problem_ids
	target.created_world_event_ids = source.created_world_event_ids
	target.selected_ending_id = source.selected_ending_id
	target.issues = source.issues


static func _validate_request(
	current_week: int,
	definition: SituationDefinition,
	state: SituationState,
	base_world_operations: Array[StateOperation],
	boundary: StringName
) -> PackedStringArray:
	var errors := PackedStringArray()
	if current_week < 1:
		errors.append("SituationResolver current_week must be at least 1.")
	if definition == null or state == null:
		errors.append("SituationResolver requires definition and state.")
		return errors
	if definition.id != state.definition_id:
		errors.append("Situation definition and state IDs must match.")
	if boundary != BOUNDARY_WEEK_START and boundary != BOUNDARY_WEEK_END:
		errors.append("Unknown situation boundary: %s." % boundary)
	errors.append_array(state.validate())
	for clock_definition in definition.clock_definitions:
		if not state.clock_values.has(clock_definition.id):
			errors.append("SituationState is missing clock %s." % clock_definition.id)
	for problem_definition in definition.problem_definitions:
		if not state.problems.has(problem_definition.id):
			errors.append("SituationState is missing problem %s." % problem_definition.id)
	var declared_clock_ids: Array[StringName] = []
	for clock_definition in definition.clock_definitions:
		declared_clock_ids.append(clock_definition.id)
	for clock_id: StringName in state.clock_values:
		if not declared_clock_ids.has(clock_id):
			errors.append("SituationState has undeclared clock %s." % clock_id)
	var declared_problem_ids: Array[StringName] = []
	for problem_definition in definition.problem_definitions:
		declared_problem_ids.append(problem_definition.id)
	for problem_id: StringName in state.problems:
		if not declared_problem_ids.has(problem_id):
			errors.append("SituationState has undeclared problem %s." % problem_id)
	for operation: StateOperation in base_world_operations:
		if operation == null:
			errors.append("Base world operations cannot contain null.")
			continue
		if not [
			CampaignTransaction.TARGET_CLOCK,
			CampaignTransaction.TARGET_SITUATION,
			CampaignTransaction.TARGET_PROBLEM,
			CampaignTransaction.TARGET_CAMPAIGN,
		].has(operation.target_kind):
			errors.append("SituationResolver received non-world target %s." % operation.target_kind)
		if operation.target_kind == CampaignTransaction.TARGET_CAMPAIGN \
			and not [
				CampaignTransaction.FIELD_WORLD_EVENTS,
				CampaignTransaction.FIELD_CONTRACT_HISTORY,
			].has(operation.field_id):
			errors.append("SituationResolver received non-world campaign field.")
	return errors


static func _resolve_deadlines(
	current_week: int,
	definition: SituationDefinition,
	snapshot: WorldSnapshot,
	result: ResolutionResult
) -> void:
	var expired_ids: Array[StringName] = []
	for problem_id: StringName in _sorted_problem_ids(snapshot.situation):
		var problem: WorldProblemState = snapshot.situation.problems[problem_id]
		if problem.status == WorldProblemState.STATUS_ACTIVE \
			and problem.response_deadline_week >= 0 \
			and current_week > problem.response_deadline_week:
			expired_ids.append(problem_id)

	var deadline_operations: Array[StateOperation] = []
	for problem_index: int in range(expired_ids.size()):
		var problem_id: StringName = expired_ids[problem_index]
		var problem: WorldProblemState = snapshot.situation.problems[problem_id]
		var problem_definition: WorldProblemDefinition = _problem_definition(
			definition,
			problem_id
		)
		var source_order: int = SOURCE_DEADLINE + problem_index
		deadline_operations.append_array(_problem_transition_operations(
			problem,
			WorldProblemState.STATUS_ESCALATED,
			current_week,
			&"problem_escalated",
			&"",
			source_order
		))
		var projection: EffectProjection = _project_effects(
			problem_definition.escalation_effects,
			problem_id,
			problem_id,
			current_week,
			snapshot,
			source_order
		)
		result.issues.append_array(projection.issues)
		deadline_operations.append_array(projection.operations)
		result.created_world_event_ids.append_array(projection.event_ids)
		result.escalated_problem_ids.append(problem_id)
	result.operations.append_array(deadline_operations)
	_apply_preview(snapshot, definition, deadline_operations)


static func _resolve_problem_transitions(
	current_week: int,
	definition: SituationDefinition,
	snapshot: WorldSnapshot,
	forced_create: Dictionary[StringName, StringName],
	forced_resolve: Dictionary[StringName, StringName],
	result: ResolutionResult
) -> void:
	var transition_operations: Array[StateOperation] = []
	var initial_statuses: Dictionary[StringName, StringName] = {}
	for problem_id: StringName in _sorted_problem_ids(snapshot.situation):
		initial_statuses[problem_id] = snapshot.situation.problems[problem_id].status

	for problem_id: StringName in _sorted_problem_ids(snapshot.situation):
		var problem: WorldProblemState = snapshot.situation.problems[problem_id]
		var problem_definition: WorldProblemDefinition = _problem_definition(
			definition,
			problem_id
		)
		if initial_statuses[problem_id] == WorldProblemState.STATUS_INACTIVE:
			var activation_rule: WorldRule = _first_matching_rule(
				problem_definition.activation_rules,
				current_week,
				snapshot
			)
			if forced_create.has(problem_id) or activation_rule != null:
				var reason_code: StringName = forced_create.get(
					problem_id,
					activation_rule.id if activation_rule != null else &"problem_activated"
				)
				var source_event_id: StringName = (
					WorldConditionEvaluator.first_matching_event_instance_id(
						activation_rule,
						snapshot.world_events
					)
					if activation_rule != null
					else &""
				)
				transition_operations.append_array(_problem_activation_operations(
					problem,
					problem_definition,
					current_week,
					reason_code,
					source_event_id
				))
				result.activated_problem_ids.append(problem_id)
		elif initial_statuses[problem_id] == WorldProblemState.STATUS_ACTIVE:
			var resolution_rule: WorldRule = _first_matching_rule(
				problem_definition.resolution_rules,
				current_week,
				snapshot
			)
			if forced_resolve.has(problem_id) or resolution_rule != null:
				var reason_code: StringName = forced_resolve.get(
					problem_id,
					resolution_rule.id if resolution_rule != null else &"problem_resolved"
				)
				transition_operations.append_array(_problem_transition_operations(
					problem,
					WorldProblemState.STATUS_RESOLVED,
					current_week,
					reason_code,
					&"",
					SOURCE_PROBLEM
				))
				result.resolved_problem_ids.append(problem_id)
	result.operations.append_array(transition_operations)
	_apply_preview(snapshot, definition, transition_operations)


static func _problem_activation_operations(
	problem: WorldProblemState,
	definition: WorldProblemDefinition,
	current_week: int,
	reason_code: StringName,
	source_event_id: StringName
) -> Array[StateOperation]:
	var operations: Array[StateOperation] = [
		StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem.definition_id,
			CampaignTransaction.FIELD_STATUS,
			StateOperation.OP_SET_ID,
			WorldProblemState.STATUS_ACTIVE,
			reason_code,
			SOURCE_PROBLEM
		),
		_numeric_operation(
			CampaignTransaction.TARGET_PROBLEM,
			problem.definition_id,
			CampaignTransaction.FIELD_OPENED_WEEK,
			current_week - problem.opened_week,
			reason_code,
			SOURCE_PROBLEM
		),
	]
	if definition.response_window_weeks >= 1:
		var deadline: int = current_week + definition.response_window_weeks - 1
		operations.append(_numeric_operation(
			CampaignTransaction.TARGET_PROBLEM,
			problem.definition_id,
			CampaignTransaction.FIELD_RESPONSE_DEADLINE_WEEK,
			deadline - problem.response_deadline_week,
			reason_code,
			SOURCE_PROBLEM
		))
	if not source_event_id.is_empty():
		operations.append(StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem.definition_id,
			CampaignTransaction.FIELD_SOURCE_EVENT_ID,
			StateOperation.OP_SET_ID,
			source_event_id,
			reason_code,
			SOURCE_PROBLEM
		))
	return operations


static func _problem_transition_operations(
	problem: WorldProblemState,
	status: StringName,
	current_week: int,
	reason_code: StringName,
	source_event_id: StringName,
	source_order: int
) -> Array[StateOperation]:
	var operations: Array[StateOperation] = [
		StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem.definition_id,
			CampaignTransaction.FIELD_STATUS,
			StateOperation.OP_SET_ID,
			status,
			reason_code,
			source_order
		),
		_numeric_operation(
			CampaignTransaction.TARGET_PROBLEM,
			problem.definition_id,
			CampaignTransaction.FIELD_CLOSED_WEEK,
			current_week - problem.closed_week,
			reason_code,
			source_order
		),
		StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem.definition_id,
			CampaignTransaction.FIELD_RESOLUTION_REASON_CODE,
			StateOperation.OP_SET_ID,
			reason_code,
			reason_code,
			source_order
		),
	]
	if not source_event_id.is_empty():
		operations.append(StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem.definition_id,
			CampaignTransaction.FIELD_SOURCE_EVENT_ID,
			StateOperation.OP_SET_ID,
			source_event_id,
			reason_code,
			source_order
		))
	return operations


static func _project_effects(
	effects: Array[WorldEffect],
	source_id: StringName,
	related_problem_id: StringName,
	current_week: int,
	snapshot: WorldSnapshot,
	source_order: int
) -> EffectProjection:
	var result := EffectProjection.new()
	var event_reasons: Dictionary[StringName, Array] = {}
	for effect: WorldEffect in effects:
		match effect.type:
			&"modify_clock":
				result.operations.append(_numeric_operation(
					CampaignTransaction.TARGET_CLOCK,
					effect.target_id,
					CampaignTransaction.FIELD_VALUE,
					effect.amount,
					effect.reason_code,
					source_order
				))
			&"change_phase":
				result.operations.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					snapshot.situation.definition_id,
					CampaignTransaction.FIELD_PHASE_ID,
					StateOperation.OP_SET_ID,
					effect.target_id,
					effect.reason_code,
					source_order
				))
			&"unlock_contract":
				result.operations.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					snapshot.situation.definition_id,
					CampaignTransaction.FIELD_UNLOCKED_CONTRACT_IDS,
					StateOperation.OP_ADD_UNIQUE,
					effect.target_id,
					effect.reason_code,
					source_order
				))
			&"set_ending":
				if not result.ending_candidates.has(effect.target_id):
					result.ending_candidates.append(effect.target_id)
			&"create_problem":
				result.create_problem_reasons[effect.target_id] = effect.reason_code
			&"resolve_problem":
				result.resolve_problem_reasons[effect.target_id] = effect.reason_code
			&"create_world_event":
				if not event_reasons.has(effect.target_id):
					event_reasons[effect.target_id] = []
				event_reasons[effect.target_id].append(effect.reason_code)
			&"add_message":
				result.issues.append(
					"add_message projection belongs to Task012 and is unavailable in Task008."
				)
			_:
				result.issues.append("Unsupported situation effect: %s." % effect.type)

	var event_keys: Array[StringName] = []
	event_keys.assign(event_reasons.keys())
	event_keys.sort()
	for event_key: StringName in event_keys:
		var reasons: Array[StringName] = []
		reasons.assign(event_reasons[event_key])
		reasons.sort()
		var event_id := StringName("%s_%s" % [source_id, event_key])
		var event := WorldEventState.create(
			event_id,
			event_key,
			current_week,
			source_id,
			related_problem_id,
			reasons
		)
		if event == null:
			result.issues.append("Could not create situation event %s." % event_key)
			continue
		result.event_ids.append(event_id)
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_WORLD_EVENTS,
			StateOperation.OP_APPEND_RECORD,
			event,
			reasons[0],
			source_order
		))
	return result


static func _select_ending(
	current_week: int,
	definition: SituationDefinition,
	snapshot: WorldSnapshot,
	forced_candidates: Array[StringName]
) -> EndingDefinition:
	if not snapshot.situation.ending_id.is_empty():
		return null
	var candidates: Array[EndingDefinition] = []
	for ending: EndingDefinition in definition.ending_definitions:
		if forced_candidates.has(ending.id) or _conditions_match(
			ending.all_conditions,
			ending.any_conditions,
			current_week,
			snapshot
		):
			candidates.append(ending)
	candidates.sort_custom(_ending_less)
	return candidates[0] if not candidates.is_empty() else null


static func _conditions_match(
	all_conditions: Array,
	any_conditions: Array,
	current_week: int,
	snapshot: WorldSnapshot
) -> bool:
	for condition in all_conditions:
		if not WorldConditionEvaluator.is_met(
			condition,
			current_week,
			snapshot.situation,
			snapshot.world_events,
			snapshot.contract_history
		):
			return false
	if any_conditions.is_empty():
		return true
	for condition in any_conditions:
		if WorldConditionEvaluator.is_met(
			condition,
			current_week,
			snapshot.situation,
			snapshot.world_events,
			snapshot.contract_history
		):
			return true
	return false


static func _first_matching_rule(
	rules: Array[WorldRule],
	current_week: int,
	snapshot: WorldSnapshot
) -> WorldRule:
	var matching: Array[WorldRule] = []
	for rule: WorldRule in rules:
		if WorldConditionEvaluator.rule_matches(
			rule,
			current_week,
			snapshot.situation,
			snapshot.world_events,
			snapshot.contract_history
		):
			matching.append(rule)
	matching.sort_custom(_world_rule_less)
	return matching[0] if not matching.is_empty() else null


static func _apply_preview(
	snapshot: WorldSnapshot,
	definition: SituationDefinition,
	operations: Array[StateOperation]
) -> void:
	var ordered: Array[StateOperation] = []
	for operation: StateOperation in operations:
		if operation != null:
			ordered.append(operation.duplicate_value())
	ordered.sort_custom(_operation_less)
	var numeric_totals: Dictionary[String, int] = {}
	for operation: StateOperation in ordered:
		if operation.operation == StateOperation.OP_ADD_INT:
			var key: String = _operation_field_key(operation)
			numeric_totals[key] = numeric_totals.get(key, 0) + int(operation.value)
	var applied_numeric: Dictionary[String, bool] = {}
	for operation: StateOperation in ordered:
		var key: String = _operation_field_key(operation)
		if operation.operation == StateOperation.OP_ADD_INT:
			if applied_numeric.has(key):
				continue
			applied_numeric[key] = true
			_apply_preview_numeric(
				snapshot,
				definition,
				operation,
				numeric_totals[key]
			)
		elif operation.operation == StateOperation.OP_SET_ID:
			_apply_preview_set(snapshot, operation)
		elif operation.operation == StateOperation.OP_ADD_UNIQUE:
			_apply_preview_add_unique(snapshot, operation)
		elif operation.operation == StateOperation.OP_REMOVE_UNIQUE:
			_apply_preview_remove_unique(snapshot, operation)
		elif operation.operation == StateOperation.OP_APPEND_RECORD:
			_apply_preview_record(snapshot, operation)


static func _apply_preview_numeric(
	snapshot: WorldSnapshot,
	definition: SituationDefinition,
	operation: StateOperation,
	delta: int
) -> void:
	if operation.target_kind == CampaignTransaction.TARGET_CLOCK \
		and snapshot.situation.clock_values.has(operation.target_id):
		var bounds: Vector2i = _clock_bounds(definition, operation.target_id)
		snapshot.situation.clock_values[operation.target_id] = clampi(
			snapshot.situation.clock_values[operation.target_id] + delta,
			bounds.x,
			bounds.y
		)
	elif operation.target_kind == CampaignTransaction.TARGET_PROBLEM \
		and snapshot.situation.problems.has(operation.target_id):
		var problem: WorldProblemState = snapshot.situation.problems[operation.target_id]
		match operation.field_id:
			CampaignTransaction.FIELD_OPENED_WEEK:
				problem.opened_week += delta
			CampaignTransaction.FIELD_RESPONSE_DEADLINE_WEEK:
				problem.response_deadline_week += delta
			CampaignTransaction.FIELD_CLOSED_WEEK:
				problem.closed_week += delta


static func _apply_preview_set(
	snapshot: WorldSnapshot,
	operation: StateOperation
) -> void:
	if operation.target_kind == CampaignTransaction.TARGET_SITUATION:
		match operation.field_id:
			CampaignTransaction.FIELD_PHASE_ID:
				snapshot.situation.phase_id = StringName(operation.value)
			CampaignTransaction.FIELD_ENDING_ID:
				snapshot.situation.ending_id = StringName(operation.value)
	elif operation.target_kind == CampaignTransaction.TARGET_PROBLEM \
		and snapshot.situation.problems.has(operation.target_id):
		var problem: WorldProblemState = snapshot.situation.problems[operation.target_id]
		match operation.field_id:
			CampaignTransaction.FIELD_STATUS:
				problem.status = StringName(operation.value)
			CampaignTransaction.FIELD_SOURCE_EVENT_ID:
				problem.source_event_id = StringName(operation.value)
			CampaignTransaction.FIELD_RESOLUTION_REASON_CODE:
				problem.resolution_reason_code = StringName(operation.value)


static func _apply_preview_add_unique(
	snapshot: WorldSnapshot,
	operation: StateOperation
) -> void:
	if operation.target_kind != CampaignTransaction.TARGET_SITUATION:
		return
	var values: Array[StringName] = (
		snapshot.situation.triggered_rule_ids
		if operation.field_id == CampaignTransaction.FIELD_TRIGGERED_RULE_IDS
		else snapshot.situation.unlocked_contract_ids
	)
	var value := StringName(operation.value)
	if not values.has(value):
		values.append(value)
		values.sort_custom(_stable_id_less)


static func _apply_preview_remove_unique(
	snapshot: WorldSnapshot,
	operation: StateOperation
) -> void:
	if operation.target_kind != CampaignTransaction.TARGET_SITUATION:
		return
	var values: Array[StringName] = (
		snapshot.situation.triggered_rule_ids
		if operation.field_id == CampaignTransaction.FIELD_TRIGGERED_RULE_IDS
		else snapshot.situation.unlocked_contract_ids
	)
	values.erase(StringName(operation.value))


static func _apply_preview_record(
	snapshot: WorldSnapshot,
	operation: StateOperation
) -> void:
	if operation.field_id == CampaignTransaction.FIELD_WORLD_EVENTS \
		and operation.value is WorldEventState:
		var event: WorldEventState = operation.value
		for existing: WorldEventState in snapshot.world_events:
			if existing.instance_id == event.instance_id:
				return
		snapshot.world_events.append(event.duplicate_state())
	elif operation.field_id == CampaignTransaction.FIELD_CONTRACT_HISTORY \
		and operation.value is ContractHistoryEntry:
		var entry: ContractHistoryEntry = operation.value
		for existing: ContractHistoryEntry in snapshot.contract_history:
			if existing.contract_instance_id == entry.contract_instance_id:
				return
		snapshot.contract_history.append(entry.duplicate_state())


static func _filter_trigger_marker_operations(
	operations: Array[StateOperation]
) -> Array[StateOperation]:
	var markers: Array[StateOperation] = []
	for operation: StateOperation in operations:
		if operation.target_kind == CampaignTransaction.TARGET_SITUATION \
			and operation.field_id == CampaignTransaction.FIELD_TRIGGERED_RULE_IDS:
			markers.append(operation)
	return markers


static func _coalesce_new_activations_for_terminal_boundary(
	base_state: SituationState,
	snapshot: WorldSnapshot,
	result: ResolutionResult
) -> void:
	var newly_active: Dictionary[StringName, bool] = {}
	for problem_id: StringName in result.activated_problem_ids:
		if base_state.problems[problem_id].status == WorldProblemState.STATUS_INACTIVE \
			and snapshot.situation.problems[problem_id].status \
				== WorldProblemState.STATUS_ACTIVE:
			newly_active[problem_id] = true
	if newly_active.is_empty():
		return
	# The transaction forbids contradictory set_id writes. Preserve the locked
	# activation weeks, but let the ending's closed status be the sole status
	# write when a problem opens and closes on the same boundary.
	var kept_operations: Array[StateOperation] = []
	for operation: StateOperation in result.operations:
		if operation.target_kind == CampaignTransaction.TARGET_PROBLEM \
			and newly_active.has(operation.target_id) \
			and operation.field_id == CampaignTransaction.FIELD_STATUS \
			and operation.value == WorldProblemState.STATUS_ACTIVE:
			continue
		kept_operations.append(operation)
	result.operations = kept_operations


static func _problem_definition(
	definition: SituationDefinition,
	problem_id: StringName
) -> WorldProblemDefinition:
	for problem: WorldProblemDefinition in definition.problem_definitions:
		if problem.id == problem_id:
			return problem
	return null


static func _terminal_phase_id(definition: SituationDefinition) -> StringName:
	for phase: SituationPhaseDefinition in definition.phase_definitions:
		if phase.is_terminal:
			return phase.id
	return &""


static func _clock_bounds(
	definition: SituationDefinition,
	clock_id: StringName
) -> Vector2i:
	for clock in definition.clock_definitions:
		if clock.id == clock_id:
			return Vector2i(clock.min_value, clock.max_value)
	return Vector2i(0, 100)


static func _sorted_problem_ids(state: SituationState) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(state.problems.keys())
	ids.sort_custom(_stable_id_less)
	return ids


static func _stable_id_less(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)


static func _numeric_operation(
	target_kind: StringName,
	target_id: StringName,
	field_id: StringName,
	value: int,
	reason_code: StringName,
	source_order: int
) -> StateOperation:
	return StateOperation.create(
		target_kind,
		target_id,
		field_id,
		StateOperation.OP_ADD_INT,
		value,
		reason_code,
		source_order
	)


static func _merge_reason_map(
	target: Dictionary[StringName, StringName],
	source: Dictionary[StringName, StringName]
) -> void:
	for key: StringName in source:
		if not target.has(key):
			target[key] = source[key]


static func _world_rule_less(left: WorldRule, right: WorldRule) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	return String(left.id) < String(right.id)


static func _ending_less(left: EndingDefinition, right: EndingDefinition) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	return String(left.id) < String(right.id)


static func _operation_less(left: StateOperation, right: StateOperation) -> bool:
	var left_key: String = "%s|%s|%s|%s|%s|%010d|%s" % [
		left.target_kind,
		left.target_id,
		left.field_id,
		left.operation,
		_preview_value_key(left.value),
		left.source_order,
		left.reason_code,
	]
	var right_key: String = "%s|%s|%s|%s|%s|%010d|%s" % [
		right.target_kind,
		right.target_id,
		right.field_id,
		right.operation,
		_preview_value_key(right.value),
		right.source_order,
		right.reason_code,
	]
	return left_key < right_key


static func _preview_value_key(value: Variant) -> String:
	if value is WorldEventState:
		return value.content_signature()
	if value is ContractHistoryEntry:
		return value.content_signature()
	return var_to_str(value)


static func _operation_field_key(operation: StateOperation) -> String:
	return "%s|%s|%s" % [
		operation.target_kind,
		operation.target_id,
		operation.field_id,
	]
