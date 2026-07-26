class_name Task015Fixtures
extends RefCounted

const GameSessionScript = preload("res://game/app/game_session.gd")
const CampaignBootstrapFixtures = preload(
	"res://tests/fixtures/campaign_bootstrap_fixtures.gd"
)
const PlanContractCommand = preload(
	"res://game/domain/contracts/plan_contract_command.gd"
)
const PlanningDraft = preload(
	"res://game/features/contract_planning/planning_draft.gd"
)


static func create_session(seed: int = 150015) -> Node:
	var session: Node = GameSessionScript.new()
	session.call(
		"set_catalog_for_testing",
		CampaignBootstrapFixtures.create_catalog()
	)
	assert(session.call(
		"start_new_campaign",
		CampaignBootstrapFixtures.SETUP_ID,
		seed
	))
	return session


static func first_pending_offer(state):
	var offers: Array = []
	for offer in state.pending_contracts:
		if offer.status == &"pending":
			offers.append(offer)
	offers.sort_custom(func(left, right) -> bool:
		return String(left.instance_id) < String(right.instance_id)
	)
	return offers[0] if not offers.is_empty() else null


static func first_four_members(state) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(state.adventurers.keys())
	ids.sort()
	ids.resize(4)
	return ids


static func valid_command(state) -> PlanContractCommand:
	var offer = first_pending_offer(state)
	return PlanContractCommand.create(
		offer.instance_id,
		first_four_members(state),
		[],
		&"balanced"
	)


static func valid_draft(state) -> PlanningDraft:
	var draft := PlanningDraft.new()
	var offer = first_pending_offer(state)
	draft.select_offer(offer.instance_id)
	for member_id: StringName in first_four_members(state):
		draft.toggle_member(member_id)
	return draft

