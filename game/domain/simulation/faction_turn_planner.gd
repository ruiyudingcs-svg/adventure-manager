## Deterministic two-pass faction planner and delayed action projector.
class_name FactionTurnPlanner
extends RefCounted

const StableSeed = preload("res://game/core/random/stable_seed.gd")
const StateOperation = preload("res://game/core/result/state_operation.gd")
const StateChange = preload("res://game/core/result/state_change.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const WorldConditionEvaluator = preload(
	"res://game/domain/situations/world_condition_evaluator.gd"
)
const FactionDefinition = preload(
	"res://game/domain/factions/faction_definition.gd"
)
const FactionActionDefinition = preload(
	"res://game/domain/factions/faction_action_definition.gd"
)
const FactionActionCommitmentState = preload(
	"res://game/domain/factions/faction_action_commitment_state.gd"
)
const FactionIntentCandidate = preload(
	"res://game/domain/factions/faction_intent_candidate.gd"
)
const FactionIntentPlan = preload(
	"res://game/domain/factions/faction_intent_plan.gd"
)
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const DeclinedOfferSuppressionKey = preload(
	"res://game/domain/contracts/declined_offer_suppression_key.gd"
)
const CreateContractOfferRequest = preload(
	"res://game/domain/contracts/create_contract_offer_request.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
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
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

const REASON_BASE: StringName = &"faction_intent_base_priority"
const REASON_URGENCY: StringName = &"faction_intent_urgency"
const REASON_AGENDA: StringName = &"faction_intent_agenda_fit"
const REASON_REPEAT: StringName = &"faction_intent_repeat_penalty"
const REASON_CONTRACT_SELECTED: StringName = &"faction_contract_selected"
const REASON_ACTION_SELECTED: StringName = &"faction_action_selected"
const REASON_ACTION_WAITED: StringName = &"faction_action_waited"
const REASON_REUSED_DECLINED: StringName = &"declined_offer_reused_no_alternative"
const REASON_ACTION_RESOLVED: StringName = &"faction_action_resolved"
const REASON_INFLUENCE_RESERVED: StringName = &"faction_action_influence_reserved"

const SOURCE_COMMITMENT: int = 1000
const SOURCE_ACTION_EFFECT: int = 1100
const SOURCE_ACTION_EVENT: int = 1200
const SOURCE_ACTION_RESOLUTION: int = 1300


## Detached inputs for one planning snapshot.
class FactionPlanningRequest extends RefCounted:
	var base_state: CampaignState
	var faction_definitions: Array[FactionDefinition]
	var contract_definitions: Array[ContractDefinition]
	var action_definitions: Array[FactionActionDefinition]
	var problem_definitions: Array[WorldProblemDefinition]
	var urgency_results: Array[ProblemUrgencyResult]
	var declined_suppressions: Array[DeclinedOfferSuppressionKey]

	static func create(
		p_base_state: CampaignState,
		p_faction_definitions: Array[FactionDefinition],
		p_contract_definitions: Array[ContractDefinition],
		p_action_definitions: Array[FactionActionDefinition],
		p_problem_definitions: Array[WorldProblemDefinition],
		p_urgency_results: Array[ProblemUrgencyResult],
		p_declined_suppressions: Array[DeclinedOfferSuppressionKey] = []
	) -> FactionPlanningRequest:
		return FactionPlanningRequest.new(
			p_base_state,
			p_faction_definitions,
			p_contract_definitions,
			p_action_definitions,
			p_problem_definitions,
			p_urgency_results,
			p_declined_suppressions
		)

	func _init(
		p_base_state: CampaignState,
		p_faction_definitions: Array[FactionDefinition],
		p_contract_definitions: Array[ContractDefinition],
		p_action_definitions: Array[FactionActionDefinition],
		p_problem_definitions: Array[WorldProblemDefinition],
		p_urgency_results: Array[ProblemUrgencyResult],
		p_declined_suppressions: Array[DeclinedOfferSuppressionKey]
	) -> void:
		base_state = p_base_state.duplicate_state() if p_base_state != null else null
		for value: FactionDefinition in p_faction_definitions:
			faction_definitions.append(value.duplicate_value() if value != null else null)
		for value: ContractDefinition in p_contract_definitions:
			contract_definitions.append(value.duplicate_value() if value != null else null)
		for value: FactionActionDefinition in p_action_definitions:
			action_definitions.append(value.duplicate_value() if value != null else null)
		for value: WorldProblemDefinition in p_problem_definitions:
			problem_definitions.append(value.duplicate_value() if value != null else null)
		for value: ProblemUrgencyResult in p_urgency_results:
			urgency_results.append(value.duplicate_value() if value != null else null)
		for value: DeclinedOfferSuppressionKey in p_declined_suppressions:
			declined_suppressions.append(value.duplicate_value() if value != null else null)


class FactionPlanningResult extends RefCounted:
	var plans: Array[FactionIntentPlan]
	var candidates: Array[FactionIntentCandidate]
	var new_offers: Array[ContractOfferState]
	var new_commitments: Array[FactionActionCommitmentState]
	var operations: Array[StateOperation]
	var reason_entries: Array[ReasonEntry]
	var state_changes: Array[StateChange]
	var new_state: CampaignState
	var issues: PackedStringArray

	func is_success() -> bool:
		return new_state != null and issues.is_empty()


class FactionActionResolutionResult extends RefCounted:
	var updated_commitments: Array[FactionActionCommitmentState]
	var world_events: Array[WorldEventState]
	var operations: Array[StateOperation]
	var reason_entries: Array[ReasonEntry]
	var issues: PackedStringArray

	func is_success() -> bool:
		return issues.is_empty()


## Plans all factions against one immutable snapshot and atomically reserves
## every selected target and influence cost.
static func plan_week(request: FactionPlanningRequest) -> FactionPlanningResult:
	var result := FactionPlanningResult.new()
	if request == null or request.base_state == null:
		result.issues.append("FactionTurnPlanner requires a planning request and state.")
		return result
	var base_state: CampaignState = request.base_state
	result.issues.append_array(base_state.validate())
	if not result.issues.is_empty():
		return result
	if not base_state.situation.ending_id.is_empty():
		result.new_state = base_state.duplicate_state()
		return result

	var faction_map := _definition_map(request.faction_definitions)
	var contract_map := _definition_map(request.contract_definitions)
	var action_map := _definition_map(request.action_definitions)
	var problem_map := _definition_map(request.problem_definitions)
	var urgency_map := _definition_map(request.urgency_results, &"problem_id")
	if (
		faction_map.size() != request.faction_definitions.size()
		or contract_map.size() != request.contract_definitions.size()
		or action_map.size() != request.action_definitions.size()
		or problem_map.size() != request.problem_definitions.size()
		or urgency_map.size() != request.urgency_results.size()
	):
		result.issues.append("Planning definitions contain null or duplicate IDs.")
		return result
	for faction_id: StringName in base_state.factions:
		if not faction_map.has(faction_id):
			result.issues.append("Missing faction definition %s." % faction_id)
	for faction_definition: FactionDefinition in request.faction_definitions:
		for action_id: StringName in faction_definition.weekly_action_ids:
			if not action_map.has(action_id):
				result.issues.append(
					"Faction %s references missing action %s."
					% [faction_definition.id, action_id]
				)
	for contract: ContractDefinition in request.contract_definitions:
		if not faction_map.has(contract.sponsor_faction_id):
			result.issues.append(
				"Contract %s references missing sponsor %s."
				% [contract.id, contract.sponsor_faction_id]
			)
		if not contract.related_problem_id.is_empty() \
				and not problem_map.has(contract.related_problem_id):
			result.issues.append(
				"Contract %s references missing problem %s."
				% [contract.id, contract.related_problem_id]
			)
	for problem_id: StringName in base_state.situation.problems:
		if not problem_map.has(problem_id):
			result.issues.append("Missing problem definition %s." % problem_id)
		elif base_state.situation.problems[problem_id].status == \
				WorldProblemState.STATUS_ACTIVE \
				and not urgency_map.has(problem_id):
			result.issues.append("Missing urgency result for active problem %s." % problem_id)
	if not result.issues.is_empty():
		return result

	var starting_pending: Dictionary[StringName, ContractOfferState] = {}
	var locks: Dictionary[StringName, bool] = {}
	var working_offers: Array[ContractOfferState] = []
	for offer: ContractOfferState in base_state.pending_contracts:
		working_offers.append(offer.duplicate_state())
		if (
			offer.status == ContractOfferState.STATUS_PENDING
			or offer.status == ContractOfferState.STATUS_ACCEPTED
		):
			locks[offer.target_lock_key] = true
		if offer.status == ContractOfferState.STATUS_PENDING:
			starting_pending[offer.sponsor_faction_id] = offer
	for commitment: FactionActionCommitmentState in \
			base_state.faction_action_commitments:
		if commitment.status == FactionActionCommitmentState.STATUS_COMMITTED:
			locks[commitment.target_lock_key] = true

	var faction_ids: Array[StringName] = []
	faction_ids.assign(base_state.factions.keys())
	faction_ids.sort()

	# Pass one fills every empty contract column before any action can reserve a lock.
	for faction_id: StringName in faction_ids:
		if starting_pending.has(faction_id):
			continue
		var definition: FactionDefinition = faction_map[faction_id]
		var candidates := _contract_candidates(
			base_state,
			definition,
			contract_map,
			problem_map,
			urgency_map
		)
		result.candidates.append_array(_duplicate_candidates(candidates))
		var selected := _select_contract_candidate(
			candidates,
			locks,
			request.declined_suppressions
		)
		if selected == null:
			result.issues.append(
				"faction_offer_missing: %s has no legal contract proposal."
				% faction_id
			)
			return _fail_planning(result)
		var selected_reasons: Array[ReasonEntry] = _copy_reasons(selected.reason_entries)
		if _is_suppressed(selected, request.declined_suppressions):
			selected_reasons.append(_reason(
				REASON_REUSED_DECLINED,
				selected.source_definition_id,
				faction_id,
				0.0,
				ReasonEntry.VISIBILITY_PLAYER
			))
		var contract: ContractDefinition = contract_map[selected.source_definition_id]
		var urgency: ProblemUrgencyResult = (
			urgency_map.get(selected.target_problem_id)
			if not selected.target_problem_id.is_empty()
			else null
		)
		var create_request := CreateContractOfferRequest.create(
			contract,
			base_state.week_index,
			selected.origin_type,
			selected.target_problem_id,
			base_state.factions[faction_id].relation,
			base_state.campaign_seed,
			base_state.situation,
			base_state.world_events,
			urgency,
			selected_reasons,
			working_offers
		)
		var offer_result = ContractOfferService.create_offer(create_request)
		if not offer_result.is_success():
			result.issues.append_array(offer_result.issues)
			return _fail_planning(result)
		result.operations.append_array(offer_result.operations)
		result.new_offers.append(offer_result.created_offer.duplicate_state())
		result.reason_entries.append_array(_copy_reasons(selected_reasons))
		working_offers.append(offer_result.created_offer.duplicate_state())
		locks[selected.target_lock_key] = true
		result.plans.append(FactionIntentPlan.create(
			faction_id,
			base_state.week_index,
			FactionIntentCandidate.MODE_CONTRACT_PROPOSAL,
			selected.id,
			selected.target_lock_key,
			selected_reasons
		))

	# Pass two only considers factions that already had pending offers at snapshot time.
	var action_source_index := 0
	for faction_id: StringName in faction_ids:
		if not starting_pending.has(faction_id):
			continue
		var definition: FactionDefinition = faction_map[faction_id]
		var candidates := _action_candidates(
			base_state,
			definition,
			action_map,
			problem_map,
			urgency_map
		)
		result.candidates.append_array(_duplicate_candidates(candidates))
		var selected := _select_candidate(candidates, locks)
		if selected == null:
			var waited := _reason(
				REASON_ACTION_WAITED,
				faction_id,
				faction_id,
				0.0,
				ReasonEntry.VISIBILITY_PLAYER
			)
			result.reason_entries.append(waited)
			result.plans.append(FactionIntentPlan.create(
				faction_id,
				base_state.week_index,
				FactionIntentCandidate.MODE_DIRECT_ACTION,
				&"",
				&"",
				[waited]
			))
			continue
		var action: FactionActionDefinition = action_map[
			selected.source_definition_id
		]
		var commitment_id := _commitment_id(
			base_state.week_index,
			faction_id,
			action.id,
			selected.target_problem_id,
			action.target_lock_key
		)
		if _commitment_exists(base_state, commitment_id):
			result.issues.append(
				"Faction action commitment ID collision: %s." % commitment_id
			)
			return _fail_planning(result)
		var reasons: Array[ReasonEntry] = _copy_reasons(selected.reason_entries)
		var commitment := FactionActionCommitmentState.create(
			commitment_id,
			faction_id,
			action.id,
			selected.target_problem_id,
			action.target_lock_key,
			base_state.week_index,
			action.influence_cost,
			reasons
		)
		if commitment == null:
			result.issues.append("Selected faction action produced invalid commitment state.")
			return _fail_planning(result)
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_FACTION_ACTION_COMMITMENTS,
			StateOperation.OP_APPEND_RECORD,
			commitment,
			REASON_ACTION_SELECTED,
			SOURCE_COMMITMENT + action_source_index
		))
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_FACTION,
			faction_id,
			CampaignTransaction.FIELD_INFLUENCE,
			StateOperation.OP_ADD_INT,
			-action.influence_cost,
			REASON_INFLUENCE_RESERVED,
			SOURCE_COMMITMENT + action_source_index
		))
		result.new_commitments.append(commitment.duplicate_state())
		result.reason_entries.append_array(_copy_reasons(reasons))
		result.plans.append(FactionIntentPlan.create(
			faction_id,
			base_state.week_index,
			FactionIntentCandidate.MODE_DIRECT_ACTION,
			selected.id,
			selected.target_lock_key,
			reasons
		))
		locks[selected.target_lock_key] = true
		action_source_index += 1

	var transaction = CampaignTransaction.apply(base_state, result.operations)
	if not transaction.is_success():
		result.issues.append_array(transaction.issues)
		return _fail_planning(result)
	result.new_state = transaction.new_state
	result.state_changes = transaction.state_changes
	return result


