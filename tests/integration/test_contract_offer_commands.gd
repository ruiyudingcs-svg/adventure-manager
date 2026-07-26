extends RefCounted

const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const PlanContractCommand = preload(
	"res://game/domain/contracts/plan_contract_command.gd"
)
const DeclineContractOfferCommand = preload(
	"res://game/domain/contracts/decline_contract_offer_command.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const IdeologyVector = preload(
	"res://game/domain/adventurers/ideology_vector.gd"
)
const CampaignStateFixtures = preload(
	"res://tests/fixtures/campaign_state_fixtures.gd"
)
const ContractOfferFixtures = preload(
	"res://tests/fixtures/contract_offer_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_accept_offer_atomically_test(),
		_invalid_plans_are_pure_test(),
		_decline_quota_and_archive_test(),
	]


func _accept_offer_atomically_test() -> Dictionary:
	var state = CampaignStateFixtures.create_baseline_state()
	var with_offer = _commit_created_offer(state)
	if with_offer == null:
		return _result(
			"valid plan installs accepted offer and active plan atomically",
			false,
			"Could not create and commit fixture Offer."
		)
	var before: String = CampaignStateFixtures.state_signature(with_offer)
	var offer = with_offer.pending_contracts[0]
	var command := PlanContractCommand.create(
		offer.instance_id,
		_member_ids(with_offer),
		[],
		&"balanced"
	)
	var command_before: String = command.content_signature()
	var service_result = ContractOfferService.accept_offer(
		with_offer,
		command,
		ContractOfferFixtures.create_planning_definitions()
	)
	var committed = CampaignTransaction.apply(
		with_offer,
		service_result.operations
	)
	var passed: bool = service_result.is_success() \
		and committed.is_success() \
		and committed.new_state.pending_contracts[0].status \
			== ContractOfferState.STATUS_ACCEPTED \
		and committed.new_state.active_plan != null \
		and committed.new_state.active_plan.contract_instance_id == offer.instance_id \
		and CampaignStateFixtures.state_signature(with_offer) == before \
		and command.content_signature() == command_before
	return _result(
		"valid plan installs accepted offer and active plan atomically",
		passed,
		"Expected accepted+plan in the new state and unchanged service inputs."
	)


func _invalid_plans_are_pure_test() -> Dictionary:
	var state = _commit_created_offer(
		CampaignStateFixtures.create_baseline_state()
	)
	if state == null:
		return _result(
			"invalid plans fail without partial state",
			false,
			"Could not create and commit fixture Offer."
		)
	var offer = state.pending_contracts[0]
	var members: Array[StringName] = _member_ids(state)
	var invalid_commands: Array[PlanContractCommand] = [
		PlanContractCommand.create(
			offer.instance_id,
			[members[0], members[1], members[2]],
			[],
			&"balanced"
		),
		PlanContractCommand.create(
			offer.instance_id,
			[members[0], members[0], members[1], members[2]],
			[],
			&"balanced"
		),
	]
	var before: String = CampaignStateFixtures.state_signature(state)
	for command: PlanContractCommand in invalid_commands:
		var result = ContractOfferService.accept_offer(
			state,
			command,
			ContractOfferFixtures.create_planning_definitions()
		)
		if result.is_success() or not result.operations.is_empty() \
			or CampaignStateFixtures.state_signature(state) != before:
			return _result(
				"invalid plans fail without partial state",
				false,
				"Invalid member count or duplicate IDs produced state intent."
			)

	state.adventurers[members[0]]._is_available = false
	before = CampaignStateFixtures.state_signature(state)
	var unavailable := PlanContractCommand.create(
		offer.instance_id,
		members,
		[],
		&"balanced"
	)
	var unavailable_result = ContractOfferService.accept_offer(
		state,
		unavailable,
		ContractOfferFixtures.create_planning_definitions()
	)
	var unavailable_passed: bool = not unavailable_result.is_success() \
		and unavailable_result.operations.is_empty() \
		and CampaignStateFixtures.state_signature(state) == before

	var economic_state = _commit_created_offer(
		CampaignStateFixtures.create_baseline_state(0)
	)
	var economic_members: Array[StringName] = _member_ids(economic_state)
	var unaffordable := PlanContractCommand.create(
		economic_state.pending_contracts[0].instance_id,
		economic_members,
		[&"supply_medical"],
		&"balanced"
	)
	var unaffordable_result = ContractOfferService.accept_offer(
		economic_state,
		unaffordable,
		ContractOfferFixtures.create_planning_definitions()
	)
	var illegal_supply_state = _commit_created_offer(
		CampaignStateFixtures.create_baseline_state()
	)
	var illegal_supply := PlanContractCommand.create(
		illegal_supply_state.pending_contracts[0].instance_id,
		_member_ids(illegal_supply_state),
		[&"supply_arcane_binding"],
		&"balanced"
	)
	var illegal_supply_result = ContractOfferService.accept_offer(
		illegal_supply_state,
		illegal_supply,
		ContractOfferFixtures.create_planning_definitions()
	)
	var opposed_state = _commit_created_offer(
		CampaignStateFixtures.create_baseline_state(),
		-100
	)
	var opposed_members: Array[StringName] = _member_ids(opposed_state)
	opposed_state.adventurers[opposed_members[0]].set_morale(20)
	var opposed_definitions = ContractOfferFixtures.create_planning_definitions()
	var original: AdventurerDefinition = (
		opposed_definitions.adventurer_definitions[opposed_members[0]]
	)
	opposed_definitions.adventurer_definitions[opposed_members[0]] = (
		AdventurerDefinition.create(
			original.id,
			original.display_name,
			original.class_id,
			original.base_capabilities,
			IdeologyVector.create_base(-5, -5, -5, -5, -5),
			[&"ruthless"],
			original.starting_relationships,
			1000
		)
	)
	opposed_definitions.contract_definitions[
		ContractOfferFixtures.CONTRACT_ID
	].intent_ideology_vector = IdeologyVector.create_task_accumulation(
		10, 10, 10, 10, 10
	)
	var opposed := PlanContractCommand.create(
		opposed_state.pending_contracts[0].instance_id,
		opposed_members,
		[],
		&"balanced"
	)
	var opposed_result = ContractOfferService.accept_offer(
		opposed_state,
		opposed,
		opposed_definitions
	)
	var passed: bool = unavailable_passed \
		and not unaffordable_result.is_success() \
		and unaffordable_result.operations.is_empty() \
		and not illegal_supply_result.is_success() \
		and illegal_supply_result.operations.is_empty() \
		and not opposed_result.is_success() \
		and opposed_result.operations.is_empty()
	return _result(
		"invalid plans fail without partial state",
		passed,
		"Unavailable, opposed, unaffordable, and illegal-supply plans must return no intent."
	)


