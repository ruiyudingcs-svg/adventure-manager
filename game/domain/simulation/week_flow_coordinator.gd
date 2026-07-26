class_name WeekFlowCoordinator
extends RefCounted

const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
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
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const ContractPlanningDefinitions = preload(
	"res://game/domain/contracts/contract_planning_definitions.gd"
)
const SupplyDefinition = preload(
	"res://game/domain/contracts/supply_definition.gd"
)
const FactionDefinition = preload(
	"res://game/domain/factions/faction_definition.gd"
)
const FactionActionDefinition = preload(
	"res://game/domain/factions/faction_action_definition.gd"
)
const SituationDefinition = preload(
	"res://game/domain/situations/situation_definition.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const ProblemUrgencyResult = preload(
	"res://game/domain/situations/problem_urgency_result.gd"
)
const DeclinedOfferSuppressionKey = preload(
	"res://game/domain/contracts/declined_offer_suppression_key.gd"
)
const StateOperation = preload("res://game/core/result/state_operation.gd")
const StateChange = preload("res://game/core/result/state_change.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const CampaignHistoryQuery = preload(
	"res://game/domain/campaign/campaign_history_query.gd"
)
const WeeklyUpkeepResolver = preload(
	"res://game/domain/simulation/weekly_upkeep_resolver.gd"
)
const SituationResolver = preload(
	"res://game/domain/simulation/situation_resolver.gd"
)
const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const FactionTurnPlanner = preload(
	"res://game/domain/simulation/faction_turn_planner.gd"
)
const ProblemUrgencyCalculator = preload(
	"res://game/domain/simulation/problem_urgency_calculator.gd"
)
const ContractResolver = preload(
	"res://game/domain/simulation/contract_resolver.gd"
)
const ContractResolutionProjector = preload(
	"res://game/domain/simulation/contract_resolution_projector.gd"
)
const MessageRequest = preload("res://game/domain/messages/message_request.gd")
const MessageState = preload("res://game/domain/messages/message_state.gd")
const WeeklyMessageProjector = preload(
	"res://game/domain/simulation/weekly_message_projector.gd"
)

const SOURCE_WEEK_STARTED: int = 1
const SOURCE_OFFER_RESOLVED: int = 900
const REASON_WEEK_STARTED: StringName = &"week_started"
const REASON_OFFER_RESOLVED: StringName = &"contract_offer_resolved"


class WeekOpeningRequest extends RefCounted:
	var current_week: int
	var base_state: CampaignState
	var adventurer_definitions: Array[AdventurerDefinition]
	var faction_definitions: Array[FactionDefinition]
	var contract_definitions: Array[ContractDefinition]
	var action_definitions: Array[FactionActionDefinition]
	var problem_definitions: Array[WorldProblemDefinition]
	var situation_definition: SituationDefinition
	var declined_suppressions: Array[DeclinedOfferSuppressionKey]

	static func create(
		p_current_week: int,
		p_base_state: CampaignState,
		p_adventurer_definitions: Array[AdventurerDefinition],
		p_faction_definitions: Array[FactionDefinition],
		p_contract_definitions: Array[ContractDefinition],
		p_action_definitions: Array[FactionActionDefinition],
		p_problem_definitions: Array[WorldProblemDefinition],
		p_situation_definition: SituationDefinition,
		p_declined_suppressions: Array[DeclinedOfferSuppressionKey] = []
	) -> WeekOpeningRequest:
		var request := WeekOpeningRequest.new()
		request.current_week = p_current_week
		request.base_state = (
			p_base_state.duplicate_state() if p_base_state != null else null
		)
		request.adventurer_definitions.assign(p_adventurer_definitions)
		request.faction_definitions.assign(p_faction_definitions)
		request.contract_definitions.assign(p_contract_definitions)
		request.action_definitions.assign(p_action_definitions)
		request.problem_definitions.assign(p_problem_definitions)
		request.situation_definition = p_situation_definition
		request.declined_suppressions.assign(p_declined_suppressions)
		return request