## Projects every action due at the end of current_week. The caller (Task011)
## merges these operations with contract effects and the week-index advance.
static func resolve_commitments(
	base_state: CampaignState,
	current_week: int,
	action_definitions: Array[FactionActionDefinition]
) -> FactionActionResolutionResult:
	var result := FactionActionResolutionResult.new()
	if base_state == null or current_week < 0:
		result.issues.append("Action resolution requires a state and non-negative week.")
		return result
	var action_map := _definition_map(action_definitions)
	if action_map.size() != action_definitions.size():
		result.issues.append("Action definitions contain null or duplicate IDs.")
		return result
	var commitments: Array[FactionActionCommitmentState] = []
	for value: FactionActionCommitmentState in base_state.faction_action_commitments:
		if (
			value.status == FactionActionCommitmentState.STATUS_COMMITTED
			and value.resolves_at_week == current_week + 1
		):
			commitments.append(value.duplicate_state())
	commitments.sort_custom(_commitment_less)
	for index: int in range(commitments.size()):
		var commitment: FactionActionCommitmentState = commitments[index]
		if not action_map.has(commitment.action_definition_id):
			result.issues.append(
				"Missing action definition %s." % commitment.action_definition_id
			)
			return _clear_action_resolution(result)
		var action: FactionActionDefinition = action_map[
			commitment.action_definition_id
		]
		var projected_effect_operations: Variant = _project_action_effects(
			action.effects,
			base_state.situation.definition_id,
			SOURCE_ACTION_EFFECT + index * 20
		)
		if projected_effect_operations == null:
			result.issues.append(
				"Faction action %s has unsupported effects." % action.id
			)
			return _clear_action_resolution(result)
		var effect_operations: Array[StateOperation] = []
		effect_operations.assign(projected_effect_operations)
		result.operations.append_array(effect_operations)
		var event_id := StringName("%s_%s" % [
			commitment.instance_id,
			action.event_key,
		])
		var reason_codes: Array[StringName] = []
		for effect: WorldEffect in action.effects:
			if not reason_codes.has(effect.reason_code):
				reason_codes.append(effect.reason_code)
		reason_codes.sort()
		if reason_codes.is_empty():
			reason_codes.append(REASON_ACTION_RESOLVED)
		var event := WorldEventState.create(
			event_id,
			action.event_key,
			current_week + 1,
			commitment.instance_id,
			commitment.target_problem_id,
			reason_codes
		)
		if event == null:
			result.issues.append("Could not create faction action world event.")
			return _clear_action_resolution(result)
		result.world_events.append(event.duplicate_state())
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_WORLD_EVENTS,
			StateOperation.OP_APPEND_RECORD,
			event,
			reason_codes[0],
			SOURCE_ACTION_EVENT + index
		))
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_FACTION_ACTION_COMMITMENT,
			commitment.instance_id,
			CampaignTransaction.FIELD_STATUS,
			StateOperation.OP_SET_ID,
			FactionActionCommitmentState.STATUS_RESOLVED,
			REASON_ACTION_RESOLVED,
			SOURCE_ACTION_RESOLUTION + index
		))
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_FACTION_ACTION_COMMITMENT,
			commitment.instance_id,
			CampaignTransaction.FIELD_RESOLVED_WEEK,
			StateOperation.OP_ADD_INT,
			commitment.resolves_at_week + 1,
			REASON_ACTION_RESOLVED,
			SOURCE_ACTION_RESOLUTION + index
		))
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_FACTION_ACTION_COMMITMENT,
			commitment.instance_id,
			CampaignTransaction.FIELD_WORLD_EVENT_IDS,
			StateOperation.OP_ADD_UNIQUE,
			event_id,
			REASON_ACTION_RESOLVED,
			SOURCE_ACTION_RESOLUTION + index
		))
		commitment.status = FactionActionCommitmentState.STATUS_RESOLVED
		commitment.resolved_week = commitment.resolves_at_week
		commitment.world_event_ids.append(event_id)
		result.updated_commitments.append(commitment)
		result.reason_entries.append(_reason(
			REASON_ACTION_RESOLVED,
			action.id,
			commitment.target_problem_id,
			0.0,
			ReasonEntry.VISIBILITY_PLAYER
		))
	return result


