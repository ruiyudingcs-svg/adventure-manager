extends RefCounted

const Task015Fixtures = preload("res://tests/fixtures/task015_fixtures.gd")
const PlanContractCommand = preload(
	"res://game/domain/contracts/plan_contract_command.gd"
)
const DeclineContractOfferCommand = preload(
	"res://game/domain/contracts/decline_contract_offer_command.gd"
)
const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const AdventurerState = preload(
	"res://game/domain/adventurers/adventurer_state.gd"
)
const PlanningPresenter = preload(
	"res://game/features/contract_planning/planning_presenter.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_draft_is_transient_and_order_independent(),
		_test_invalid_plans_do_not_commit(),
		_test_unavailable_and_over_budget_are_rejected(),
		_test_accept_is_irreversible(),
		_test_decline_quota_and_placeholder(),
		_test_member_rows_expose_all_capabilities(),
	]


func _test_draft_is_transient_and_order_independent() -> Dictionary:
	var session := Task015Fixtures.create_session()
	var before = session.call("get_campaign_snapshot")
	var draft = Task015Fixtures.valid_draft(before)
	var signature_one: String = draft.content_signature
	var reversed_members: Array[StringName] = draft.selected_member_ids.duplicate()
	reversed_members.reverse()
	draft.selected_member_ids.assign(reversed_members)
	var signature_two: String = draft.content_signature
	draft.toggle_supply(&"supply_rations")
	draft.set_approach(&"aggressive")
	var after = session.call("get_campaign_snapshot")
	var passed: bool = signature_one == signature_two \
		and before.active_plan == null \
		and after.active_plan == null \
		and _offer_signatures(before) == _offer_signatures(after)
	session.free()
	return _result(
		"planning draft is transient and signature ignores click order",
		passed,
		"Draft changed CampaignState or order changed its content signature."
	)


func _test_invalid_plans_do_not_commit() -> Dictionary:
	var session := Task015Fixtures.create_session(150017)
	var state = session.call("get_campaign_snapshot")
	var offer = Task015Fixtures.first_pending_offer(state)
	var members := Task015Fixtures.first_four_members(state)
	var invalid_commands: Array = [
		PlanContractCommand.create(
			offer.instance_id,
			members.slice(0, 3),
			[],
			&"balanced"
		),
		PlanContractCommand.create(
			offer.instance_id,
			[members[0], members[0], members[1], members[2]],
			[],
			&"balanced"
		),
		PlanContractCommand.create(
			offer.instance_id,
			members,
			[&"supply_missing"],
			&"balanced"
		),
	]
	var all_rejected := true
	for command in invalid_commands:
		if session.call("accept_plan", command):
			all_rejected = false
	var after = session.call("get_campaign_snapshot")
	var passed: bool = all_rejected \
		and after.active_plan == null \
		and _offer_signatures(state) == _offer_signatures(after)
	session.free()
	return _result(
		"invalid member and supply plans never commit",
		passed,
		"An invalid plan committed or changed Offer state."
	)


func _test_accept_is_irreversible() -> Dictionary:
	var session := Task015Fixtures.create_session(150018)
	var state = session.call("get_campaign_snapshot")
	var command = Task015Fixtures.valid_command(state)
	var accepted: bool = session.call("accept_plan", command)
	var after = session.call("get_campaign_snapshot")
	var second_offer = null
	for offer in after.pending_contracts:
		if offer.status == &"pending":
			second_offer = offer
			break
	var second_command := PlanContractCommand.create(
		second_offer.instance_id,
		Task015Fixtures.first_four_members(after),
		[],
		&"cautious"
	)
	var second_rejected: bool = not session.call(
		"accept_plan",
		second_command
	)
	var final_state = session.call("get_campaign_snapshot")
	var passed: bool = accepted \
		and second_rejected \
		and final_state.active_plan != null \
		and final_state.active_plan.contract_instance_id \
			== command.contract_offer_id \
		and final_state.active_plan.approach == &"balanced"
	session.free()
	return _result(
		"accepted plan cannot be replaced or edited",
		passed,
		"A second Offer replaced the locked active plan."
	)


