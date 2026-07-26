## Builds Dashboard ViewData from detached state and detached definitions.
class_name DashboardPresenter
extends RefCounted

const DashboardViewData = preload(
	"res://game/features/dashboard/dashboard_view_data.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const FactionActionCommitmentState = preload(
	"res://game/domain/factions/faction_action_commitment_state.gd"
)
const ProblemUrgencyCalculator = preload(
	"res://game/domain/simulation/problem_urgency_calculator.gd"
)
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")


static func present(
	state,
	situation_definition,
	contract_definitions: Array,
	faction_definitions: Array,
	action_definitions: Array,
	problem_definitions: Array
) -> DashboardViewData:
	if state == null or situation_definition == null:
		return null
	var view_data := DashboardViewData.new()
	view_data.week_index = state.week_index
	view_data.gold = state.guild.gold
	view_data.reputation = state.guild.reputation
	view_data.base_cohesion = state.guild.base_cohesion
	view_data.situation_name_key = situation_definition.display_name_key
	view_data.phase_name_key = _phase_key(
		situation_definition,
		state.situation.phase_id
	)

	var contracts := _index_by_id(contract_definitions)
	var factions := _index_by_id(faction_definitions)
	var problems := _index_by_id(problem_definitions)
	for clock in situation_definition.clock_definitions:
		if clock == null or not state.situation.clock_values.has(clock.id):
			continue
		var item := DashboardViewData.ClockItem.new()
		item.id = clock.id
		item.label_key = clock.display_name_key
		item.value = state.situation.clock_values[clock.id]
		item.maximum = clock.max_value
		view_data.clocks.append(item)

	for offer in state.pending_contracts:
		if offer == null or not contracts.has(offer.definition_id):
			continue
		var item := DashboardViewData.OfferItem.new()
		item.instance_id = offer.instance_id
		item.faction_name_key = (
			factions[offer.sponsor_faction_id].display_name_key
			if factions.has(offer.sponsor_faction_id) else &""
		)
		item.title_key = contracts[offer.definition_id].title_key
		item.reward = offer.offered_reward
		item.remaining_turns = offer.remaining_turns(state.week_index)
		item.status = offer.status
		view_data.offers.append(item)
	view_data.offers.sort_custom(func(left, right) -> bool:
		if left.faction_name_key != right.faction_name_key:
			return String(left.faction_name_key) < String(right.faction_name_key)
		return String(left.instance_id) < String(right.instance_id)
	)

	var problem_ids: Array[StringName] = []
	problem_ids.assign(state.situation.problems.keys())
	problem_ids.sort()
	for problem_id: StringName in problem_ids:
		var problem_state = state.situation.problems[problem_id]
		if problem_state.status != &"active" or not problems.has(problem_id):
			continue
		var urgency = ProblemUrgencyCalculator.calculate(
			state.week_index,
			problems[problem_id],
			problem_state,
			state.situation,
			state.world_events,
			state.contract_history
		)
		if urgency == null:
			continue
		var item := DashboardViewData.ProblemItem.new()
		item.id = problem_id
		item.title_key = problems[problem_id].title_key
		item.band = urgency.band
		item.remaining_turns = urgency.remaining_turns
		item.player_reason_keys = _player_reason_keys(urgency.reason_entries)
		view_data.problems.append(item)

	for message in state.message_history:
		var item := DashboardViewData.MessageItem.new()
		item.instance_id = message.instance_id
		item.week_index = message.week_index
		item.title_key = message.title_key
		item.body_key = message.body_key
		item.importance = message.importance
		item.is_read = message.is_read
		item.sort_order = message.sort_order
		item.parameters = message.parameters
		view_data.messages.append(item)
	view_data.messages.sort_custom(_message_less)

	for commitment in state.faction_action_commitments:
		if commitment == null \
				or commitment.status \
					!= FactionActionCommitmentState.STATUS_COMMITTED:
			continue
		var item := DashboardViewData.ActionItem.new()
		item.instance_id = commitment.instance_id
		item.faction_name_key = (
			factions[commitment.faction_id].display_name_key
			if factions.has(commitment.faction_id) else &""
		)
		item.action_title_key = StringName(
			"action.%s.title" % commitment.action_definition_id
		)
		item.problem_title_key = (
			problems[commitment.target_problem_id].title_key
			if problems.has(commitment.target_problem_id) else &""
		)
		item.player_reason_keys = _player_reason_keys(
			commitment.commitment_reason_entries
		)
		view_data.committed_actions.append(item)
	view_data.committed_actions.sort_custom(func(left, right) -> bool:
		if left.faction_name_key != right.faction_name_key:
			return String(left.faction_name_key) < String(right.faction_name_key)
		return String(left.instance_id) < String(right.instance_id)
	)

	for member_id: StringName in state.adventurers:
		var member = state.adventurers[member_id]
		if not member.get_is_available():
			view_data.alert_keys.append(&"alert.member_unavailable")
		elif member.get_injury_severity() > 0:
			view_data.alert_keys.append(&"alert.member_injured")
	var unread := 0
	for message in state.message_history:
		if not message.is_read:
			unread += 1
	if unread > 0:
		view_data.alert_keys.append(&"alert.unread_messages")
	return view_data


static func _index_by_id(definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions:
		if definition != null:
			result[definition.id] = definition
	return result


static func _phase_key(situation_definition, phase_id: StringName) -> StringName:
	for phase in situation_definition.phase_definitions:
		if phase != null and phase.id == phase_id:
			return phase.display_name_key
	return &""


static func _player_reason_keys(reasons: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for reason in reasons:
		if reason != null \
				and reason.visibility == ReasonEntry.VISIBILITY_PLAYER \
				and not result.has(reason.localization_key):
			result.append(reason.localization_key)
		if result.size() == 2:
			break
	return result


static func _message_less(left, right) -> bool:
	if left.week_index != right.week_index:
		return left.week_index > right.week_index
	if left.sort_order != right.sort_order:
		return left.sort_order < right.sort_order
	if left.instance_id == right.instance_id:
		return false
	return String(left.instance_id) < String(right.instance_id)