static func _contract_candidates(
	state: CampaignState,
	faction: FactionDefinition,
	contract_map: Dictionary,
	problem_map: Dictionary,
	urgency_map: Dictionary
) -> Array[FactionIntentCandidate]:
	var result: Array[FactionIntentCandidate] = []
	var definition_ids: Array[StringName] = []
	definition_ids.assign(contract_map.keys())
	definition_ids.sort()
	for definition_id: StringName in definition_ids:
		var definition: ContractDefinition = contract_map[definition_id]
		if definition.sponsor_faction_id != faction.id:
			continue
		var origin: StringName = &""
		var target_problem_id: StringName = &""
		var active_problem_ids: Array[StringName] = []
		var problem_ids: Array[StringName] = []
		problem_ids.assign(state.situation.problems.keys())
		problem_ids.sort()
		for problem_id: StringName in problem_ids:
			var problem_state: WorldProblemState = state.situation.problems[problem_id]
			if problem_state.status != WorldProblemState.STATUS_ACTIVE \
				or not problem_map.has(problem_id):
				continue
			var problem: WorldProblemDefinition = problem_map[problem_id]
			if problem.contract_definition_ids.has(definition.id) \
				and definition.related_problem_id == problem_id:
				active_problem_ids.append(problem_id)
		if not active_problem_ids.is_empty():
			origin = ContractOfferState.ORIGIN_PROBLEM
			target_problem_id = active_problem_ids[0]
		elif state.situation.unlocked_contract_ids.has(definition.id):
			origin = ContractOfferState.ORIGIN_FOLLOWUP
		elif definition.allow_agenda_origin \
				and definition.repeat_policy == &"repeatable":
			origin = ContractOfferState.ORIGIN_AGENDA
		else:
			continue

		var rejection_codes := _contract_rejection_codes(
			state,
			definition,
			origin,
			target_problem_id
		)
		var agenda_fit := _agenda_fit(definition.agenda_tags, faction)
		if origin == ContractOfferState.ORIGIN_AGENDA and agenda_fit <= 0:
			rejection_codes.append(&"agenda_fit_not_positive")
		var urgency_contribution := 0
		if origin == ContractOfferState.ORIGIN_PROBLEM:
			if not urgency_map.has(target_problem_id):
				rejection_codes.append(&"problem_urgency_missing")
			else:
				var urgency: ProblemUrgencyResult = urgency_map[target_problem_id]
				urgency_contribution = roundi(
					float(urgency.score * definition.urgency_weight) / 100.0
				)
		var repeat_penalty := _repeat_penalty(
			state.week_index,
			definition.recent_repeat_cooldown,
			_last_contract_offered_week(state, definition.id)
		)
		var reasons := _priority_reasons(
			definition.id,
			target_problem_id if not target_problem_id.is_empty() else faction.id,
			definition.proposal_base_priority,
			urgency_contribution,
			agenda_fit,
			repeat_penalty
		)
		var total := (
			definition.proposal_base_priority
			+ urgency_contribution
			+ agenda_fit
			- repeat_penalty
		)
		if total <= 0:
			rejection_codes.append(&"intent_priority_not_positive")
		var candidate_id := _candidate_id(
			state.week_index,
			faction.id,
			FactionIntentCandidate.MODE_CONTRACT_PROPOSAL,
			definition.id,
			origin,
			target_problem_id
		)
		result.append(FactionIntentCandidate.create(
			candidate_id,
			faction.id,
			state.week_index,
			FactionIntentCandidate.MODE_CONTRACT_PROPOSAL,
			definition.id,
			origin,
			target_problem_id,
			definition.target_lock_key,
			definition.agenda_tags,
			definition.proposal_base_priority,
			urgency_contribution,
			agenda_fit,
			repeat_penalty,
			0,
			rejection_codes.is_empty(),
			rejection_codes,
			reasons
		))
	result.sort_custom(_candidate_less)
	return result


