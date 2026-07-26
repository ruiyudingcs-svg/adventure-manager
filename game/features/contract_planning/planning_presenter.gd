class_name PlanningPresenter
extends RefCounted

const AdventurerSnapshot = preload(
	"res://game/domain/adventurers/adventurer_snapshot.gd"
)
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const SupplyDefinition = preload(
	"res://game/domain/contracts/supply_definition.gd"
)
const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const ContractForecastService = preload(
	"res://game/domain/simulation/contract_forecast_service.gd"
)
const PlanningViewData = preload(
	"res://game/features/contract_planning/planning_view_data.gd"
)


static func build_forecast(
	state,
	draft,
	contracts: Array,
	adventurers: Array,
	supplies: Array,
	clauses: Array,
	method_tags: Array
) -> ContractForecastService.ForecastResult:
	if state == null or draft == null or draft.offer_instance_id.is_empty():
		return null
	var offer = _offer_by_id(state.pending_contracts, draft.offer_instance_id)
	var contract = _definition_by_id(contracts, offer.definition_id if offer else &"")
	if offer == null or contract == null:
		return null
	var effective = ContractOfferService.build_effective_contract(
		offer,
		contract,
		clauses,
		method_tags
	)
	var adventurer_index := _index_by_id(adventurers)
	var supply_index := _index_by_id(supplies)
	var member_snapshots: Array[AdventurerSnapshot] = []
	for member_id: StringName in draft.selected_member_ids:
		if (
			not adventurer_index.has(member_id)
			or not state.adventurers.has(member_id)
		):
			return null
		var snapshot := AdventurerSnapshot.create(
			adventurer_index[member_id],
			state.adventurers[member_id]
		)
		if snapshot == null:
			return null
		member_snapshots.append(snapshot)
	var selected_supplies: Array[SupplyDefinition] = []
	for supply_id: StringName in draft.selected_supply_ids:
		if not supply_index.has(supply_id):
			return null
		selected_supplies.append(supply_index[supply_id])
	var plan := ContractPlan.create(
		member_snapshots,
		selected_supplies,
		draft.approach
	)
	return ContractForecastService.forecast(
		ContractForecastService.ForecastRequest.create(
			offer.instance_id,
			draft.content_signature,
			offer.locked_seed,
			effective,
			plan,
			state.guild.base_cohesion
		)
	)