class WeekOpeningResult extends RefCounted:
	var participation_result: CampaignHistoryQuery.ParticipationQueryResult
	var upkeep_result: WeeklyUpkeepResolver.WeeklyUpkeepResult
	var prelude_result: SituationResolver.ResolutionResult
	var lifecycle_result: ContractOfferService.UnhandledLifecycleResult
	var post_world_result: SituationResolver.ResolutionResult
	var planning_result: FactionTurnPlanner.FactionPlanningResult
	var operations: Array[StateOperation]
	var state_changes: Array[StateChange]
	var reasons: Array[ReasonEntry]
	var message_requests: Array[MessageRequest]
	var generated_messages: Array[MessageState]
	var message_projection_result: WeeklyMessageProjector.MessageProjectionResult
	var new_state: CampaignState
	var issues: PackedStringArray

	func is_success() -> bool:
		return new_state != null and issues.is_empty()


class WeekResolutionRequest extends RefCounted:
	var current_week: int
	var base_state: CampaignState
	var skip_contract: bool
	var planning_definitions: ContractPlanningDefinitions
	var action_definitions: Array[FactionActionDefinition]
	var situation_definition: SituationDefinition

	static func create(
		p_current_week: int,
		p_base_state: CampaignState,
		p_skip_contract: bool,
		p_planning_definitions: ContractPlanningDefinitions,
		p_action_definitions: Array[FactionActionDefinition],
		p_situation_definition: SituationDefinition
	) -> WeekResolutionRequest:
		var request := WeekResolutionRequest.new()
		request.current_week = p_current_week
		request.base_state = (
			p_base_state.duplicate_state() if p_base_state != null else null
		)
		request.skip_contract = p_skip_contract
		request.planning_definitions = (
			p_planning_definitions.duplicate_value()
			if p_planning_definitions != null
			else null
		)
		request.action_definitions.assign(p_action_definitions)
		request.situation_definition = p_situation_definition
		return request


class WeekResolution extends RefCounted:
	var contract_resolve_result: ContractResolver.ResolveResult
	var contract_projection_result: ContractResolutionProjector.ProjectionResult
	var action_resolution_result: FactionTurnPlanner.FactionActionResolutionResult
	var post_world_result: SituationResolver.ResolutionResult
	var operations: Array[StateOperation]
	var state_changes: Array[StateChange]
	var reasons: Array[ReasonEntry]
	var message_requests: Array[MessageRequest]
	var generated_messages: Array[MessageState]
	var message_projection_result: WeeklyMessageProjector.MessageProjectionResult
	var new_state: CampaignState
	var issues: PackedStringArray

	func is_success() -> bool:
		return new_state != null and issues.is_empty()


