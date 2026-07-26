class_name ResolutionPresenter
extends RefCounted

const ResolutionViewData = preload(
	"res://game/features/resolution/resolution_view_data.gd"
)


## Projects only the cached WeekResolution payload; final CampaignState is not
## consulted to reverse-engineer any old/new delta.
static func present(
	review: Dictionary,
	contracts: Array,
	factions: Array,
	adventurers: Array,
	clauses: Array,
	actions: Array
) -> ResolutionViewData:
	if review.is_empty():
		return null
	var view_data := ResolutionViewData.new()
	view_data.resolved_week = int(review.get("resolved_week", 0))
	view_data.next_week = int(review.get("next_week", 0))
	view_data.ending_id = review.get("ending_id", &"")
	var contract_index := _index_by_id(contracts)
	var faction_index := _index_by_id(factions)
	var adventurer_index := _index_by_id(adventurers)
	var clause_index := _index_by_id(clauses)
	var action_index := _index_by_id(actions)
	var contract: Dictionary = review.get("contract", {})
	view_data.skipped_contract = contract.is_empty()
	if not contract.is_empty():
		var definition_id: StringName = contract.get("definition_id", &"")
		var sponsor_id: StringName = contract.get("sponsor_faction_id", &"")
		if contract_index.has(definition_id):
			view_data.contract_title_key = contract_index[definition_id].title_key
		if faction_index.has(sponsor_id):
			view_data.sponsor_name_key = faction_index[sponsor_id].display_name_key
		view_data.final_tier = contract.get("result_tier", &"")
		view_data.reward = int(contract.get("reward", 0))
		view_data.supply_cost_total = int(
			contract.get("supply_cost_total", 0)
		)
		view_data.sponsor_relation_delta = int(
			contract.get("sponsor_relation_delta", 0)
		)
		for phase_value: Dictionary in contract.get("phases", []):
			var row := ResolutionViewData.PhaseRow.new()
			row.phase = phase_value.get("phase", &"")
			row.check_type = phase_value.get("check_type", &"")
			row.score = int(phase_value.get("score", 0))
			row.result_tier = phase_value.get("result_tier", &"")
			for reason: Dictionary in phase_value.get("reasons", []):
				row.reason_keys.append(_reason_key(reason))
			view_data.phases.append(row)
		for clause_value: Dictionary in contract.get("clauses", []):
			var row := ResolutionViewData.ClauseRow.new()
			row.clause_id = clause_value.get("clause_id", &"")
			if clause_index.has(row.clause_id):
				row.title_key = clause_index[row.clause_id].display_name_key
			row.importance = clause_value.get("importance", &"")
			row.satisfied = bool(clause_value.get("satisfied", false))
			row.evidence.assign(clause_value.get("evidence", []))
			view_data.clauses.append(row)
		for member_value: Dictionary in contract.get("members", []):
			var row := ResolutionViewData.MemberRow.new()
			row.member_id = member_value.get("member_id", &"")
			if adventurer_index.has(row.member_id):
				row.display_name = adventurer_index[row.member_id].display_name
			row.fatigue_delta = int(member_value.get("fatigue_delta", 0))
			row.injury_result = member_value.get("injury_result", &"")
			row.injury_severity_after = int(
				member_value.get("injury_severity_after", 0)
			)
			row.recovery_weeks_after = int(
				member_value.get("recovery_weeks_after", 0)
			)
			row.available_after = bool(
				member_value.get("is_available_after", true)
			)
			row.morale_delta = int(member_value.get("morale_delta", 0))
			view_data.members.append(row)

	for change_value: Dictionary in review.get("state_changes", []):
		var row := ResolutionViewData.ChangeRow.new()
		row.target_id = change_value.get("target_id", &"")
		row.field_path = str(change_value.get("field_path", ""))
		row.old_value = _duplicate_variant(change_value.get("old_value"))
		row.new_value = _duplicate_variant(change_value.get("new_value"))
		row.reason_codes.assign(change_value.get("reason_codes", []))
		view_data.changes.append(row)
	for reason_value: Dictionary in review.get("reasons", []):
		var row := ResolutionViewData.ReasonRow.new()
		row.code = reason_value.get("code", &"")
		row.localization_key = reason_value.get("localization_key", &"")
		row.target_id = reason_value.get("target_id", &"")
		row.amount = float(reason_value.get("amount", 0.0))
		row.phase = reason_value.get("phase", &"")
		view_data.reasons.append(row)
	for action_value: Dictionary in review.get("faction_actions", []):
		var action_id: StringName = action_value.get(
			"action_definition_id",
			&""
		)
		if action_index.has(action_id):
			view_data.faction_action_titles.append(
				StringName("action.%s.title" % action_id)
			)
	return view_data


static func _index_by_id(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		if value != null:
			result[value.id] = value
	return result


static func _reason_key(reason: Dictionary) -> StringName:
	var localization_key: StringName = reason.get("localization_key", &"")
	return localization_key if not localization_key.is_empty() \
		else reason.get("code", &"")


static func _duplicate_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return value