func _test_unavailable_and_over_budget_are_rejected() -> Dictionary:
	var session := Task015Fixtures.create_session(150020)
	var catalog = session.call("_catalog")
	var state = session.call("get_campaign_snapshot")
	var offer = Task015Fixtures.first_pending_offer(state)
	var members := Task015Fixtures.first_four_members(state)
	var member_id: StringName = members[0]
	var original = state.adventurers[member_id]
	state.adventurers[member_id] = AdventurerState.create(
		member_id,
		original.get_fatigue(),
		original.get_morale(),
		original.get_injury_severity(),
		original.get_recovery_weeks_remaining(),
		original.get_growth_xp(),
		false,
		original.get_relationship_deltas(),
		original.get_recent_assignment_count(),
		original.get_recent_neglect_count()
	)
	var unavailable = ContractOfferService.accept_offer(
		state,
		PlanContractCommand.create(
			offer.instance_id,
			members,
			[],
			&"balanced"
		),
		session.call("_planning_definitions")
	)
	var contract = catalog.get_contract(offer.definition_id)
	var allowed_supply_id: StringName
	for supply in catalog.get_all_supplies():
		for tag: StringName in supply.tags:
			if contract.allowed_supply_tags.has(tag):
				allowed_supply_id = supply.id
				break
		if not allowed_supply_id.is_empty():
			break
	var affordable_state = session.call("get_campaign_snapshot")
	affordable_state.guild.gold = 0
	var over_budget = ContractOfferService.accept_offer(
		affordable_state,
		PlanContractCommand.create(
			offer.instance_id,
			members,
			[allowed_supply_id],
			&"balanced"
		),
		session.call("_planning_definitions")
	)
	var passed: bool = not unavailable.is_success() \
		and not over_budget.is_success() \
		and state.active_plan == null \
		and affordable_state.active_plan == null
	session.free()
	return _result(
		"unavailable members and over-budget supplies are rejected",
		passed,
		"Official planning validation accepted an unavailable or unaffordable plan."
	)


func _test_decline_quota_and_placeholder() -> Dictionary:
	var session := Task015Fixtures.create_session(150019)
	var before = session.call("get_campaign_snapshot")
	var first = Task015Fixtures.first_pending_offer(before)
	var declined: bool = session.call(
		"decline_offer",
		DeclineContractOfferCommand.create(first.instance_id)
	)
	var middle = session.call("get_campaign_snapshot")
	var second = Task015Fixtures.first_pending_offer(middle)
	var rejected: bool = not session.call(
		"decline_offer",
		DeclineContractOfferCommand.create(second.instance_id)
	)
	var after = session.call("get_campaign_snapshot")
	var declined_count := 0
	var pending_count := 0
	for offer in after.pending_contracts:
		if offer.status == &"declined":
			declined_count += 1
		elif offer.status == &"pending":
			pending_count += 1
	var passed: bool = declined \
		and rejected \
		and after.pending_contracts.size() == 3 \
		and declined_count == 1 \
		and pending_count == 2 \
		and after.declined_offer_week == after.week_index
	session.free()
	return _result(
		"decline is once per week and keeps a disabled slot",
		passed,
		"Decline quota, no-refill behavior, or placeholder state failed."
	)


func _test_member_rows_expose_all_capabilities() -> Dictionary:
	var session := Task015Fixtures.create_session(150021)
	var catalog = session.call("_catalog")
	var state = session.call("get_campaign_snapshot")
	var draft = Task015Fixtures.valid_draft(state)
	var view_data = PlanningPresenter.present(
		state,
		draft,
		catalog.get_all_contracts(),
		catalog.get_all_factions(),
		catalog.get_all_adventurers(),
		catalog.get_all_supplies(),
		catalog.get_all_contract_clauses(),
		null,
		[]
	)
	var definition_index: Dictionary = {}
	for definition in catalog.get_all_adventurers():
		definition_index[definition.id] = definition
	var passed: bool = view_data.members.size() == 8
	for row in view_data.members:
		if not definition_index.has(row.member_id) \
				or row.capabilities.size() != 6:
			passed = false
			continue
		var capabilities = definition_index[row.member_id].base_capabilities
		passed = passed \
			and row.capabilities.get(&"frontline", -1) == capabilities.frontline \
			and row.capabilities.get(&"offense", -1) == capabilities.offense \
			and row.capabilities.get(&"scouting", -1) == capabilities.scouting \
			and row.capabilities.get(&"support", -1) == capabilities.support \
			and row.capabilities.get(&"arcana", -1) == capabilities.arcana \
			and row.capabilities.get(&"discipline", -1) == capabilities.discipline
	session.free()
	return _result(
		"planning member rows expose all six detached capabilities",
		passed,
		"A planning member row omitted or changed a capability value."
	)


func _offer_signatures(state) -> PackedStringArray:
	var signatures := PackedStringArray()
	for offer in state.pending_contracts:
		signatures.append(offer.content_signature())
	signatures.sort()
	return signatures


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