## Opens exactly the next week. All previews remain private and only the final
## combined transaction state is exposed to the caller.
static func open_week(request: WeekOpeningRequest) -> WeekOpeningResult:
	var result := WeekOpeningResult.new()
	if request == null or request.base_state == null:
		result.issues.append("Week opening requires a request and CampaignState.")
		return result
	var base_state: CampaignState = request.base_state
	if request.current_week != base_state.week_index + 1:
		result.issues.append("open_week must advance CampaignState by exactly one week.")
	if request.situation_definition == null:
		result.issues.append("Week opening requires a SituationDefinition.")
	elif request.situation_definition.id != base_state.situation.definition_id:
		result.issues.append("Week opening SituationDefinition does not match state.")
	result.issues.append_array(base_state.validate())
	if not result.issues.is_empty():
		return _clear_opening(result)

	var week_operation := StateOperation.create(
		CampaignTransaction.TARGET_CAMPAIGN,
		CampaignTransaction.ID_CAMPAIGN,
		CampaignTransaction.FIELD_WEEK_INDEX,
		StateOperation.OP_ADD_INT,
		1,
		REASON_WEEK_STARTED,
		SOURCE_WEEK_STARTED
	)
	var first_operations: Array[StateOperation] = [week_operation]
	result.reasons.append(ReasonEntry.create(
		REASON_WEEK_STARTED,
		&"week_flow",
		&"week_flow_coordinator",
		&"campaign",
		request.current_week,
		REASON_WEEK_STARTED,
		{"week_index": request.current_week},
		&"week_start",
		ReasonEntry.VISIBILITY_PLAYER
	))
	var urgency_results: Array[ProblemUrgencyResult] = []

	if request.current_week == 1:
		var week_preview = CampaignTransaction.apply(base_state, first_operations)
		if not week_preview.is_success():
			result.issues.append_array(week_preview.issues)
			return _clear_opening(result)
		urgency_results = _initial_urgencies(
			request.current_week,
			week_preview.new_state,
			request.problem_definitions
		)
		return _plan_and_commit_opening(
			request,
			result,
			first_operations,
			week_preview.new_state,
			urgency_results
		)

	result.participation_result = CampaignHistoryQuery.participation_for_week(
		base_state,
		request.current_week - 1
	)
	if not result.participation_result.is_success():
		result.issues.append_array(result.participation_result.issues)
		return _clear_opening(result)
	result.upkeep_result = WeeklyUpkeepResolver.resolve(
		request.current_week,
		base_state,
		request.adventurer_definitions,
		result.participation_result.snapshot
	)
	if not result.upkeep_result.is_success():
		result.issues.append_array(result.upkeep_result.issues)
		return _clear_opening(result)
	first_operations.append_array(result.upkeep_result.operations)
	result.reasons.append_array(result.upkeep_result.reason_entries)

	result.prelude_result = SituationResolver.resolve_week_start_prelude(
		request.current_week,
		request.situation_definition,
		base_state.situation,
		base_state.world_events,
		base_state.contract_history
	)
	if not result.prelude_result.is_success():
		result.issues.append_array(result.prelude_result.issues)
		return _clear_opening(result)
	first_operations.append_array(result.prelude_result.operations)

	var prelude_preview = CampaignTransaction.apply(base_state, first_operations)
	if not prelude_preview.is_success():
		result.issues.append_array(prelude_preview.issues)
		return _clear_opening(result)
	result.lifecycle_result = ContractOfferService.resolve_unhandled_offers(
		prelude_preview.new_state,
		request.current_week,
		request.contract_definitions,
		request.faction_definitions,
		request.action_definitions,
		request.problem_definitions
	)
	if not result.lifecycle_result.is_success():
		result.issues.append_array(result.lifecycle_result.issues)
		return _clear_opening(result)
	first_operations.append_array(result.lifecycle_result.operations)
	result.reasons.append_array(result.lifecycle_result.reason_entries)

	result.post_world_result = SituationResolver.resolve_after_base_operations(
		request.current_week,
		request.situation_definition,
		result.lifecycle_result.new_state.situation,
		result.lifecycle_result.new_state.world_events,
		result.lifecycle_result.new_state.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_START
	)
	if not result.post_world_result.is_success():
		result.issues.append_array(result.post_world_result.issues)
		return _clear_opening(result)
	first_operations.append_array(result.post_world_result.operations)
	urgency_results.assign(result.post_world_result.urgency_results)

	var world_transaction = CampaignTransaction.apply(base_state, first_operations)
	if not world_transaction.is_success():
		result.issues.append_array(world_transaction.issues)
		return _clear_opening(result)
	if not world_transaction.new_state.situation.ending_id.is_empty():
		result.operations = first_operations
		result.state_changes = world_transaction.state_changes
		result.new_state = world_transaction.new_state
		return _finalize_opening_messages(request, result)
	return _plan_and_commit_opening(
		request,
		result,
		first_operations,
		world_transaction.new_state,
		urgency_results
	)