static func _action_candidates(
	state: CampaignState,
	faction: FactionDefinition,
	action_map: Dictionary,
	problem_map: Dictionary,
	urgency_map: Dictionary
) -> Array[FactionIntentCandidate]:
	var result: Array[FactionIntentCandidate] = []
	var action_ids: Array[StringName] = faction.weekly_action_ids.duplicate()
	action_ids.sort()
	var problem_ids: Array[StringName] = []
	problem_ids.assign(state.situation.problems.keys())
	problem_ids.sort()
	for action_id: StringName in action_ids:
		if not action_map.has(action_id):
			continue
		var action: FactionActionDefinition = action_map[action_id]
		for problem_id: StringName in problem_ids:
			var problem_state: WorldProblemState = state.situation.problems[problem_id]
			if problem_state.status != WorldProblemState.STATUS_ACTIVE \
				or not problem_map.has(problem_id):
				continue
			var problem: WorldProblemDefinition = problem_map[problem_id]
			if not _tags_cover(problem.problem_tags, action.target_problem_tags):
				continue
			var rejection_codes: Array[StringName] = []
			for condition in action.conditions:
				if not WorldConditionEvaluator.is_met(
					condition,
					state.week_index,
					state.situation,
					state.world_events,
					state.contract_history
				):
					rejection_codes.append(&"action_condition_not_met")
					break
			if state.factions[faction.id].influence < action.influence_cost:
				rejection_codes.append(&"action_insufficient_influence")
			if not urgency_map.has(problem_id):
				rejection_codes.append(&"problem_urgency_missing")
			var urgency_contribution := 0
			if urgency_map.has(problem_id):
				var urgency: ProblemUrgencyResult = urgency_map[problem_id]
				urgency_contribution = roundi(
					float(urgency.score * action.urgency_weight) / 100.0
				)
			var agenda_fit := _agenda_fit(action.agenda_tags, faction)
			var repeat_penalty := _repeat_penalty(
				state.week_index,
				action.recent_repeat_cooldown,
				_last_action_committed_week(state, action.id)
			)
			var total := (
				action.base_intent_priority
				+ urgency_contribution
				+ agenda_fit
				- repeat_penalty
			)
			if total <= 0:
				rejection_codes.append(&"intent_priority_not_positive")
			var reasons := _priority_reasons(
				action.id,
				problem_id,
				action.base_intent_priority,
				urgency_contribution,
				agenda_fit,
				repeat_penalty
			)
			result.append(FactionIntentCandidate.create(
				_candidate_id(
					state.week_index,
					faction.id,
					FactionIntentCandidate.MODE_DIRECT_ACTION,
					action.id,
					&"",
					problem_id
				),
				faction.id,
				state.week_index,
				FactionIntentCandidate.MODE_DIRECT_ACTION,
				action.id,
				&"",
				problem_id,
				action.target_lock_key,
				action.agenda_tags,
				action.base_intent_priority,
				urgency_contribution,
				agenda_fit,
				repeat_penalty,
				action.influence_cost,
				rejection_codes.is_empty(),
				rejection_codes,
				reasons
			))
	result.sort_custom(_candidate_less)
	return result