## Produces detached rows only; all rule validation and forecast values arrive
## from official domain services.
static func present(
	state,
	draft,
	contracts: Array,
	factions: Array,
	adventurers: Array,
	supplies: Array,
	clauses: Array,
	forecast,
	validation_issues: PackedStringArray
) -> PlanningViewData:
	var view_data := PlanningViewData.new()
	if state == null or draft == null:
		view_data.validation_issues.append("planning.validation.no_campaign")
		return view_data
	var contract_index := _index_by_id(contracts)
	var faction_index := _index_by_id(factions)
	var adventurer_index := _index_by_id(adventurers)
	var supply_index := _index_by_id(supplies)
	var clause_index := _index_by_id(clauses)
	view_data.plan_locked = state.active_plan != null
	view_data.decline_quota_used = state.declined_offer_week == state.week_index
	view_data.approach = draft.approach
	view_data.selected_member_count = draft.selected_member_ids.size()
	view_data.selected_supply_count = draft.selected_supply_ids.size()
	view_data.plan_signature = draft.content_signature
	view_data.validation_issues = validation_issues.duplicate()

	var offers: Array = state.pending_contracts.duplicate()
	offers.sort_custom(func(left, right) -> bool:
		var left_key := "%s|%s" % [left.sponsor_faction_id, left.instance_id]
		var right_key := "%s|%s" % [right.sponsor_faction_id, right.instance_id]
		return left_key < right_key
	)
	for offer in offers:
		if not contract_index.has(offer.definition_id):
			continue
		var definition = contract_index[offer.definition_id]
		var card := PlanningViewData.OfferCard.new()
		card.offer_instance_id = offer.instance_id
		card.title_key = definition.title_key
		card.sponsor_name_key = (
			faction_index[offer.sponsor_faction_id].display_name_key
			if faction_index.has(offer.sponsor_faction_id) else &""
		)
		card.reward = offer.offered_reward
		card.remaining_turns = offer.remaining_turns(state.week_index)
		card.risk_level = definition.risk_level
		card.origin_type = offer.origin_type
		card.status = offer.status
		card.selected = offer.instance_id == draft.offer_instance_id
		card.is_declined_placeholder = offer.status == &"declined"
		card.can_decline = (
			offer.status == &"pending"
			and not view_data.decline_quota_used
			and not view_data.plan_locked
		)
		for reason in offer.generation_reason_entries:
			if reason.visibility == &"player" and card.reason_keys.size() < 2:
				card.reason_keys.append(
					reason.localization_key
					if not reason.localization_key.is_empty()
					else reason.code
				)
		view_data.offer_cards.append(card)

	var selected_offer = _offer_by_id(
		state.pending_contracts,
		draft.offer_instance_id
	)
	var selected_definition = (
		contract_index.get(selected_offer.definition_id)
		if selected_offer != null else null
	)
	if selected_offer != null and selected_definition != null:
		view_data.selected_offer_id = selected_offer.instance_id
		view_data.selected_title_key = selected_definition.title_key
		view_data.selected_description_key = selected_definition.description_key
		view_data.selected_reward = selected_offer.offered_reward
		view_data.selected_risk_level = selected_definition.risk_level
		for stage in selected_definition.stages:
			var row := PlanningViewData.StageRow.new()
			row.phase = stage.phase
			row.check_type = stage.check.check_type
			view_data.stages.append(row)
		for clause_id: StringName in selected_definition.clause_ids:
			if not clause_index.has(clause_id):
				continue
			var clause = clause_index[clause_id]
			var row := PlanningViewData.ClauseRow.new()
			row.clause_id = clause.id
			row.title_key = clause.display_name_key
			row.description_key = clause.description_key
			row.category = clause.category
			row.importance = clause.importance
			row.forecast_status = (
				forecast.clause_statuses.get(clause.id, &"")
				if forecast != null and forecast.is_success() else &""
			)
			view_data.clauses.append(row)

	for member_id: StringName in state.adventurers:
		if not adventurer_index.has(member_id):
			continue
		var definition = adventurer_index[member_id]
		var member_state = state.adventurers[member_id]
		var row := PlanningViewData.MemberRow.new()
		row.member_id = member_id
		row.display_name = definition.display_name
		row.selected = draft.selected_member_ids.has(member_id)
		row.available = member_state.get_is_available()
		row.fatigue = member_state.get_fatigue()
		row.morale = member_state.get_morale()
		row.injury = member_state.get_injury_severity()
		var capabilities = definition.base_capabilities
		row.capabilities = {
			&"frontline": capabilities.frontline,
			&"offense": capabilities.offense,
			&"scouting": capabilities.scouting,
			&"support": capabilities.support,
			&"arcana": capabilities.arcana,
			&"discipline": capabilities.discipline,
		}
		if forecast != null and forecast.is_success():
			row.attitude_status = forecast.attitude_statuses.get(member_id, &"")
			row.injury_risk_band = forecast.member_injury_bands.get(member_id, &"")
		view_data.members.append(row)
	view_data.members.sort_custom(func(left, right) -> bool:
		return String(left.member_id) < String(right.member_id)
	)

	for supply_id: StringName in supply_index:
		var definition = supply_index[supply_id]
		var row := PlanningViewData.SupplyRow.new()
		row.supply_id = supply_id
		row.display_name_key = definition.display_name_key
		row.cost = definition.cost
		row.selected = draft.selected_supply_ids.has(supply_id)
		row.allowed = (
			selected_definition != null
			and _supply_is_allowed(definition, selected_definition.allowed_supply_tags)
		)
		view_data.supplies.append(row)
	view_data.supplies.sort_custom(func(left, right) -> bool:
		return String(left.supply_id) < String(right.supply_id)
	)

	if forecast != null and forecast.is_success():
		view_data.likely_tier_low = forecast.likely_tier_low
		view_data.likely_tier_high = forecast.likely_tier_high
		view_data.supply_cost_total = forecast.supply_cost_total
		for reason in forecast.warning_reasons:
			view_data.warning_keys.append(
				reason.localization_key
				if not reason.localization_key.is_empty() else reason.code
			)
	view_data.can_accept = (
		not view_data.plan_locked
		and selected_offer != null
		and selected_offer.status == &"pending"
		and validation_issues.is_empty()
		and forecast != null
		and forecast.is_success()
	)
	return view_data


static func _index_by_id(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		if value != null:
			result[value.id] = value
	return result


static func _definition_by_id(values: Array, definition_id: StringName):
	for value in values:
		if value != null and value.id == definition_id:
			return value
	return null


static func _offer_by_id(values: Array, offer_id: StringName):
	for value in values:
		if value != null and value.instance_id == offer_id:
			return value
	return null


static func _supply_is_allowed(supply, allowed_tags: Array[StringName]) -> bool:
	for tag: StringName in supply.tags:
		if allowed_tags.has(tag):
			return true
	return false