## Resolves the accepted player contract (or explicit no-contract choice), all
## locked faction actions, and one post-base world batch in one transaction.
static func resolve_week(request: WeekResolutionRequest) -> WeekResolution:
	var result := WeekResolution.new()
	if request == null or request.base_state == null:
		result.issues.append("Week resolution requires a request and CampaignState.")
		return result
	var state: CampaignState = request.base_state
	if request.current_week != state.week_index:
		result.issues.append("resolve_week current_week must match CampaignState.")
	if request.situation_definition == null \
			or request.situation_definition.id != state.situation.definition_id:
		result.issues.append("Week resolution SituationDefinition does not match state.")
	result.issues.append_array(state.validate())
	if not result.issues.is_empty():
		return _clear_resolution(result)

	var accepted_offer := _accepted_offer(state)
	if request.skip_contract:
		if accepted_offer != null or state.active_plan != null:
			result.issues.append(
				"Explicit no-contract resolution cannot contain an accepted plan."
			)
	elif accepted_offer == null or state.active_plan == null:
		result.issues.append("Contract resolution requires one accepted Offer and plan.")
	if not request.skip_contract and request.planning_definitions == null:
		result.issues.append("Contract resolution requires detached planning definitions.")
	if not result.issues.is_empty():
		return _clear_resolution(result)

	var operations: Array[StateOperation] = []
	if not request.skip_contract:
		var definition: ContractDefinition = request.planning_definitions.contract_definitions.get(
			accepted_offer.definition_id
		)
		if definition == null:
			result.issues.append("Accepted Offer ContractDefinition is missing.")
			return _clear_resolution(result)
		var effective = ContractOfferService.build_effective_contract(
			accepted_offer,
			definition,
			request.planning_definitions.clauses,
			request.planning_definitions.method_tag_definitions
		)
		var plan := _build_contract_plan(state, request.planning_definitions, result.issues)
		if effective == null or plan == null or not result.issues.is_empty():
			result.issues.append("Accepted Offer could not produce locked resolver inputs.")
			return _clear_resolution(result)
		result.contract_resolve_result = ContractResolver.resolve(
			effective,
			plan,
			accepted_offer.locked_seed,
			state.guild.base_cohesion
		)
		if not result.contract_resolve_result.is_success():
			result.issues.append_array(result.contract_resolve_result.errors)
			return _clear_resolution(result)
		result.contract_projection_result = ContractResolutionProjector.project(
			state,
			result.contract_resolve_result.resolution,
			accepted_offer.sponsor_faction_id,
			accepted_offer.definition_id,
			accepted_offer.related_problem_id,
			state.active_plan.approach,
			accepted_offer
		)
		if not result.contract_projection_result.is_success():
			result.issues.append_array(result.contract_projection_result.issues)
			return _clear_resolution(result)
		operations.append_array(result.contract_projection_result.operations)
		result.reasons.append_array(
			result.contract_resolve_result.resolution.reason_entries
		)
		operations.append_array(_resolved_offer_operations(accepted_offer, state.week_index))

	result.action_resolution_result = FactionTurnPlanner.resolve_commitments(
		state,
		request.current_week,
		request.action_definitions
	)
	if not result.action_resolution_result.is_success():
		result.issues.append_array(result.action_resolution_result.issues)
		return _clear_resolution(result)
	operations.append_array(result.action_resolution_result.operations)
	result.reasons.append_array(result.action_resolution_result.reason_entries)

	var world_base := _world_operations(operations)
	result.post_world_result = SituationResolver.resolve_after_base_operations(
		request.current_week,
		request.situation_definition,
		state.situation,
		state.world_events,
		state.contract_history,
		world_base,
		SituationResolver.BOUNDARY_WEEK_END
	)
	if not result.post_world_result.is_success():
		result.issues.append_array(result.post_world_result.issues)
		return _clear_resolution(result)
	operations.append_array(result.post_world_result.operations)

	var transaction = CampaignTransaction.apply(state, operations)
	if not transaction.is_success():
		result.issues.append_array(transaction.issues)
		return _clear_resolution(result)
	result.operations = operations
	result.state_changes = transaction.state_changes
	result.new_state = transaction.new_state
	return _finalize_resolution_messages(request, result)


static func _plan_and_commit_opening(
	request: WeekOpeningRequest,
	result: WeekOpeningResult,
	base_operations: Array[StateOperation],
	planning_state: CampaignState,
	urgency_results: Array[ProblemUrgencyResult]
) -> WeekOpeningResult:
	var planning_request := FactionTurnPlanner.FactionPlanningRequest.create(
		planning_state,
		request.faction_definitions,
		request.contract_definitions,
		request.action_definitions,
		request.problem_definitions,
		urgency_results,
		request.declined_suppressions
	)
	result.planning_result = FactionTurnPlanner.plan_week(planning_request)
	if not result.planning_result.is_success():
		result.issues.append_array(result.planning_result.issues)
		return _clear_opening(result)
	var combined: Array[StateOperation] = []
	combined.append_array(base_operations)
	combined.append_array(result.planning_result.operations)
	var transaction = CampaignTransaction.apply(request.base_state, combined)
	if not transaction.is_success():
		result.issues.append_array(transaction.issues)
		return _clear_opening(result)
	result.operations = combined
	result.state_changes = transaction.state_changes
	result.reasons.append_array(result.planning_result.reason_entries)
	result.new_state = transaction.new_state
	return _finalize_opening_messages(request, result)