static func _contract_rejection_codes(
	state: CampaignState,
	definition: ContractDefinition,
	origin: StringName,
	target_problem_id: StringName
) -> Array[StringName]:
	var result: Array[StringName] = []
	var unlocked: bool = definition.starts_unlocked \
		or state.situation.unlocked_contract_ids.has(definition.id)
	if not unlocked:
		result.append(&"contract_not_unlocked")
	if state.guild.reputation < definition.min_reputation:
		result.append(&"contract_reputation_too_low")
	for prerequisite_id: StringName in definition.prerequisite_contract_ids:
		if not _contract_completed(state, prerequisite_id):
			result.append(&"contract_prerequisite_missing")
	for exclusive_id: StringName in definition.exclusive_contract_ids:
		if _contract_completed(state, exclusive_id):
			result.append(&"contract_exclusive_completed")
	if definition.repeat_policy == &"once_per_campaign" \
			and _contract_completed(state, definition.id):
		result.append(&"contract_already_completed")
	for rule in definition.availability_rules:
		if not WorldConditionEvaluator.rule_matches(
			rule,
			state.week_index,
			state.situation,
			state.world_events,
			state.contract_history
		):
			result.append(&"contract_availability_not_met")
	if origin == ContractOfferState.ORIGIN_PROBLEM:
		if target_problem_id.is_empty() \
				or not state.situation.problems.has(target_problem_id) \
				or state.situation.problems[target_problem_id].status != \
					WorldProblemState.STATUS_ACTIVE:
			result.append(&"contract_problem_not_active")
	return result


