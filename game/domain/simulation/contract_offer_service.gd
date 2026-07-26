class_name ContractOfferService
extends RefCounted

const StableSeed = preload("res://game/core/random/stable_seed.gd")
const StateOperation = preload("res://game/core/result/state_operation.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const AdventurerSnapshot = preload(
	"res://game/domain/adventurers/adventurer_snapshot.gd"
)
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const ContractInstantiationSnapshot = preload(
	"res://game/domain/contracts/contract_instantiation_snapshot.gd"
)
const CheckDifficultyBinding = preload(
	"res://game/domain/contracts/check_difficulty_binding.gd"
)
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const ContractPlanState = preload(
	"res://game/domain/contracts/contract_plan_state.gd"
)
const ContractPlanningDefinitions = preload(
	"res://game/domain/contracts/contract_planning_definitions.gd"
)
const DeclinedOfferSuppressionKey = preload(
	"res://game/domain/contracts/declined_offer_suppression_key.gd"
)
const CreateContractOfferRequest = preload(
	"res://game/domain/contracts/create_contract_offer_request.gd"
)
const PlanContractCommand = preload(
	"res://game/domain/contracts/plan_contract_command.gd"
)
const DeclineContractOfferCommand = preload(
	"res://game/domain/contracts/decline_contract_offer_command.gd"
)
const EffectiveContract = preload(
	"res://game/domain/contracts/effective_contract.gd"
)
const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const ContractStageDefinition = preload(
	"res://game/domain/contracts/contract_stage_definition.gd"
)
const SupplyDefinition = preload(
	"res://game/domain/contracts/supply_definition.gd"
)
const MethodTagDefinition = preload(
	"res://game/domain/contracts/method_tag_definition.gd"
)
const MissionContext = preload(
	"res://game/domain/contracts/mission_context.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const ContractPlanValidator = preload(
	"res://game/domain/simulation/contract_plan_validator.gd"
)
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const StateChange = preload("res://game/core/result/state_change.gd")
const FactionDefinition = preload(
	"res://game/domain/factions/faction_definition.gd"
)
const FactionActionDefinition = preload(
	"res://game/domain/factions/faction_action_definition.gd"
)
const FactionActionCommitmentState = preload(
	"res://game/domain/factions/faction_action_commitment_state.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const WorldConditionEvaluator = preload(
	"res://game/domain/situations/world_condition_evaluator.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const MessageRequest = preload("res://game/domain/messages/message_request.gd")
const MessageState = preload("res://game/domain/messages/message_state.gd")
const WeeklyMessageProjector = preload(
	"res://game/domain/simulation/weekly_message_projector.gd"
)

const TARGET_CAMPAIGN: StringName = &"campaign"
const TARGET_CONTRACT_OFFER: StringName = &"contract_offer"
const ID_CAMPAIGN: StringName = &"campaign"
const FIELD_PENDING_CONTRACTS: StringName = &"pending_contracts"
const FIELD_ACTIVE_PLAN: StringName = &"active_plan"
const FIELD_DECLINED_OFFER_WEEK: StringName = &"declined_offer_week"
const FIELD_CONTRACT_HISTORY: StringName = &"contract_history"
const FIELD_STATUS: StringName = &"status"
const FIELD_RESOLVED_WEEK: StringName = &"resolved_week"
const FIELD_TERMINAL_REASON_CODE: StringName = &"terminal_reason_code"

const REASON_OFFER_CREATED: StringName = &"contract_offer_created"
const REASON_OFFER_ACCEPTED: StringName = &"contract_offer_accepted"
const REASON_OFFER_DECLINED: StringName = &"contract_offer_declined"
const REASON_OFFER_ARCHIVED: StringName = &"contract_offer_archived"
const TERMINAL_PLAYER_DECLINED: StringName = &"player_declined_contract_offer"

const SOURCE_CREATE: int = 900
const SOURCE_ACCEPT: int = 910
const SOURCE_DECLINE: int = 920
const SOURCE_ARCHIVE: int = 930
const SOURCE_LIFECYCLE: int = 1400
const SOURCE_LIFECYCLE_EFFECT: int = 1500


class OfferServiceResult extends RefCounted:
	var operations: Array[StateOperation]
	var created_offer: ContractOfferState
	var updated_offer: ContractOfferState
	var plan: ContractPlanState
	var reason_entries: Array[ReasonEntry]
	var suppression_keys: Array[DeclinedOfferSuppressionKey]
	var message_requests: Array[MessageRequest]
	var generated_messages: Array[MessageState]
	var message_projection_result: WeeklyMessageProjector.MessageProjectionResult
	var state_changes: Array[StateChange]
	var new_state: CampaignState
	var issues: PackedStringArray

	func is_success() -> bool:
		return issues.is_empty()


class UnhandledLifecycleResult extends RefCounted:
	var operations: Array[StateOperation]
	var updated_offers: Array[ContractOfferState]
	var history_entries: Array[ContractHistoryEntry]
	var world_events: Array[WorldEventState]
	var reason_entries: Array[ReasonEntry]
	var state_changes: Array[StateChange]
	var new_state: CampaignState
	var issues: PackedStringArray

	func is_success() -> bool:
		return new_state != null and issues.is_empty()


## Creates a fully locked pending Offer and the operation that can append it.
## The request is detached, and neither it nor its nested definition is mutated.
static func create_offer(request: CreateContractOfferRequest) -> OfferServiceResult:
	var result := OfferServiceResult.new()
	if request == null:
		result.issues.append("ContractOfferService.create_offer requires a request.")
		return result
	result.issues.append_array(request.validate())
	if not result.issues.is_empty():
		return result

	var snapshot: ContractInstantiationSnapshot = instantiate(request)
	if snapshot == null:
		result.issues.append("Contract offer instantiation produced an invalid snapshot.")
		return result

	var definition: ContractDefinition = request.definition
	var relation_tier: StringName = ContractOfferState.relation_tier_for(
		request.sponsor_relation
	)
	var duration_bonus: int = _duration_bonus_for_tier(relation_tier)
	var reward_multiplier: float = _reward_multiplier_for_tier(relation_tier)
	# roundi is the documented round-away boundary; reward is rounded exactly once.
	var offered_reward: int = roundi(float(definition.base_reward) * reward_multiplier)
	var expires_week: int = (
		request.offered_week
		+ definition.offer_duration_weeks
		+ duration_bonus
		- 1
	)
	var fragments: Array[StringName] = [
		&"contract_offer",
		StringName(str(request.offered_week)),
		definition.sponsor_faction_id,
		definition.id,
		request.origin_type,
		request.related_problem_id,
		definition.target_lock_key,
	]
	var offer_id := StringName(
		"contract_offer_%08x" % StableSeed.derive(0, fragments)
	)
	var resolution_seed: int = StableSeed.derive(
		request.campaign_seed,
		[offer_id, &"contract_resolution"]
	)

	for existing: ContractOfferState in request.existing_offers:
		if existing.instance_id == offer_id:
			result.issues.append(
				"Contract offer ID collision for %s; existing records cannot be overwritten."
				% offer_id
			)
		if (
			existing.status == ContractOfferState.STATUS_PENDING
			and existing.sponsor_faction_id == definition.sponsor_faction_id
		):
			result.issues.append(
				"Faction %s already has a pending contract offer."
				% definition.sponsor_faction_id
			)
		if (
			(
				existing.status == ContractOfferState.STATUS_PENDING
				or existing.status == ContractOfferState.STATUS_ACCEPTED
			)
			and existing.target_lock_key == definition.target_lock_key
		):
			result.issues.append(
				"Contract target lock %s is already occupied."
				% definition.target_lock_key
			)
	if not result.issues.is_empty():
		return result

	var urgency_at_offer: int = (
		request.problem_urgency.score
		if request.problem_urgency != null
		else 0
	)
	var offer := ContractOfferState.create(
		offer_id,
		definition.id,
		definition.sponsor_faction_id,
		request.origin_type,
		request.related_problem_id,
		definition.target_lock_key,
		request.offered_week,
		expires_week,
		offered_reward,
		relation_tier,
		request.sponsor_relation,
		urgency_at_offer,
		request.generation_reason_entries,
		resolution_seed,
		snapshot
	)
	if offer == null:
		result.issues.append("Contract offer failed its locked-state validation.")
		return result

	result.created_offer = offer.duplicate_state()
	result.reason_entries.append(_reason(
		REASON_OFFER_CREATED,
		definition.id,
		offer_id,
		float(offered_reward),
		&"contract_offer",
		ReasonEntry.VISIBILITY_PLAYER
	))
	result.operations.append(StateOperation.create(
		TARGET_CAMPAIGN,
		ID_CAMPAIGN,
		FIELD_PENDING_CONTRACTS,
		StateOperation.OP_APPEND_RECORD,
		offer,
		REASON_OFFER_CREATED,
		SOURCE_CREATE
	))
	return result


## Evaluates all matching instantiation rules in stable rule-ID order.
## Effects are summed before their documented aggregate clamp is applied.
static func instantiate(
	request: CreateContractOfferRequest
) -> ContractInstantiationSnapshot:
	if request == null or not request.validate().is_empty():
		return null

	var rules: Array[ContractDefinition.OfferInstantiationRule] = []
	rules.append_array(request.definition.instantiation_rules)
	rules.sort_custom(func(
		left: ContractDefinition.OfferInstantiationRule,
		right: ContractDefinition.OfferInstantiationRule
	) -> bool:
		if left == null:
			return right != null
		if right == null:
			return false
		return String(left.id) < String(right.id)
	)

	var check_totals: Dictionary[StringName, int] = {}
	var context_totals: Dictionary[StringName, int] = {}
	var check_reason_codes: Dictionary[StringName, Array] = {}
	var context_reason_codes: Dictionary[StringName, Array] = {}
	var matched_rules: Array[ContractDefinition.OfferInstantiationRule] = []
	for rule: ContractDefinition.OfferInstantiationRule in rules:
		if rule == null or not _instantiation_rule_matches(rule, request):
			continue
		matched_rules.append(rule)
		for effect: ContractDefinition.OfferInstantiationEffect in rule.effects:
			if effect == null or effect.amount == 0:
				continue
			if effect.type == &"add_check_difficulty":
				check_totals[effect.target_id] = (
					check_totals.get(effect.target_id, 0) + effect.amount
				)
				_append_reason_code(
					check_reason_codes,
					effect.target_id,
					rule.reason_code
				)
			elif effect.type == &"add_initial_context":
				context_totals[effect.target_id] = (
					context_totals.get(effect.target_id, 0) + effect.amount
				)
				_append_reason_code(
					context_reason_codes,
					effect.target_id,
					rule.reason_code
				)

	var bindings: Array[CheckDifficultyBinding] = []
	var check_ids: Array[StringName] = check_totals.keys()
	check_ids.sort()
	var effective_reason_codes: Dictionary[StringName, bool] = {}
	for check_id: StringName in check_ids:
		var final_delta: int = clampi(
			check_totals[check_id],
			CheckDifficultyBinding.MIN_DIFFICULTY_DELTA,
			CheckDifficultyBinding.MAX_DIFFICULTY_DELTA
		)
		if final_delta == 0:
			continue
		var codes: Array[StringName] = []
		codes.assign(check_reason_codes.get(check_id, []))
		for code: StringName in codes:
			effective_reason_codes[code] = true
		var binding := CheckDifficultyBinding.create(
			check_id,
			final_delta,
			codes
		)
		if binding == null:
			return null
		bindings.append(binding)

	var context_values: Dictionary[StringName, int] = {}
	for key: StringName in MissionContext.CONTEXT_KEYS:
		var aggregate_delta: int = clampi(context_totals.get(key, 0), -6, 6)
		var final_value: int = clampi(aggregate_delta, 0, 10)
		context_values[key] = final_value
		if final_value == 0:
			continue
		var codes: Array[StringName] = []
		codes.assign(context_reason_codes.get(key, []))
		for code: StringName in codes:
			effective_reason_codes[code] = true

	var reasons: Array[ReasonEntry] = []
	for rule: ContractDefinition.OfferInstantiationRule in matched_rules:
		if not effective_reason_codes.has(rule.reason_code):
			continue
		reasons.append(_reason(
			rule.reason_code,
			rule.id,
			request.definition.id,
			_rule_effect_amount(rule),
			&"contract_instantiation",
			ReasonEntry.VISIBILITY_PLAYER
		))

	return ContractInstantiationSnapshot.create(
		request.offered_week,
		bindings,
		MissionContext.new(context_values),
		reasons
	)


## Accepts a current pending Offer after detached plan, attitude, supply, and
## affordability validation. Supply gold is only prechecked here and is charged
## by the later atomic week-resolution transaction.
static func accept_offer(
	base_state: CampaignState,
	command: PlanContractCommand,
	detached_definitions: ContractPlanningDefinitions
) -> OfferServiceResult:
	var result := OfferServiceResult.new()
	if base_state == null:
		result.issues.append("ContractOfferService.accept_offer requires CampaignState.")
	if command == null:
		result.issues.append("ContractOfferService.accept_offer requires a command.")
	if detached_definitions == null:
		result.issues.append(
			"ContractOfferService.accept_offer requires detached definitions."
		)
	if not result.issues.is_empty():
		return result
	result.issues.append_array(base_state.validate())
	result.issues.append_array(command.validate())
	result.issues.append_array(detached_definitions.validate())
	if not result.issues.is_empty():
		return result

	var offer: ContractOfferState = _find_offer(
		base_state.pending_contracts,
		command.contract_offer_id
	)
	if offer == null:
		result.issues.append("Unknown contract offer %s." % command.contract_offer_id)
		return result
	if offer.status != ContractOfferState.STATUS_PENDING:
		result.issues.append("Only a pending contract offer can be accepted.")
	if base_state.week_index > offer.expires_week:
		result.issues.append("Contract offer %s has expired." % offer.instance_id)
	if base_state.active_plan != null:
		result.issues.append("CampaignState already has an active contract plan.")
	if not result.issues.is_empty():
		return result

	if not detached_definitions.contract_definitions.has(offer.definition_id):
		result.issues.append(
			"Missing detached ContractDefinition %s." % offer.definition_id
		)
		return result
	var definition: ContractDefinition = (
		detached_definitions.contract_definitions[offer.definition_id]
	)
	var effective: EffectiveContract = build_effective_contract(
		offer,
		definition,
		detached_definitions.clauses,
		detached_definitions.method_tag_definitions
	)
	if effective == null:
		result.issues.append(
			"Could not build EffectiveContract for offer %s." % offer.instance_id
		)
		return result

	var member_snapshots: Array[AdventurerSnapshot] = []
	for member_id: StringName in command.selected_member_ids:
		if not base_state.adventurers.has(member_id):
			result.issues.append("Unknown selected adventurer %s." % member_id)
			continue
		if not detached_definitions.adventurer_definitions.has(member_id):
			result.issues.append(
				"Missing detached AdventurerDefinition %s." % member_id
			)
			continue
		var member_snapshot := AdventurerSnapshot.create(
			detached_definitions.adventurer_definitions[member_id],
			base_state.adventurers[member_id]
		)
		if member_snapshot == null:
			result.issues.append(
				"Could not snapshot selected adventurer %s." % member_id
			)
		else:
			member_snapshots.append(member_snapshot)

	var selected_supplies: Array[SupplyDefinition] = []
	var total_supply_cost: int = 0
	for supply_id: StringName in command.selected_supply_ids:
		if not detached_definitions.supply_definitions.has(supply_id):
			result.issues.append("Unknown selected supply %s." % supply_id)
			continue
		var supply = detached_definitions.supply_definitions[supply_id]
		if supply == null:
			result.issues.append("Selected supply %s is null." % supply_id)
			continue
		selected_supplies.append(supply)
		total_supply_cost += supply.cost
	if total_supply_cost > base_state.guild.gold:
		result.issues.append(
			"Selected supplies cost %d gold, but the guild only has %d."
			% [total_supply_cost, base_state.guild.gold]
		)
	if not result.issues.is_empty():
		return result

	var plan := ContractPlan.create(
		member_snapshots,
		selected_supplies,
		command.approach
	)
	var validation = ContractPlanValidator.validate(effective, plan)
	result.issues.append_array(validation.errors)
	if not result.issues.is_empty():
		return result
	for reason: ReasonEntry in validation.reason_entries:
		result.reason_entries.append(reason.duplicate_value())

	var plan_state := ContractPlanState.create(
		offer.instance_id,
		command.selected_member_ids,
		command.selected_supply_ids,
		command.approach
	)
	if plan_state == null:
		result.issues.append("Accepted contract plan state is invalid.")
		return result
	var accepted_offer: ContractOfferState = offer.duplicate_state()
	accepted_offer.status = ContractOfferState.STATUS_ACCEPTED

	result.updated_offer = accepted_offer
	result.plan = plan_state.duplicate_state()
	result.reason_entries.append(_reason(
		REASON_OFFER_ACCEPTED,
		offer.definition_id,
		offer.instance_id,
		0.0,
		&"contract_offer",
		ReasonEntry.VISIBILITY_PLAYER
	))
	result.operations.append(StateOperation.create(
		TARGET_CONTRACT_OFFER,
		offer.instance_id,
		FIELD_STATUS,
		StateOperation.OP_SET_ID,
		ContractOfferState.STATUS_ACCEPTED,
		REASON_OFFER_ACCEPTED,
		SOURCE_ACCEPT
	))
	result.operations.append(StateOperation.create(
		TARGET_CAMPAIGN,
		ID_CAMPAIGN,
		FIELD_ACTIVE_PLAN,
		StateOperation.OP_APPEND_RECORD,
		plan_state,
		REASON_OFFER_ACCEPTED,
		SOURCE_ACCEPT + 1
	))
	return result


## Declines at most one pending Offer per campaign week. The returned batch
## records history and quota use but has no faction or world-state operations.
static func decline_offer(
	base_state: CampaignState,
	command: DeclineContractOfferCommand
) -> OfferServiceResult:
	var result := OfferServiceResult.new()
	if base_state == null:
		result.issues.append("ContractOfferService.decline_offer requires CampaignState.")
	if command == null:
		result.issues.append("ContractOfferService.decline_offer requires a command.")
	if not result.issues.is_empty():
		return result
	result.issues.append_array(base_state.validate())
	result.issues.append_array(command.validate())
	if not result.issues.is_empty():
		return result

	var offer: ContractOfferState = _find_offer(
		base_state.pending_contracts,
		command.contract_offer_id
	)
	if offer == null:
		result.issues.append("Unknown contract offer %s." % command.contract_offer_id)
		return result
	if offer.status != ContractOfferState.STATUS_PENDING:
		result.issues.append("Only a pending contract offer can be declined.")
	if base_state.declined_offer_week == base_state.week_index:
		result.issues.append("The weekly contract-offer decline quota is already used.")
	if not result.issues.is_empty():
		return result

	var declined_offer: ContractOfferState = offer.duplicate_state()
	declined_offer.status = ContractOfferState.STATUS_DECLINED
	declined_offer.resolved_week = base_state.week_index
	declined_offer.terminal_reason_code = TERMINAL_PLAYER_DECLINED
	var history := ContractHistoryEntry.new(
		base_state.week_index,
		offer.offered_week,
		offer.instance_id,
		offer.definition_id,
		offer.sponsor_faction_id,
		offer.origin_type,
		offer.related_problem_id,
		offer.target_lock_key,
		ContractOfferState.STATUS_DECLINED,
		TERMINAL_PLAYER_DECLINED,
		[],
		[],
		&"",
		&"",
		0,
		{},
		[],
		[],
		offer.generation_reason_entries
	)
	var history_issues: PackedStringArray = history.validate()
	if not history_issues.is_empty():
		result.issues.append_array(history_issues)
		return result

	result.updated_offer = declined_offer
	result.reason_entries.append(_reason(
		REASON_OFFER_DECLINED,
		offer.definition_id,
		offer.instance_id,
		0.0,
		&"contract_offer",
		ReasonEntry.VISIBILITY_PLAYER
	))
	result.operations.append(StateOperation.create(
		TARGET_CONTRACT_OFFER,
		offer.instance_id,
		FIELD_STATUS,
		StateOperation.OP_SET_ID,
		ContractOfferState.STATUS_DECLINED,
		REASON_OFFER_DECLINED,
		SOURCE_DECLINE
	))
	# resolved_week uses add_int because Gate C deliberately has no generic setter.
	result.operations.append(StateOperation.create(
		TARGET_CONTRACT_OFFER,
		offer.instance_id,
		FIELD_RESOLVED_WEEK,
		StateOperation.OP_ADD_INT,
		base_state.week_index + 1,
		REASON_OFFER_DECLINED,
		SOURCE_DECLINE + 1
	))
	result.operations.append(StateOperation.create(
		TARGET_CONTRACT_OFFER,
		offer.instance_id,
		FIELD_TERMINAL_REASON_CODE,
		StateOperation.OP_SET_ID,
		TERMINAL_PLAYER_DECLINED,
		REASON_OFFER_DECLINED,
		SOURCE_DECLINE + 2
	))
	result.operations.append(StateOperation.create(
		TARGET_CAMPAIGN,
		ID_CAMPAIGN,
		FIELD_CONTRACT_HISTORY,
		StateOperation.OP_APPEND_RECORD,
		history,
		REASON_OFFER_DECLINED,
		SOURCE_DECLINE + 3
	))
	result.operations.append(StateOperation.create(
		TARGET_CAMPAIGN,
		ID_CAMPAIGN,
		FIELD_DECLINED_OFFER_WEEK,
		StateOperation.OP_ADD_INT,
		base_state.week_index - base_state.declined_offer_week,
		REASON_OFFER_DECLINED,
		SOURCE_DECLINE + 4
	))
	if (
		base_state.active_plan != null
		and base_state.active_plan.contract_instance_id == offer.instance_id
	):
		result.operations.append(StateOperation.create(
			TARGET_CAMPAIGN,
			ID_CAMPAIGN,
			FIELD_ACTIVE_PLAN,
			StateOperation.OP_REMOVE_UNIQUE,
			offer.instance_id,
			REASON_OFFER_DECLINED,
			SOURCE_DECLINE + 5
		))
	var domain_transaction = CampaignTransaction.apply(base_state, result.operations)
	if not domain_transaction.is_success():
		result.issues.append_array(domain_transaction.issues)
		result.operations.clear()
		return result
	result.new_state = domain_transaction.new_state
	result.state_changes = domain_transaction.state_changes
	result.message_requests.append(MessageRequest.create(
		MessageRequest.CATEGORY_CONTRACT_LIFECYCLE,
		&"contract_offer",
		offer.instance_id,
		&"message_contract_declined_title",
		&"message_contract_declined_body",
		{
			"status": ContractOfferState.STATUS_DECLINED,
			"reason_code": TERMINAL_PLAYER_DECLINED,
		},
		MessageRequest.IMPORTANCE_NORMAL
	))
	result.message_projection_result = WeeklyMessageProjector.project_requests(
		result.new_state,
		result,
		result.message_requests
	)
	if not result.message_projection_result.is_success():
		result.issues.append_array(result.message_projection_result.issues)
		result.operations.clear()
		result.state_changes.clear()
		result.new_state = null
		return result
	result.operations.append_array(result.message_projection_result.operations)
	result.generated_messages.assign(
		result.message_projection_result.created_messages
	)
	var final_transaction = CampaignTransaction.apply(base_state, result.operations)
	if not final_transaction.is_success():
		result.issues.append_array(final_transaction.issues)
		result.operations.clear()
		result.generated_messages.clear()
		result.state_changes.clear()
		result.new_state = null
		return result
	result.state_changes = final_transaction.state_changes
	result.new_state = final_transaction.new_state
	return result


## Removes prior-week declined placeholders without duplicating their history.
## Each returned suppression key is transient input for one planner selection.
static func archive_declined(
	base_state: CampaignState,
	current_week: int
) -> OfferServiceResult:
	var result := OfferServiceResult.new()
	if base_state == null:
		result.issues.append(
			"ContractOfferService.archive_declined requires CampaignState."
		)
		return result
	result.issues.append_array(base_state.validate())
	if current_week < 0:
		result.issues.append("archive_declined current_week must be non-negative.")
	if current_week < base_state.week_index:
		result.issues.append("archive_declined cannot run for a past week.")
	if not result.issues.is_empty():
		return result

	var declined: Array[ContractOfferState] = []
	for offer: ContractOfferState in base_state.pending_contracts:
		if (
			offer.status == ContractOfferState.STATUS_DECLINED
			and current_week > offer.resolved_week
		):
			declined.append(offer)
	declined.sort_custom(func(
		left: ContractOfferState,
		right: ContractOfferState
	) -> bool:
		return String(left.instance_id) < String(right.instance_id)
	)

	for index: int in range(declined.size()):
		var offer: ContractOfferState = declined[index]
		var suppression_key := DeclinedOfferSuppressionKey.create(
			offer.definition_id,
			offer.origin_type,
			offer.related_problem_id,
			offer.target_lock_key
		)
		if suppression_key == null:
			result.issues.append(
				"Declined offer %s produced an invalid suppression key."
				% offer.instance_id
			)
			result.operations.clear()
			result.suppression_keys.clear()
			return result
		result.suppression_keys.append(suppression_key)
		result.operations.append(StateOperation.create(
			TARGET_CAMPAIGN,
			ID_CAMPAIGN,
			FIELD_PENDING_CONTRACTS,
			StateOperation.OP_REMOVE_UNIQUE,
			offer.instance_id,
			REASON_OFFER_ARCHIVED,
			SOURCE_ARCHIVE + index
		))
	return result


## Resolves every newly expired pending Offer in stable order. Each offer reads
## the previous result through a private working state, but the public batch
## remains all-or-nothing and never mutates base_state.
static func resolve_unhandled_offers(
	base_state: CampaignState,
	current_week: int,
	contract_definitions: Array[ContractDefinition],
	faction_definitions: Array[FactionDefinition],
	action_definitions: Array[FactionActionDefinition],
	problem_definitions: Array[WorldProblemDefinition]
) -> UnhandledLifecycleResult:
	var result := UnhandledLifecycleResult.new()
	if base_state == null or current_week < 0:
		result.issues.append(
			"Unhandled Offer lifecycle requires a state and non-negative week."
		)
		return result
	if current_week != base_state.week_index:
		result.issues.append(
			"Unhandled Offer lifecycle current_week must match CampaignState.week_index."
		)
		return result
	result.issues.append_array(base_state.validate())
	if not result.issues.is_empty():
		return result
	var contract_map := _definition_map(contract_definitions)
	var faction_map := _definition_map(faction_definitions)
	var action_map := _definition_map(action_definitions)
	var problem_map := _definition_map(problem_definitions)
	if (
		contract_map.size() != contract_definitions.size()
		or faction_map.size() != faction_definitions.size()
		or action_map.size() != action_definitions.size()
		or problem_map.size() != problem_definitions.size()
	):
		result.issues.append("Lifecycle definitions contain null or duplicate IDs.")
		return result

	var expired_offers: Array[ContractOfferState] = []
	for offer: ContractOfferState in base_state.pending_contracts:
		if offer.status == ContractOfferState.STATUS_PENDING \
				and current_week > offer.expires_week:
			expired_offers.append(offer.duplicate_state())
	expired_offers.sort_custom(_expired_offer_less)
	var working := base_state.duplicate_state()
	for offer_index: int in range(expired_offers.size()):
		var offer: ContractOfferState = expired_offers[offer_index]
		if not contract_map.has(offer.definition_id):
			result.issues.append(
				"Missing contract definition %s." % offer.definition_id
			)
			return _clear_lifecycle(result)
		if not faction_map.has(offer.sponsor_faction_id):
			result.issues.append(
				"Missing faction definition %s." % offer.sponsor_faction_id
			)
			return _clear_lifecycle(result)
		var definition: ContractDefinition = contract_map[offer.definition_id]
		if definition.sponsor_faction_id != offer.sponsor_faction_id:
			result.issues.append("Offer sponsor does not match its contract definition.")
			return _clear_lifecycle(result)

		var terminal_status := ContractOfferState.STATUS_EXPIRED
		var terminal_reason := &"offer_expired_by_policy"
		var action: FactionActionDefinition
		var problem_active := offer.related_problem_id.is_empty()
		if not offer.related_problem_id.is_empty():
			if not working.situation.problems.has(offer.related_problem_id) \
					or not problem_map.has(offer.related_problem_id):
				result.issues.append(
					"Offer references missing problem %s." % offer.related_problem_id
				)
				return _clear_lifecycle(result)
			problem_active = working.situation.problems[
				offer.related_problem_id
			].status == WorldProblemState.STATUS_ACTIVE
		if not problem_active:
			terminal_reason = &"offer_expired_problem_inactive"
		else:
			var can_try_npc: bool = definition.unhandled_policy == &"npc_or_expire" \
				or definition.unhandled_policy == &"npc_or_escalate"
			var npc_executable := false
			if can_try_npc:
				if not action_map.has(definition.npc_completion_action_id):
					result.issues.append(
						"Missing NPC completion action %s."
						% definition.npc_completion_action_id
					)
					return _clear_lifecycle(result)
				action = action_map[definition.npc_completion_action_id]
				var faction: FactionDefinition = faction_map[offer.sponsor_faction_id]
				if not faction.weekly_action_ids.has(action.id) \
						or action.target_lock_key != offer.target_lock_key:
					result.issues.append(
						"NPC completion action owner or target lock is inconsistent."
					)
					return _clear_lifecycle(result)
				npc_executable = _npc_action_is_executable(
					working,
					current_week,
					offer,
					action
				)
			if npc_executable:
				terminal_status = ContractOfferState.STATUS_NPC_COMPLETED
				terminal_reason = &"npc_completion_action_executed"
			elif definition.unhandled_policy == &"escalate" \
					or definition.unhandled_policy == &"npc_or_escalate":
				if offer.related_problem_id.is_empty():
					terminal_status = ContractOfferState.STATUS_EXPIRED
					terminal_reason = &"offer_expired_no_problem_to_escalate"
				else:
					terminal_status = ContractOfferState.STATUS_ESCALATED
					terminal_reason = &"offer_escalated_by_policy"

		var offer_operations: Array[StateOperation] = []
		var event_ids: Array[StringName] = []
		if terminal_status == ContractOfferState.STATUS_NPC_COMPLETED:
			offer_operations.append(StateOperation.create(
				CampaignTransaction.TARGET_FACTION,
				offer.sponsor_faction_id,
				CampaignTransaction.FIELD_INFLUENCE,
				StateOperation.OP_ADD_INT,
				-action.influence_cost,
				&"npc_completion_influence_spent",
				SOURCE_LIFECYCLE + offer_index
			))
			var projection := _project_lifecycle_effects(
				action.effects,
				working.situation.definition_id,
				offer.instance_id,
				offer.related_problem_id,
				current_week,
				SOURCE_LIFECYCLE_EFFECT + offer_index * 20,
				false
			)
			if not projection["issues"].is_empty():
				result.issues.append_array(projection["issues"])
				return _clear_lifecycle(result)
			offer_operations.append_array(projection["operations"])
			event_ids.append_array(projection["event_ids"])
			var action_event := _create_action_event(
				action,
				offer.instance_id,
				offer.related_problem_id,
				current_week
			)
			if action_event == null:
				result.issues.append("NPC completion event could not be created.")
				return _clear_lifecycle(result)
			event_ids.append(action_event.instance_id)
			result.world_events.append(action_event.duplicate_state())
			offer_operations.append(StateOperation.create(
				CampaignTransaction.TARGET_CAMPAIGN,
				CampaignTransaction.ID_CAMPAIGN,
				CampaignTransaction.FIELD_WORLD_EVENTS,
				StateOperation.OP_APPEND_RECORD,
				action_event,
				terminal_reason,
				SOURCE_LIFECYCLE_EFFECT + offer_index * 20 + 19
			))
		elif terminal_status == ContractOfferState.STATUS_ESCALATED:
			var problem: WorldProblemDefinition = problem_map[offer.related_problem_id]
			var projection := _project_lifecycle_effects(
				problem.escalation_effects,
				working.situation.definition_id,
				offer.instance_id,
				offer.related_problem_id,
				current_week,
				SOURCE_LIFECYCLE_EFFECT + offer_index * 20,
				true
			)
			if not projection["issues"].is_empty():
				result.issues.append_array(projection["issues"])
				return _clear_lifecycle(result)
			offer_operations.append_array(projection["operations"])
			event_ids.append_array(projection["event_ids"])
			for event: WorldEventState in projection["events"]:
				result.world_events.append(event.duplicate_state())
			offer_operations.append_array(_problem_escalation_operations(
				offer.related_problem_id,
				current_week,
				terminal_reason,
				event_ids[0] if not event_ids.is_empty() else &"",
				SOURCE_LIFECYCLE + offer_index
			))

		var history := ContractHistoryEntry.new(
			current_week,
			offer.offered_week,
			offer.instance_id,
			offer.definition_id,
			offer.sponsor_faction_id,
			offer.origin_type,
			offer.related_problem_id,
			offer.target_lock_key,
			terminal_status,
			terminal_reason,
			[],
			[],
			&"",
			&"",
			0,
			{},
			[],
			event_ids,
			offer.generation_reason_entries
		)
		if not history.validate().is_empty():
			result.issues.append("Unhandled Offer history failed validation.")
			return _clear_lifecycle(result)
		offer_operations.append_array(_terminal_offer_operations(
			offer,
			current_week,
			terminal_status,
			terminal_reason,
			history,
			SOURCE_LIFECYCLE + offer_index
		))
		var committed = CampaignTransaction.apply(working, offer_operations)
		if not committed.is_success():
			result.issues.append_array(committed.issues)
			return _clear_lifecycle(result)
		working = committed.new_state
		result.operations.append_array(offer_operations)
		result.history_entries.append(history.duplicate_state())
		var updated := offer.duplicate_state()
		updated.status = terminal_status
		updated.resolved_week = current_week
		updated.terminal_reason_code = terminal_reason
		result.updated_offers.append(updated)
		result.reason_entries.append(_reason(
			terminal_reason,
			offer.definition_id,
			offer.instance_id,
			0.0,
			&"contract_lifecycle",
			ReasonEntry.VISIBILITY_PLAYER
		))
	# Reapply the complete operation list once so the public StateChange audit
	# reflects the same atomic merge boundary that the caller will commit.
	var final_transaction = CampaignTransaction.apply(base_state, result.operations)
	if not final_transaction.is_success():
		result.issues.append_array(final_transaction.issues)
		return _clear_lifecycle(result)
	result.new_state = final_transaction.new_state
	result.state_changes = final_transaction.state_changes
	return result


## Projects the locked Offer overlays over detached definitions. It never reads
## the current world, faction relationship, reward, or seed again.
static func build_effective_contract(
	offer: ContractOfferState,
	definition: ContractDefinition,
	clauses: Array[ContractClauseDefinition],
	method_tags: Array[MethodTagDefinition]
) -> EffectiveContract:
	if (
		offer == null
		or definition == null
		or offer.definition_id != definition.id
		or offer.instantiation_snapshot == null
	):
		return null

	var difficulty_by_check: Dictionary[StringName, int] = {}
	for binding: CheckDifficultyBinding in (
		offer.instantiation_snapshot.check_difficulty_deltas
	):
		if binding == null:
			return null
		difficulty_by_check[binding.check_id] = binding.difficulty_delta

	var stages: Array[ContractStageDefinition] = []
	for source_stage: ContractStageDefinition in definition.stages:
		stages.append(source_stage.duplicate_value() if source_stage != null else null)
	for stage: ContractStageDefinition in stages:
		if stage == null or stage.check == null:
			return null
		stage.check.difficulty += difficulty_by_check.get(stage.check.id, 0)

	var clauses_by_id: Dictionary[StringName, ContractClauseDefinition] = {}
	for clause: ContractClauseDefinition in clauses:
		if clause == null or clauses_by_id.has(clause.id):
			return null
		clauses_by_id[clause.id] = clause
	var selected_clauses: Array[ContractClauseDefinition] = []
	for clause_id: StringName in definition.clause_ids:
		if not clauses_by_id.has(clause_id):
			return null
		selected_clauses.append(clauses_by_id[clause_id])

	var context_deltas: Array[Dictionary] = []
	for key: StringName in MissionContext.CONTEXT_KEYS:
		var amount: int = (
			offer.instantiation_snapshot.initial_context.get_value(key)
		)
		if amount != 0:
			context_deltas.append(
				MissionContext.create_delta(key, amount, offer.instance_id)
			)

	return EffectiveContract.create_complete(
		offer.instance_id,
		definition.id,
		offer.offered_reward,
		definition.base_fatigue,
		definition.risk_level,
		offer.sponsor_relation_snapshot,
		definition.intent_ideology_vector,
		definition.expected_method_tags,
		definition.allowed_supply_tags,
		stages,
		selected_clauses,
		context_deltas,
		definition.final_outcome_table,
		method_tags
	)


static func _instantiation_rule_matches(
	rule: ContractDefinition.OfferInstantiationRule,
	request: CreateContractOfferRequest
) -> bool:
	for condition: ContractDefinition.OfferBindingCondition in rule.all_conditions:
		if condition == null or not _instantiation_condition_is_met(condition, request):
			return false
	return true


static func _instantiation_condition_is_met(
	condition: ContractDefinition.OfferBindingCondition,
	request: CreateContractOfferRequest
) -> bool:
	match condition.type:
		&"clock_gte":
			return (
				request.situation.clock_values.has(condition.target_id)
				and request.situation.clock_values[condition.target_id] >= condition.int_value
			)
		&"clock_lte":
			return (
				request.situation.clock_values.has(condition.target_id)
				and request.situation.clock_values[condition.target_id] <= condition.int_value
			)
		&"phase_is":
			return request.situation.phase_id == condition.target_id
		&"world_event_occurred":
			for event in request.world_events:
				if event != null and event.event_key == condition.target_id:
					return true
			return false
		&"origin_type_is":
			return request.origin_type == condition.tag_value
		&"problem_urgency_gte":
			return (
				request.origin_type == ContractOfferState.ORIGIN_PROBLEM
				and request.problem_urgency != null
				and request.problem_urgency.score >= condition.int_value
			)
		&"problem_urgency_lte":
			return (
				request.origin_type == ContractOfferState.ORIGIN_PROBLEM
				and request.problem_urgency != null
				and request.problem_urgency.score <= condition.int_value
			)
		&"problem_age_gte":
			var problem: WorldProblemState = _related_problem(request)
			return (
				problem != null
				and problem.opened_week >= 0
				and request.offered_week - problem.opened_week >= condition.int_value
			)
		&"problem_remaining_turns_lte":
			var problem: WorldProblemState = _related_problem(request)
			return (
				problem != null
				and problem.response_deadline_week >= 0
				and (
					problem.response_deadline_week - request.offered_week + 1
					<= condition.int_value
				)
			)
		&"problem_is_active":
			var problem: WorldProblemState = _related_problem(request)
			return problem != null and problem.status == WorldProblemState.STATUS_ACTIVE
	return false


static func _related_problem(
	request: CreateContractOfferRequest
) -> WorldProblemState:
	if (
		request.origin_type != ContractOfferState.ORIGIN_PROBLEM
		or request.related_problem_id.is_empty()
		or not request.situation.problems.has(request.related_problem_id)
	):
		return null
	return request.situation.problems[request.related_problem_id]


static func _append_reason_code(
	reason_codes_by_target: Dictionary[StringName, Array],
	target_id: StringName,
	reason_code: StringName
) -> void:
	var codes: Array = reason_codes_by_target.get(target_id, [])
	if not codes.has(reason_code):
		codes.append(reason_code)
	reason_codes_by_target[target_id] = codes


static func _rule_effect_amount(
	rule: ContractDefinition.OfferInstantiationRule
) -> float:
	var total: int = 0
	for effect: ContractDefinition.OfferInstantiationEffect in rule.effects:
		if effect != null:
			total += effect.amount
	return float(total)


static func _duration_bonus_for_tier(tier: StringName) -> int:
	if tier == ContractOfferState.RELATION_TIER_TRUSTED:
		return 2
	if tier == ContractOfferState.RELATION_TIER_FAVORABLE:
		return 1
	return 0


static func _reward_multiplier_for_tier(tier: StringName) -> float:
	if tier == ContractOfferState.RELATION_TIER_TRUSTED:
		return 1.2
	if tier == ContractOfferState.RELATION_TIER_FAVORABLE:
		return 1.1
	return 1.0


static func _find_offer(
	offers: Array[ContractOfferState],
	offer_id: StringName
) -> ContractOfferState:
	for offer: ContractOfferState in offers:
		if offer != null and offer.instance_id == offer_id:
			return offer
	return null


static func _definition_map(definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for definition: Variant in definitions:
		if definition == null:
			continue
		var definition_id: StringName = definition.get("id")
		if result.has(definition_id):
			return {}
		result[definition_id] = definition
	return result


static func _expired_offer_less(
	left: ContractOfferState,
	right: ContractOfferState
) -> bool:
	if left.expires_week != right.expires_week:
		return left.expires_week < right.expires_week
	if left.offered_week != right.offered_week:
		return left.offered_week < right.offered_week
	return String(left.instance_id) < String(right.instance_id)


static func _npc_action_is_executable(
	state: CampaignState,
	current_week: int,
	expiring_offer: ContractOfferState,
	action: FactionActionDefinition
) -> bool:
	if state.factions[expiring_offer.sponsor_faction_id].influence \
			< action.influence_cost:
		return false
	for condition in action.conditions:
		if not WorldConditionEvaluator.is_met(
			condition,
			current_week,
			state.situation,
			state.world_events,
			state.contract_history
		):
			return false
	# The expiring Offer releases its own lock before this check; every other
	# pending Offer or committed action keeps its reservation.
	for offer: ContractOfferState in state.pending_contracts:
		if offer.instance_id == expiring_offer.instance_id:
			continue
		if offer.status in [
			ContractOfferState.STATUS_PENDING,
			ContractOfferState.STATUS_ACCEPTED,
		] and offer.target_lock_key == action.target_lock_key:
			return false
	for commitment: FactionActionCommitmentState in \
			state.faction_action_commitments:
		if commitment.status == FactionActionCommitmentState.STATUS_COMMITTED \
				and commitment.target_lock_key == action.target_lock_key:
			return false
	return true


static func _project_lifecycle_effects(
	effects: Array[WorldEffect],
	situation_id: StringName,
	source_id: StringName,
	related_problem_id: StringName,
	current_week: int,
	source_order: int,
	allow_embedded_events: bool
) -> Dictionary:
	var operations: Array[StateOperation] = []
	var events: Array[WorldEventState] = []
	var event_ids: Array[StringName] = []
	var issues := PackedStringArray()
	var event_reason_map: Dictionary[StringName, Array] = {}
	for index: int in range(effects.size()):
		var effect: WorldEffect = effects[index]
		match effect.type:
			&"modify_clock":
				operations.append(StateOperation.create(
					CampaignTransaction.TARGET_CLOCK,
					effect.target_id,
					CampaignTransaction.FIELD_VALUE,
					StateOperation.OP_ADD_INT,
					effect.amount,
					effect.reason_code,
					source_order + index
				))
			&"create_world_event":
				if not allow_embedded_events:
					issues.append(
						"Faction action effects cannot contain create_world_event."
					)
					continue
				if not event_reason_map.has(effect.target_id):
					event_reason_map[effect.target_id] = []
				event_reason_map[effect.target_id].append(effect.reason_code)
			&"change_phase":
				operations.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					situation_id,
					CampaignTransaction.FIELD_PHASE_ID,
					StateOperation.OP_SET_ID,
					effect.target_id,
					effect.reason_code,
					source_order + index
				))
			&"unlock_contract":
				operations.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					situation_id,
					CampaignTransaction.FIELD_UNLOCKED_CONTRACT_IDS,
					StateOperation.OP_ADD_UNIQUE,
					effect.target_id,
					effect.reason_code,
					source_order + index
				))
			&"set_ending":
				operations.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					situation_id,
					CampaignTransaction.FIELD_ENDING_ID,
					StateOperation.OP_SET_ID,
					effect.target_id,
					effect.reason_code,
					source_order + index
				))
			_:
				issues.append(
					"Unsupported unhandled lifecycle effect: %s." % effect.type
				)
	var event_keys: Array[StringName] = []
	event_keys.assign(event_reason_map.keys())
	event_keys.sort()
	for event_key: StringName in event_keys:
		var reason_codes: Array[StringName] = []
		reason_codes.assign(event_reason_map[event_key])
		reason_codes.sort()
		var event_id := StringName("%s_%s" % [source_id, event_key])
		var event := WorldEventState.create(
			event_id,
			event_key,
			current_week,
			source_id,
			related_problem_id,
			reason_codes
		)
		if event == null:
			issues.append("Could not create lifecycle event %s." % event_key)
			continue
		event_ids.append(event_id)
		events.append(event)
		operations.append(StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_WORLD_EVENTS,
			StateOperation.OP_APPEND_RECORD,
			event,
			reason_codes[0],
			source_order + effects.size()
		))
	return {
		"operations": operations,
		"events": events,
		"event_ids": event_ids,
		"issues": issues,
	}