static func _finalize_opening_messages(
	request: WeekOpeningRequest,
	result: WeekOpeningResult
) -> WeekOpeningResult:
	result.message_requests = _opening_message_requests(request, result)
	result.message_projection_result = WeeklyMessageProjector.project_requests(
		result.new_state,
		result,
		result.message_requests
	)
	if not result.message_projection_result.is_success():
		result.issues.append_array(result.message_projection_result.issues)
		return _clear_opening(result)
	result.operations.append_array(result.message_projection_result.operations)
	var transaction = CampaignTransaction.apply(request.base_state, result.operations)
	if not transaction.is_success():
		result.issues.append_array(transaction.issues)
		return _clear_opening(result)
	result.generated_messages.assign(
		result.message_projection_result.created_messages
	)
	result.state_changes = transaction.state_changes
	result.new_state = transaction.new_state
	return result


static func _finalize_resolution_messages(
	request: WeekResolutionRequest,
	result: WeekResolution
) -> WeekResolution:
	result.message_requests = _resolution_message_requests(request, result)
	result.message_projection_result = WeeklyMessageProjector.project_requests(
		result.new_state,
		result,
		result.message_requests
	)
	if not result.message_projection_result.is_success():
		result.issues.append_array(result.message_projection_result.issues)
		return _clear_resolution(result)
	result.operations.append_array(result.message_projection_result.operations)
	var transaction = CampaignTransaction.apply(request.base_state, result.operations)
	if not transaction.is_success():
		result.issues.append_array(transaction.issues)
		return _clear_resolution(result)
	result.generated_messages.assign(
		result.message_projection_result.created_messages
	)
	result.state_changes = transaction.state_changes
	result.new_state = transaction.new_state
	return result


static func _opening_message_requests(
	request: WeekOpeningRequest,
	result: WeekOpeningResult
) -> Array[MessageRequest]:
	var messages: Array[MessageRequest] = []
	if result.upkeep_result != null:
		_append_message(messages, MessageRequest.create(
			MessageRequest.CATEGORY_UPKEEP,
			&"weekly_upkeep",
			&"weekly_upkeep",
			&"message_upkeep_title",
			&"message_upkeep_body",
			{
				"required": result.upkeep_result.required_upkeep,
				"paid": result.upkeep_result.paid,
				"shortfall": result.upkeep_result.shortfall,
				"reason_codes": _player_reason_codes(
					result.upkeep_result.reason_entries
				),
			},
			(
				MessageRequest.IMPORTANCE_HIGH
				if result.upkeep_result.shortfall > 0
				else MessageRequest.IMPORTANCE_NORMAL
			)
		))
		var member_reasons: Dictionary[StringName, Array] = {}
		for reason: ReasonEntry in result.upkeep_result.reason_entries:
			if reason.visibility != ReasonEntry.VISIBILITY_PLAYER \
					or not request.base_state.adventurers.has(reason.target_id):
				continue
			if not member_reasons.has(reason.target_id):
				member_reasons[reason.target_id] = []
			member_reasons[reason.target_id].append(reason)
		var member_ids: Array[StringName] = []
		member_ids.assign(member_reasons.keys())
		member_ids.sort()
		for member_id: StringName in member_ids:
			_append_message(messages, MessageRequest.create(
				MessageRequest.CATEGORY_UPKEEP,
				&"adventurer",
				member_id,
				&"message_member_upkeep_title",
				&"message_member_upkeep_body",
				{
					"member_id": member_id,
					"reason_codes": _player_reason_codes(member_reasons[member_id]),
				},
				MessageRequest.IMPORTANCE_NORMAL
			))
	if result.lifecycle_result != null:
		for offer: ContractOfferState in result.lifecycle_result.updated_offers:
			_append_message(messages, MessageRequest.create(
				MessageRequest.CATEGORY_CONTRACT_LIFECYCLE,
				&"contract_offer",
				offer.instance_id,
				&"message_contract_lifecycle_title",
				&"message_contract_lifecycle_body",
				{
					"status": offer.status,
					"reason_code": offer.terminal_reason_code,
				},
				MessageRequest.IMPORTANCE_HIGH
			))
	if result.planning_result != null:
		for offer: ContractOfferState in result.planning_result.new_offers:
			_append_message(messages, MessageRequest.create(
				MessageRequest.CATEGORY_CONTRACT_OFFER,
				&"contract_offer",
				offer.instance_id,
				&"message_contract_offer_title",
				&"message_contract_offer_body",
				{
					"sponsor_faction_id": offer.sponsor_faction_id,
					"origin_type": offer.origin_type,
					"reward": offer.offered_reward,
					"expires_week": offer.expires_week,
					"reason_codes": _player_reason_codes(
						offer.generation_reason_entries
					),
				},
				MessageRequest.IMPORTANCE_HIGH
			))
		for commitment in result.planning_result.new_commitments:
			_append_message(messages, MessageRequest.create(
				MessageRequest.CATEGORY_FACTION_ACTION,
				&"faction_action_commitment",
				commitment.instance_id,
				&"message_faction_action_committed_title",
				&"message_faction_action_committed_body",
				{
					"faction_id": commitment.faction_id,
					"action_id": commitment.action_definition_id,
					"problem_id": commitment.target_problem_id,
					"resolves_at_week": commitment.resolves_at_week,
					"reason_codes": _player_reason_codes(
						commitment.commitment_reason_entries
					),
				},
				MessageRequest.IMPORTANCE_NORMAL
			))
	_append_world_messages(
		messages,
		request.base_state,
		result.new_state,
		result,
		&"week_opening"
	)
	_append_message(messages, MessageRequest.create(
		MessageRequest.CATEGORY_WEEK_SUMMARY,
		&"week_opening",
		StringName("week_%d" % result.new_state.week_index),
		&"message_week_opening_summary_title",
		&"message_week_opening_summary_body",
		{"week_index": result.new_state.week_index},
		MessageRequest.IMPORTANCE_NORMAL
	))
	return messages