static func _select_contract_candidate(
	candidates: Array[FactionIntentCandidate],
	locks: Dictionary[StringName, bool],
	suppressions: Array[DeclinedOfferSuppressionKey]
) -> FactionIntentCandidate:
	var fallback: FactionIntentCandidate
	for candidate: FactionIntentCandidate in candidates:
		if not candidate.eligible or locks.has(candidate.target_lock_key):
			continue
		if not _is_suppressed(candidate, suppressions):
			return candidate
		if fallback == null:
			fallback = candidate
	return fallback


static func _select_candidate(
	candidates: Array[FactionIntentCandidate],
	locks: Dictionary[StringName, bool]
) -> FactionIntentCandidate:
	for candidate: FactionIntentCandidate in candidates:
		if candidate.eligible and not locks.has(candidate.target_lock_key):
			return candidate
	return null


static func _is_suppressed(
	candidate: FactionIntentCandidate,
	suppressions: Array[DeclinedOfferSuppressionKey]
) -> bool:
	for key: DeclinedOfferSuppressionKey in suppressions:
		if (
			key.definition_id == candidate.source_definition_id
			and key.origin_type == candidate.origin_type
			and key.related_problem_id == candidate.target_problem_id
			and key.target_lock_key == candidate.target_lock_key
		):
			return true
	return false


