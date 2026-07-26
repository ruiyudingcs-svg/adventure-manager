## Projects only committed state and history; it never evaluates ending rules.
class_name EndingPresenter
extends RefCounted

const EndingViewData = preload(
	"res://game/features/ending/ending_view_data.gd"
)
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)

const MAX_EVENTS: int = 8
const MAX_REASONS: int = 8


static func present(
	state,
	situation_definition,
	ending_definitions: Array,
	problem_definitions: Array,
	contract_definitions: Array,
	faction_definitions: Array,
	adventurer_definitions: Array
) -> EndingViewData:
	if state == null \
			or situation_definition == null \
			or state.situation == null \
			or state.situation.ending_id.is_empty():
		return null
	var endings := _index_by_id(ending_definitions)
	var ending_id: StringName = state.situation.ending_id
	if not endings.has(ending_id):
		return null

	var view_data := EndingViewData.new()
	var ending = endings[ending_id]
	view_data.ending_id = ending_id
	view_data.title_key = ending.display_name_key
	view_data.description_key = ending.description_key
	view_data.ending_week = state.week_index
	_project_clocks(view_data, state, situation_definition)
	_project_events(view_data, state)
	_project_problems(view_data, state, problem_definitions)
	_project_contracts(view_data, state, contract_definitions)
	_project_factions(view_data, state, faction_definitions)
	_project_members(view_data, state, adventurer_definitions)
	_project_reasons(view_data, state)
	return view_data


static func _project_clocks(
	view_data: EndingViewData,
	state,
	situation_definition
) -> void:
	for definition in situation_definition.clock_definitions:
		if definition == null \
				or not state.situation.clock_values.has(definition.id):
			continue
		var row := EndingViewData.ClockRow.new()
		row.id = definition.id
		row.label_key = definition.display_name_key
		row.value = state.situation.clock_values[definition.id]
		view_data.clocks.append(row)


static func _project_events(view_data: EndingViewData, state) -> void:
	var events: Array = []
	for event in state.world_events:
		if event != null and event.visibility == WorldEventState.VISIBILITY_PLAYER:
			events.append(event)
	events.sort_custom(func(left, right) -> bool:
		if left.week_index != right.week_index:
			return left.week_index < right.week_index
		return String(left.instance_id) < String(right.instance_id)
	)
	var start: int = maxi(0, events.size() - MAX_EVENTS)
	for index: int in range(start, events.size()):
		var row := EndingViewData.EventRow.new()
		row.event_key = events[index].event_key
		row.week_index = events[index].week_index
		view_data.events.append(row)


static func _project_problems(
	view_data: EndingViewData,
	state,
	problem_definitions: Array
) -> void:
	var definitions := _index_by_id(problem_definitions)
	var problem_ids: Array[StringName] = []
	problem_ids.assign(state.situation.problems.keys())
	problem_ids.sort()
	for problem_id: StringName in problem_ids:
		var problem = state.situation.problems[problem_id]
		if problem == null \
				or problem.status == &"inactive" \
				or not definitions.has(problem_id):
			continue
		var row := EndingViewData.ProblemRow.new()
		row.title_key = definitions[problem_id].title_key
		row.status = problem.status
		row.closed_week = problem.closed_week
		view_data.problems.append(row)


static func _project_contracts(
	view_data: EndingViewData,
	state,
	contract_definitions: Array
) -> void:
	var definitions := _index_by_id(contract_definitions)
	var history: Array = state.contract_history.duplicate()
	history.sort_custom(func(left, right) -> bool:
		if left.week_index != right.week_index:
			return left.week_index < right.week_index
		return String(left.contract_instance_id) \
			< String(right.contract_instance_id)
	)
	for entry in history:
		if entry == null or not definitions.has(entry.contract_definition_id):
			continue
		var row := EndingViewData.ContractRow.new()
		row.title_key = definitions[entry.contract_definition_id].title_key
		row.terminal_status = entry.terminal_status
		row.result_tier = entry.result_tier
		row.reward = entry.reward_received
		row.week_index = entry.week_index
		view_data.contracts.append(row)


static func _project_factions(
	view_data: EndingViewData,
	state,
	faction_definitions: Array
) -> void:
	var definitions := _index_by_id(faction_definitions)
	var faction_ids: Array[StringName] = []
	faction_ids.assign(state.factions.keys())
	faction_ids.sort()
	for faction_id: StringName in faction_ids:
		if not definitions.has(faction_id):
			continue
		var row := EndingViewData.FactionRow.new()
		row.name_key = definitions[faction_id].display_name_key
		row.relation = state.factions[faction_id].relation
		view_data.factions.append(row)


static func _project_members(
	view_data: EndingViewData,
	state,
	adventurer_definitions: Array
) -> void:
	var definitions := _index_by_id(adventurer_definitions)
	var member_ids: Array[StringName] = []
	member_ids.assign(state.adventurers.keys())
	member_ids.sort()
	for member_id: StringName in member_ids:
		if not definitions.has(member_id):
			continue
		var member = state.adventurers[member_id]
		var row := EndingViewData.MemberRow.new()
		row.display_name = definitions[member_id].display_name
		row.fatigue = member.get_fatigue()
		row.injury_severity = member.get_injury_severity()
		row.recovery_weeks = member.get_recovery_weeks_remaining()
		row.morale = member.get_morale()
		view_data.members.append(row)


static func _project_reasons(view_data: EndingViewData, state) -> void:
	var history: Array = state.contract_history.duplicate()
	history.reverse()
	for entry in history:
		if entry == null:
			continue
		for reason in entry.generation_reason_entries:
			if reason != null and reason.visibility == ReasonEntry.VISIBILITY_PLAYER:
				_append_reason(
					view_data.reason_keys,
					reason.localization_key
					if not reason.localization_key.is_empty()
					else reason.code
				)
		_append_reason(view_data.reason_keys, entry.terminal_reason_code)
		if view_data.reason_keys.size() == MAX_REASONS:
			return
	var events: Array = state.world_events.duplicate()
	events.reverse()
	for event in events:
		if event == null or event.visibility != WorldEventState.VISIBILITY_PLAYER:
			continue
		for reason_code: StringName in event.effect_reason_codes:
			_append_reason(view_data.reason_keys, reason_code)
			if view_data.reason_keys.size() == MAX_REASONS:
				return


static func _append_reason(
	reasons: Array[StringName],
	reason_key: StringName
) -> void:
	if reason_key.is_empty() or reasons.has(reason_key) \
			or reasons.size() >= MAX_REASONS:
		return
	reasons.append(reason_key)


static func _index_by_id(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		if value != null:
			result[value.id] = value
	return result