static func _create_action_event(
	action: FactionActionDefinition,
	source_id: StringName,
	related_problem_id: StringName,
	current_week: int
) -> WorldEventState:
	var reason_codes: Array[StringName] = []
	for effect: WorldEffect in action.effects:
		if not reason_codes.has(effect.reason_code):
			reason_codes.append(effect.reason_code)
	if reason_codes.is_empty():
		reason_codes.append(&"npc_completion_action_executed")
	reason_codes.sort()
	return WorldEventState.create(
		StringName("%s_%s" % [source_id, action.event_key]),
		action.event_key,
		current_week,
		source_id,
		related_problem_id,
		reason_codes
	)


static func _problem_escalation_operations(
	problem_id: StringName,
	current_week: int,
	reason_code: StringName,
	event_id: StringName,
	source_order: int
) -> Array[StateOperation]:
	var result: Array[StateOperation] = [
		StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem_id,
			CampaignTransaction.FIELD_STATUS,
			StateOperation.OP_SET_ID,
			WorldProblemState.STATUS_ESCALATED,
			reason_code,
			source_order
		),
		StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem_id,
			CampaignTransaction.FIELD_CLOSED_WEEK,
			StateOperation.OP_ADD_INT,
			current_week + 1,
			reason_code,
			source_order
		),
		StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem_id,
			CampaignTransaction.FIELD_RESOLUTION_REASON_CODE,
			StateOperation.OP_SET_ID,
			reason_code,
			reason_code,
			source_order
		),
	]
	if not event_id.is_empty():
		result.append(StateOperation.create(
			CampaignTransaction.TARGET_PROBLEM,
			problem_id,
			CampaignTransaction.FIELD_SOURCE_EVENT_ID,
			StateOperation.OP_SET_ID,
			event_id,
			reason_code,
			source_order
		))
	return result