static func _agenda_fit(
	tags: Array[StringName],
	faction: FactionDefinition
) -> int:
	var weights: Dictionary[StringName, int] = {}
	for item in faction.agenda_weights:
		weights[item.tag] = item.weight
	var total := 0
	for tag: StringName in tags:
		total += weights.get(tag, 0)
	return clampi(total, -30, 30)


## The documented repeat formula rounds once after the division.
static func _repeat_penalty(
	current_week: int,
	cooldown: int,
	last_week: int
) -> int:
	if cooldown <= 0 or last_week < 0:
		return 0
	var remaining := maxi(0, cooldown - (current_week - last_week))
	return roundi(20.0 * float(remaining) / float(cooldown))


static func _last_contract_offered_week(
	state: CampaignState,
	definition_id: StringName
) -> int:
	var last_week := -1
	for offer: ContractOfferState in state.pending_contracts:
		if offer.definition_id == definition_id:
			last_week = maxi(last_week, offer.offered_week)
	for entry: ContractHistoryEntry in state.contract_history:
		if entry.contract_definition_id == definition_id:
			last_week = maxi(last_week, entry.offered_week)
	return last_week


static func _last_action_committed_week(
	state: CampaignState,
	definition_id: StringName
) -> int:
	var last_week := -1
	for commitment: FactionActionCommitmentState in \
			state.faction_action_commitments:
		if commitment.action_definition_id == definition_id:
			last_week = maxi(last_week, commitment.committed_week)
	return last_week


static func _contract_completed(
	state: CampaignState,
	definition_id: StringName
) -> bool:
	for entry: ContractHistoryEntry in state.contract_history:
		if entry.contract_definition_id == definition_id \
				and entry.terminal_status in [
					ContractHistoryEntry.STATUS_RESOLVED,
					ContractHistoryEntry.STATUS_NPC_COMPLETED,
				]:
			return true
	return false


static func _priority_reasons(
	source_id: StringName,
	target_id: StringName,
	base_priority: int,
	urgency: int,
	agenda: int,
	repeat: int
) -> Array[ReasonEntry]:
	var result: Array[ReasonEntry] = [
		_reason(REASON_BASE, source_id, target_id, float(base_priority),
			ReasonEntry.VISIBILITY_DEBUG),
	]
	if urgency != 0:
		result.append(_reason(REASON_URGENCY, source_id, target_id, float(urgency),
			ReasonEntry.VISIBILITY_PLAYER))
	if agenda != 0:
		result.append(_reason(REASON_AGENDA, source_id, target_id, float(agenda),
			ReasonEntry.VISIBILITY_PLAYER))
	if repeat != 0:
		result.append(_reason(REASON_REPEAT, source_id, target_id, float(-repeat),
			ReasonEntry.VISIBILITY_DEBUG))
	return result