static func _resolution_message_requests(
	request: WeekResolutionRequest,
	result: WeekResolution
) -> Array[MessageRequest]:
	var messages: Array[MessageRequest] = []
	if result.contract_resolve_result != null:
		var resolution = result.contract_resolve_result.resolution
		var member_effects: Array[Dictionary] = []
		for outcome in resolution.member_outcomes:
			member_effects.append({
				"member_id": outcome.member_id,
				"fatigue_delta": outcome.fatigue_delta,
				"injury_result": outcome.injury_result,
				"morale_delta": outcome.morale_delta,
			})
		_append_message(messages, MessageRequest.create(
			MessageRequest.CATEGORY_CONTRACT_RESULT,
			&"contract",
			resolution.contract_instance_id,
			&"message_contract_result_title",
			&"message_contract_result_body",
			{
				"result_tier": resolution.result_tier,
				"reward": resolution.reward,
				"supply_cost": resolution.supply_cost_total,
				"member_effects": member_effects,
				"reason_codes": _player_reason_codes(resolution.reason_entries),
			},
			MessageRequest.IMPORTANCE_HIGH
		))
	if result.action_resolution_result != null:
		for commitment in result.action_resolution_result.updated_commitments:
			_append_message(messages, MessageRequest.create(
				MessageRequest.CATEGORY_FACTION_ACTION,
				&"faction_action_resolution",
				commitment.instance_id,
				&"message_faction_action_resolved_title",
				&"message_faction_action_resolved_body",
				{
					"faction_id": commitment.faction_id,
					"action_id": commitment.action_definition_id,
					"problem_id": commitment.target_problem_id,
					"world_event_ids": commitment.world_event_ids,
					"reason_codes": _player_reason_codes(
						commitment.commitment_reason_entries
					),
				},
				MessageRequest.IMPORTANCE_HIGH
			))
	_append_world_messages(
		messages,
		request.base_state,
		result.new_state,
		result,
		&"week_resolution"
	)
	_append_message(messages, MessageRequest.create(
		MessageRequest.CATEGORY_WEEK_SUMMARY,
		&"week_resolution",
		StringName("week_%d" % result.new_state.week_index),
		&"message_week_resolution_summary_title",
		&"message_week_resolution_summary_body",
		{"week_index": result.new_state.week_index},
		MessageRequest.IMPORTANCE_NORMAL
	))
	return messages