static func _terminal_offer_operations(
	offer: ContractOfferState,
	current_week: int,
	terminal_status: StringName,
	terminal_reason: StringName,
	history: ContractHistoryEntry,
	source_order: int
) -> Array[StateOperation]:
	return [
		StateOperation.create(
			TARGET_CONTRACT_OFFER,
			offer.instance_id,
			FIELD_STATUS,
			StateOperation.OP_SET_ID,
			terminal_status,
			terminal_reason,
			source_order
		),
		StateOperation.create(
			TARGET_CONTRACT_OFFER,
			offer.instance_id,
			FIELD_RESOLVED_WEEK,
			StateOperation.OP_ADD_INT,
			current_week + 1,
			terminal_reason,
			source_order
		),
		StateOperation.create(
			TARGET_CONTRACT_OFFER,
			offer.instance_id,
			FIELD_TERMINAL_REASON_CODE,
			StateOperation.OP_SET_ID,
			terminal_reason,
			terminal_reason,
			source_order
		),
		StateOperation.create(
			TARGET_CAMPAIGN,
			ID_CAMPAIGN,
			FIELD_CONTRACT_HISTORY,
			StateOperation.OP_APPEND_RECORD,
			history,
			terminal_reason,
			source_order
		),
		StateOperation.create(
			TARGET_CAMPAIGN,
			ID_CAMPAIGN,
			FIELD_PENDING_CONTRACTS,
			StateOperation.OP_REMOVE_UNIQUE,
			offer.instance_id,
			terminal_reason,
			source_order
		),
	]


static func _clear_lifecycle(
	result: UnhandledLifecycleResult
) -> UnhandledLifecycleResult:
	result.operations.clear()
	result.updated_offers.clear()
	result.history_entries.clear()
	result.world_events.clear()
	result.reason_entries.clear()
	result.state_changes.clear()
	result.new_state = null
	return result


static func _reason(
	code: StringName,
	source_id: StringName,
	target_id: StringName,
	amount: float,
	category: StringName,
	visibility: StringName
) -> ReasonEntry:
	return ReasonEntry.create(
		code,
		category,
		source_id,
		target_id,
		amount,
		StringName("reason.%s" % code),
		{},
		&"contract_offer",
		visibility
	)