static func _project_action_effects(
	effects: Array[WorldEffect],
	situation_id: StringName,
	source_order: int
) -> Variant:
	var result: Array[StateOperation] = []
	for index: int in range(effects.size()):
		var effect: WorldEffect = effects[index]
		match effect.type:
			&"modify_clock":
				result.append(StateOperation.create(
					CampaignTransaction.TARGET_CLOCK,
					effect.target_id,
					CampaignTransaction.FIELD_VALUE,
					StateOperation.OP_ADD_INT,
					effect.amount,
					effect.reason_code,
					source_order + index
				))
			&"change_phase":
				result.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					situation_id,
					CampaignTransaction.FIELD_PHASE_ID,
					StateOperation.OP_SET_ID,
					effect.target_id,
					effect.reason_code,
					source_order + index
				))
			&"unlock_contract":
				result.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					situation_id,
					CampaignTransaction.FIELD_UNLOCKED_CONTRACT_IDS,
					StateOperation.OP_ADD_UNIQUE,
					effect.target_id,
					effect.reason_code,
					source_order + index
				))
			&"set_ending":
				result.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					situation_id,
					CampaignTransaction.FIELD_ENDING_ID,
					StateOperation.OP_SET_ID,
					effect.target_id,
					effect.reason_code,
					source_order + index
				))
			_:
				return null
	return result


static func _tags_cover(
	source_tags: Array[StringName],
	required_tags: Array[StringName]
) -> bool:
	for tag: StringName in required_tags:
		if not source_tags.has(tag):
			return false
	return true


static func _definition_map(
	definitions: Array,
	id_field: StringName = &"id"
) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in definitions:
		if value == null:
			continue
		var id: StringName = value.get(String(id_field))
		if result.has(id):
			return {}
		result[id] = value
	return result


static func _candidate_id(
	week: int,
	faction_id: StringName,
	mode: StringName,
	definition_id: StringName,
	origin: StringName,
	problem_id: StringName
) -> StringName:
	var digest := StableSeed.derive(0, [
		&"faction_intent",
		StringName(str(week)),
		faction_id,
		mode,
		definition_id,
		origin,
		problem_id,
	])
	return StringName("faction_intent_%08x" % digest)


static func _commitment_id(
	week: int,
	faction_id: StringName,
	action_id: StringName,
	problem_id: StringName,
	target_lock: StringName
) -> StringName:
	var digest := StableSeed.derive(0, [
		&"faction_action_commitment",
		StringName(str(week)),
		faction_id,
		action_id,
		problem_id,
		target_lock,
	])
	return StringName("faction_action_%08x" % digest)


static func _commitment_exists(
	state: CampaignState,
	instance_id: StringName
) -> bool:
	for value: FactionActionCommitmentState in state.faction_action_commitments:
		if value.instance_id == instance_id:
			return true
	return false


static func _candidate_less(
	left: FactionIntentCandidate,
	right: FactionIntentCandidate
) -> bool:
	if left.total_priority != right.total_priority:
		return left.total_priority > right.total_priority
	if left.base_priority != right.base_priority:
		return left.base_priority > right.base_priority
	if left.source_definition_id != right.source_definition_id:
		return String(left.source_definition_id) < String(right.source_definition_id)
	return String(left.target_problem_id) < String(right.target_problem_id)


static func _commitment_less(
	left: FactionActionCommitmentState,
	right: FactionActionCommitmentState
) -> bool:
	if left.committed_week != right.committed_week:
		return left.committed_week < right.committed_week
	if left.faction_id != right.faction_id:
		return String(left.faction_id) < String(right.faction_id)
	return String(left.instance_id) < String(right.instance_id)


static func _duplicate_candidates(
	values: Array[FactionIntentCandidate]
) -> Array[FactionIntentCandidate]:
	var result: Array[FactionIntentCandidate] = []
	for value: FactionIntentCandidate in values:
		result.append(value.duplicate_value())
	return result


static func _copy_reasons(values: Array[ReasonEntry]) -> Array[ReasonEntry]:
	var result: Array[ReasonEntry] = []
	for value: ReasonEntry in values:
		result.append(value.duplicate_value())
	return result


static func _reason(
	code: StringName,
	source_id: StringName,
	target_id: StringName,
	amount: float,
	visibility: StringName
) -> ReasonEntry:
	return ReasonEntry.create(
		code,
		&"faction_planning",
		source_id,
		target_id,
		amount,
		StringName("reason.%s" % code),
		{},
		&"planning",
		visibility
	)


static func _fail_planning(result: FactionPlanningResult) -> FactionPlanningResult:
	result.operations.clear()
	result.new_offers.clear()
	result.new_commitments.clear()
	result.plans.clear()
	result.reason_entries.clear()
	result.state_changes.clear()
	result.new_state = null
	return result


static func _clear_action_resolution(
	result: FactionActionResolutionResult
) -> FactionActionResolutionResult:
	result.operations.clear()
	result.updated_commitments.clear()
	result.world_events.clear()
	result.reason_entries.clear()
	return result