static func _append_world_messages(
	messages: Array[MessageRequest],
	base_state: CampaignState,
	new_state: CampaignState,
	source_result: Variant,
	boundary_source: StringName
) -> void:
	var known_events: Dictionary[StringName, bool] = {}
	for event in base_state.world_events:
		known_events[event.instance_id] = true
	for event in new_state.world_events:
		if known_events.has(event.instance_id):
			continue
		_append_message(messages, MessageRequest.create(
			MessageRequest.CATEGORY_WORLD_EVENT,
			&"world_event",
			event.instance_id,
			&"message_world_event_title",
			&"message_world_event_body",
			{
				"event_key": event.event_key,
				"problem_id": event.related_problem_id,
			},
			MessageRequest.IMPORTANCE_HIGH
		))
	var problem_ids: Array[StringName] = []
	problem_ids.assign(new_state.situation.problems.keys())
	problem_ids.sort()
	for problem_id: StringName in problem_ids:
		if not base_state.situation.problems.has(problem_id):
			continue
		var before_problem = base_state.situation.problems[problem_id]
		var after_problem = new_state.situation.problems[problem_id]
		if before_problem.status == after_problem.status \
				and before_problem.opened_week == after_problem.opened_week \
				and before_problem.response_deadline_week \
					== after_problem.response_deadline_week \
				and before_problem.closed_week == after_problem.closed_week \
				and before_problem.source_event_id == after_problem.source_event_id \
				and before_problem.resolution_reason_code \
					== after_problem.resolution_reason_code:
			continue
		_append_message(messages, MessageRequest.create(
			MessageRequest.CATEGORY_WORLD_EVENT,
			StringName("%s_problem_state" % boundary_source),
			problem_id,
			&"message_problem_changed_title",
			&"message_problem_changed_body",
			{
				"status": after_problem.status,
				"response_deadline_week": after_problem.response_deadline_week,
				"closed_week": after_problem.closed_week,
				"reason_code": after_problem.resolution_reason_code,
			},
			MessageRequest.IMPORTANCE_HIGH
		))
	var urgency_results: Array = []
	if source_result.get("post_world_result") != null:
		urgency_results = source_result.post_world_result.urgency_results
	for urgency in urgency_results:
		_append_message(messages, MessageRequest.create(
			MessageRequest.CATEGORY_WORLD_EVENT,
			StringName("%s_problem" % boundary_source),
			urgency.problem_id,
			&"message_problem_urgency_title",
			&"message_problem_urgency_body",
			{
				"band": urgency.band,
				"remaining_turns": urgency.remaining_turns,
				"reason_codes": _player_reason_codes(urgency.reason_entries),
			},
			(
				MessageRequest.IMPORTANCE_CRITICAL
				if urgency.band == ProblemUrgencyResult.BAND_CRITICAL
				else MessageRequest.IMPORTANCE_NORMAL
			)
		))
	if base_state.situation.phase_id != new_state.situation.phase_id \
			or base_state.situation.ending_id != new_state.situation.ending_id:
		_append_message(messages, MessageRequest.create(
			MessageRequest.CATEGORY_WORLD_EVENT,
			StringName("%s_situation" % boundary_source),
			new_state.situation.definition_id,
			&"message_situation_changed_title",
			&"message_situation_changed_body",
			{
				"phase_id": new_state.situation.phase_id,
				"ending_id": new_state.situation.ending_id,
			},
			(
				MessageRequest.IMPORTANCE_CRITICAL
				if not new_state.situation.ending_id.is_empty()
				else MessageRequest.IMPORTANCE_HIGH
			)
		))


static func _player_reason_codes(reasons: Array) -> Array[StringName]:
	var codes: Array[StringName] = []
	for value: Variant in reasons:
		var reason: ReasonEntry = value
		if reason != null \
				and reason.visibility == ReasonEntry.VISIBILITY_PLAYER \
				and not codes.has(reason.code):
			codes.append(reason.code)
		if codes.size() == 2:
			break
	return codes


static func _append_message(
	messages: Array[MessageRequest],
	message: MessageRequest
) -> void:
	if message != null:
		messages.append(message)


static func _initial_urgencies(
	current_week: int,
	state: CampaignState,
	problem_definitions: Array[WorldProblemDefinition]
) -> Array[ProblemUrgencyResult]:
	var results: Array[ProblemUrgencyResult] = []
	var definitions: Dictionary[StringName, WorldProblemDefinition] = {}
	for definition: WorldProblemDefinition in problem_definitions:
		if definition != null:
			definitions[definition.id] = definition
	var ids: Array[StringName] = []
	ids.assign(state.situation.problems.keys())
	ids.sort()
	for problem_id: StringName in ids:
		var problem: WorldProblemState = state.situation.problems[problem_id]
		if (
			problem.status != WorldProblemState.STATUS_ACTIVE
			or not definitions.has(problem_id)
		):
			continue
		var urgency := ProblemUrgencyCalculator.calculate(
			current_week,
			definitions[problem_id],
			problem,
			state.situation,
			state.world_events,
			state.contract_history
		)
		if urgency != null:
			results.append(urgency)
	return results


