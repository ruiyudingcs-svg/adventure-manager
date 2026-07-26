class_name WorldConditionEvaluator
extends RefCounted

const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldCondition = preload(
	"res://game/domain/situations/world_condition.gd"
)
const WorldRule = preload("res://game/domain/situations/world_rule.gd")
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)


## Evaluates one structured world predicate against a detached world snapshot.
static func is_met(
	condition: WorldCondition,
	current_week: int,
	state: SituationState,
	world_events: Array[WorldEventState],
	contract_history: Array[ContractHistoryEntry]
) -> bool:
	if condition == null or state == null:
		return false
	match condition.type:
		&"clock_gte":
			return state.clock_values.has(condition.target_id) \
				and state.clock_values[condition.target_id] >= condition.int_value
		&"clock_lte":
			return state.clock_values.has(condition.target_id) \
				and state.clock_values[condition.target_id] <= condition.int_value
		&"phase_is":
			return state.phase_id == condition.target_id
		&"week_gte":
			return current_week >= condition.int_value
		&"contract_completed":
			for entry: ContractHistoryEntry in contract_history:
				if entry.contract_definition_id == condition.target_id \
					and (
						entry.terminal_status == &"resolved"
						or entry.terminal_status == &"npc_completed"
					):
					return true
			return false
		&"problem_is_active":
			return state.problems.has(condition.target_id) \
				and state.problems[condition.target_id].status \
					== WorldProblemState.STATUS_ACTIVE
		&"problem_is_resolved":
			return state.problems.has(condition.target_id) \
				and state.problems[condition.target_id].status \
					== WorldProblemState.STATUS_RESOLVED
		&"world_event_occurred":
			return _event_occurred(condition.target_id, world_events)
		&"world_event_not_occurred":
			return not _event_occurred(condition.target_id, world_events)
	return false


static func rule_matches(
	rule: WorldRule,
	current_week: int,
	state: SituationState,
	world_events: Array[WorldEventState],
	contract_history: Array[ContractHistoryEntry]
) -> bool:
	if rule == null:
		return false
	for condition: WorldCondition in rule.all_conditions:
		if not is_met(condition, current_week, state, world_events, contract_history):
			return false
	if rule.any_conditions.is_empty():
		return true
	for condition: WorldCondition in rule.any_conditions:
		if is_met(condition, current_week, state, world_events, contract_history):
			return true
	return false


static func first_matching_event_instance_id(
	rule: WorldRule,
	world_events: Array[WorldEventState]
) -> StringName:
	var event_keys: Array[StringName] = []
	for condition: WorldCondition in rule.all_conditions:
		if condition.type == &"world_event_occurred":
			event_keys.append(condition.target_id)
	for condition: WorldCondition in rule.any_conditions:
		if condition.type == &"world_event_occurred":
			event_keys.append(condition.target_id)
	event_keys.sort()
	var matching_ids: Array[StringName] = []
	for event: WorldEventState in world_events:
		if event_keys.has(event.event_key):
			matching_ids.append(event.instance_id)
	matching_ids.sort()
	return matching_ids[0] if not matching_ids.is_empty() else &""


static func _event_occurred(
	event_key: StringName,
	world_events: Array[WorldEventState]
) -> bool:
	for event: WorldEventState in world_events:
		if event.event_key == event_key:
			return true
	return false