func _decline_quota_and_archive_test() -> Dictionary:
	var state = _commit_created_offer(
		CampaignStateFixtures.create_baseline_state()
	)
	if state == null:
		return _result(
			"decline quota history and next-week archive are atomic",
			false,
			"Could not create and commit fixture Offer."
		)
	var offer = state.pending_contracts[0]
	var before: String = CampaignStateFixtures.state_signature(state)
	var decline = ContractOfferService.decline_offer(
		state,
		DeclineContractOfferCommand.create(offer.instance_id)
	)
	var committed = CampaignTransaction.apply(state, decline.operations)
	if not decline.is_success() or not committed.is_success():
		return _result(
			"decline quota history and next-week archive are atomic",
			false,
			"Decline failed: %s / %s" % [decline.issues, committed.issues]
		)
	var declined_state = committed.new_state
	var repeated = ContractOfferService.decline_offer(
		declined_state,
		DeclineContractOfferCommand.create(offer.instance_id)
	)
	var archive = ContractOfferService.archive_declined(
		declined_state,
		declined_state.week_index + 1
	)
	var archived = CampaignTransaction.apply(
		declined_state,
		archive.operations
	)
	var passed: bool = CampaignStateFixtures.state_signature(state) == before \
		and declined_state.pending_contracts[0].status \
			== ContractOfferState.STATUS_DECLINED \
		and declined_state.declined_offer_week == declined_state.week_index \
		and declined_state.contract_history.size() == 1 \
		and decline.generated_messages.size() == 1 \
		and decline.generated_messages[0].category == &"contract_lifecycle" \
		and decline.new_state != null \
		and CampaignStateFixtures.state_signature(decline.new_state) \
			== CampaignStateFixtures.state_signature(declined_state) \
		and not repeated.is_success() \
		and repeated.operations.is_empty() \
		and archive.is_success() \
		and archive.suppression_keys.size() == 1 \
		and archived.is_success() \
		and archived.new_state.pending_contracts.is_empty() \
		and archived.new_state.contract_history.size() == 1
	return _result(
		"decline quota history and next-week archive are atomic",
		passed,
		"Expected one quota use, one history row, and one suppression key."
	)


func _commit_created_offer(state, relation: int = 0):
	var request = ContractOfferFixtures.create_request(state, relation)
	var created = ContractOfferService.create_offer(request)
	if not created.is_success():
		return null
	var committed = CampaignTransaction.apply(state, created.operations)
	return committed.new_state if committed.is_success() else null


func _member_ids(state) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(state.adventurers.keys())
	result.sort()
	return result


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