static func _accepted_offer(state: CampaignState) -> ContractOfferState:
	for offer: ContractOfferState in state.pending_contracts:
		if offer.status == ContractOfferState.STATUS_ACCEPTED:
			return offer
	return null


static func _build_contract_plan(
	state: CampaignState,
	definitions: ContractPlanningDefinitions,
	issues: PackedStringArray
) -> ContractPlan:
	var members: Array[AdventurerSnapshot] = []
	for member_id: StringName in state.active_plan.selected_member_ids:
		if (
			not state.adventurers.has(member_id)
			or not definitions.adventurer_definitions.has(member_id)
		):
			issues.append("Accepted plan references missing member %s." % member_id)
			continue
		var snapshot := AdventurerSnapshot.create(
			definitions.adventurer_definitions[member_id],
			state.adventurers[member_id]
		)
		if snapshot == null:
			issues.append("Accepted plan member snapshot failed for %s." % member_id)
		else:
			members.append(snapshot)
	var supplies: Array[SupplyDefinition] = []
	for supply_id: StringName in state.active_plan.selected_supply_ids:
		if not definitions.supply_definitions.has(supply_id):
			issues.append("Accepted plan references missing supply %s." % supply_id)
		else:
			supplies.append(definitions.supply_definitions[supply_id])
	if not issues.is_empty():
		return null
	return ContractPlan.create(members, supplies, state.active_plan.approach)


static func _resolved_offer_operations(
	offer: ContractOfferState,
	current_week: int
) -> Array[StateOperation]:
	return [
		StateOperation.create(
			CampaignTransaction.TARGET_CONTRACT_OFFER,
			offer.instance_id,
			CampaignTransaction.FIELD_STATUS,
			StateOperation.OP_SET_ID,
			ContractOfferState.STATUS_RESOLVED,
			REASON_OFFER_RESOLVED,
			SOURCE_OFFER_RESOLVED
		),
		StateOperation.create(
			CampaignTransaction.TARGET_CONTRACT_OFFER,
			offer.instance_id,
			CampaignTransaction.FIELD_RESOLVED_WEEK,
			StateOperation.OP_ADD_INT,
			current_week + 1,
			REASON_OFFER_RESOLVED,
			SOURCE_OFFER_RESOLVED + 1
		),
		StateOperation.create(
			CampaignTransaction.TARGET_CONTRACT_OFFER,
			offer.instance_id,
			CampaignTransaction.FIELD_TERMINAL_REASON_CODE,
			StateOperation.OP_SET_ID,
			REASON_OFFER_RESOLVED,
			REASON_OFFER_RESOLVED,
			SOURCE_OFFER_RESOLVED + 2
		),
		StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_ACTIVE_PLAN,
			StateOperation.OP_REMOVE_UNIQUE,
			offer.instance_id,
			REASON_OFFER_RESOLVED,
			SOURCE_OFFER_RESOLVED + 3
		),
		StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_PENDING_CONTRACTS,
			StateOperation.OP_REMOVE_UNIQUE,
			offer.instance_id,
			REASON_OFFER_RESOLVED,
			SOURCE_OFFER_RESOLVED + 4
		),
	]


static func _world_operations(
	operations: Array[StateOperation]
) -> Array[StateOperation]:
	var world: Array[StateOperation] = []
	for operation: StateOperation in operations:
		if [
			CampaignTransaction.TARGET_CLOCK,
			CampaignTransaction.TARGET_SITUATION,
			CampaignTransaction.TARGET_PROBLEM,
		].has(operation.target_kind):
			world.append(operation)
		elif (
			operation.target_kind == CampaignTransaction.TARGET_CAMPAIGN
			and [
				CampaignTransaction.FIELD_WORLD_EVENTS,
				CampaignTransaction.FIELD_CONTRACT_HISTORY,
			].has(operation.field_id)
		):
			world.append(operation)
	return world


static func _clear_opening(result: WeekOpeningResult) -> WeekOpeningResult:
	result.operations.clear()
	result.state_changes.clear()
	result.generated_messages.clear()
	result.new_state = null
	return result


static func _clear_resolution(result: WeekResolution) -> WeekResolution:
	result.operations.clear()
	result.state_changes.clear()
	result.generated_messages.clear()
	result.new_state = null
	return result
