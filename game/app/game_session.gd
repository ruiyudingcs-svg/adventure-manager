## Sole runtime owner of the authoritative CampaignState.
extends Node

const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const CampaignBootstrapper = preload(
	"res://game/domain/simulation/campaign_bootstrapper.gd"
)
const WeeklyMessageProjector = preload(
	"res://game/domain/simulation/weekly_message_projector.gd"
)
const PlanContractCommand = preload(
	"res://game/domain/contracts/plan_contract_command.gd"
)
const DeclineContractOfferCommand = preload(
	"res://game/domain/contracts/decline_contract_offer_command.gd"
)
const ContractPlanningDefinitions = preload(
	"res://game/domain/contracts/contract_planning_definitions.gd"
)
const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const WeekFlowCoordinator = preload(
	"res://game/domain/simulation/week_flow_coordinator.gd"
)
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const SupplyDefinition = preload(
	"res://game/domain/contracts/supply_definition.gd"
)
const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const MethodTagDefinition = preload(
	"res://game/domain/contracts/method_tag_definition.gd"
)
const SaveService = preload("res://game/persistence/save_service.gd")

const PHASE_NO_CAMPAIGN: StringName = &"no_campaign"
const PHASE_PLANNING: StringName = &"planning"
const PHASE_RESOLUTION_REVIEW: StringName = &"resolution_review"
const PHASE_ENDED: StringName = &"ended"
const ALLOWED_PHASES: Array[StringName] = [
	PHASE_NO_CAMPAIGN,
	PHASE_PLANNING,
	PHASE_RESOLUTION_REVIEW,
	PHASE_ENDED,
]
const DEFAULT_SAVE_PATH: String = "user://campaign_v0_1.json"

signal campaign_replaced
signal message_read(message_id: StringName)
signal session_error(message: String)
signal campaign_saved(path: String)
signal campaign_loaded(path: String)

var _campaign_state: CampaignState
var _phase: StringName = PHASE_NO_CAMPAIGN
var _resolution_review_snapshot: Variant
var _last_error: String = ""
var _last_issues: PackedStringArray
var _catalog_override: Node
var _campaign_setup_id: StringName
var _save_service := SaveService.new()
var _has_recovery_candidate: bool


## Starts a detached Gate F setup through the pure CampaignBootstrapper.
func start_new_campaign(setup_id: StringName, campaign_seed: int) -> bool:
	var catalog := _catalog()
	if catalog == null:
		return _fail("DataCatalog is unavailable.")
	if not catalog.call("can_start_new_game"):
		var catalog_issues: Array = catalog.call("get_last_load_issues")
		var messages := PackedStringArray()
		for issue in catalog_issues:
			messages.append(issue.message)
		return _fail(
			"Content catalog is not ready.",
			messages
		)
	var setup = catalog.call("get_campaign_setup", setup_id)
	if setup == null:
		return _fail("Unknown campaign setup: %s." % setup_id)
	var situation = catalog.call(
		"get_situation",
		setup.situation_definition_id
	)
	var request := CampaignBootstrapper.BootstrapRequest.create(
		setup,
		campaign_seed,
		catalog.call("get_all_adventurers"),
		catalog.call("get_all_factions"),
		catalog.call("get_all_contracts"),
		catalog.call("get_all_faction_actions"),
		catalog.call("get_all_problems"),
		situation
	)
	var bootstrap := CampaignBootstrapper.bootstrap(request)
	if not bootstrap.is_success():
		return _fail(
			"New campaign could not be started.",
			bootstrap.issues
		)
	_campaign_state = bootstrap.new_state.duplicate_state()
	_campaign_setup_id = setup_id
	_resolution_review_snapshot = null
	_phase = (
		PHASE_ENDED
		if not _campaign_state.situation.ending_id.is_empty()
		else PHASE_PLANNING
	)
	_clear_error()
	campaign_replaced.emit()
	return true


## Returns a detached snapshot; no screen receives the authoritative instance.
func get_campaign_snapshot() -> CampaignState:
	return (
		_campaign_state.duplicate_state()
		if _campaign_state != null else null
	)


func get_phase() -> StringName:
	return _phase


func has_campaign() -> bool:
	return _campaign_state != null


func has_resolution_review() -> bool:
	return _phase == PHASE_RESOLUTION_REVIEW \
		and _resolution_review_snapshot != null


func get_last_error() -> String:
	return _last_error


func get_last_issues() -> PackedStringArray:
	return _last_issues.duplicate()


func get_default_save_path() -> String:
	return DEFAULT_SAVE_PATH


func get_campaign_setup_id() -> StringName:
	return _campaign_setup_id


func has_recovery_candidate() -> bool:
	return _has_recovery_candidate


## SaveService owns encoding and file replacement; GameSession owns the
## planning-only phase gate and never publishes partial load results.
func save_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	if _phase != PHASE_PLANNING or _campaign_state == null:
		return _fail(
			"Only an active planning phase can be saved.",
			PackedStringArray(["save.phase_not_planning"])
		)
	var result = _save_service.save_planning_state(
		path,
		_campaign_setup_id,
		_campaign_state
	)
	if not result.is_success():
		return _fail(
			"Campaign could not be saved.",
			_save_issue_messages(result.issues)
		)
	_has_recovery_candidate = false
	_clear_error()
	campaign_saved.emit(path)
	return true


func load_game(
	path: String = DEFAULT_SAVE_PATH,
	accept_recovery: bool = false
) -> bool:
	var catalog := _catalog()
	if catalog == null:
		return _fail("DataCatalog is unavailable.")
	var result = _save_service.load_planning_state(path, catalog)
	_has_recovery_candidate = result.has_recovery_candidate()
	if result.is_success():
		return _publish_loaded_campaign(
			result.campaign_state,
			result.campaign_setup_id,
			path
		)
	if accept_recovery and result.has_recovery_candidate():
		return _publish_loaded_campaign(
			result.recovery_state,
			result.recovery_campaign_setup_id,
			result.recovery_path
		)
	var messages := _save_issue_messages(result.issues)
	if result.has_recovery_candidate():
		messages.append("save.recovery_available")
	return _fail("Campaign could not be loaded.", messages)


func inspect_save(path: String = DEFAULT_SAVE_PATH):
	return _save_service.inspect_save(path)


## Dry-runs the official acceptance service against detached definitions.
## It exists so disabled UI controls can show the same validation authority.
func validate_plan(command: PlanContractCommand) -> PackedStringArray:
	var issues := PackedStringArray()
	if _phase != PHASE_PLANNING or _campaign_state == null:
		issues.append("Contract plans can only be validated during planning.")
		return issues
	var definitions := _planning_definitions()
	if definitions == null:
		issues.append("Contract planning definitions are unavailable.")
		return issues
	var result := ContractOfferService.accept_offer(
		_campaign_state,
		command,
		definitions
	)
	return result.issues.duplicate()


## Applies the accepted decline command only after its complete transaction succeeds.
func decline_offer(command: DeclineContractOfferCommand) -> bool:
	if _phase != PHASE_PLANNING or _campaign_state == null:
		return _fail("Offers can only be declined during planning.")
	var result := ContractOfferService.decline_offer(_campaign_state, command)
	if not result.is_success() or result.new_state == null:
		return _fail("Contract offer could not be declined.", result.issues)
	_campaign_state = result.new_state.duplicate_state()
	_clear_error()
	campaign_replaced.emit()
	return true


## Locks exactly one accepted PlanContractCommand; no later edit API exists.
func accept_plan(command: PlanContractCommand) -> bool:
	if _phase != PHASE_PLANNING or _campaign_state == null:
		return _fail("Contract plans can only be accepted during planning.")
	var definitions := _planning_definitions()
	if definitions == null:
		return _fail("Contract planning definitions are unavailable.")
	var accepted := ContractOfferService.accept_offer(
		_campaign_state,
		command,
		definitions
	)
	if not accepted.is_success():
		return _fail("Contract plan could not be accepted.", accepted.issues)
	var transaction = CampaignTransaction.apply(
		_campaign_state,
		accepted.operations
	)
	if not transaction.is_success():
		return _fail(
			"Contract plan could not be committed.",
			transaction.issues
		)
	_campaign_state = transaction.new_state.duplicate_state()
	_clear_error()
	campaign_replaced.emit()
	return true


## Resolves the current planning week once and caches its detached result for review.
func resolve_current_week(skip_contract: bool) -> bool:
	if _phase != PHASE_PLANNING or _campaign_state == null:
		return _fail("The current week can only resolve once during planning.")
	if skip_contract:
		if _campaign_state.active_plan != null:
			return _fail("A week with an active plan cannot skip its contract.")
	else:
		if _campaign_state.active_plan == null:
			return _fail("Dispatch requires an accepted contract plan.")
	var catalog := _catalog()
	var situation = catalog.call(
		"get_situation",
		_campaign_state.situation.definition_id
	) if catalog != null else null
	var definitions := (
		null if skip_contract else _planning_definitions()
	)
	var request := WeekFlowCoordinator.WeekResolutionRequest.create(
		_campaign_state.week_index,
		_campaign_state,
		skip_contract,
		definitions,
		catalog.call("get_all_faction_actions") if catalog != null else [],
		situation
	)
	var resolution := WeekFlowCoordinator.resolve_week(request)
	if not resolution.is_success():
		return _fail("The current week could not be resolved.", resolution.issues)
	# The result owns a state cloned from the request; the authoritative state is
	# replaced by a second clone so review data can never mutate it.
	_resolution_review_snapshot = resolution
	_campaign_state = resolution.new_state.duplicate_state()
	_phase = PHASE_RESOLUTION_REVIEW
	_clear_error()
	campaign_replaced.emit()
	return true


## Returns a detached primitive review payload projected only from the cached
## WeekResolution and its committed StateChanges.
func get_resolution_review_snapshot(
	include_debug_reasons: bool = false
) -> Dictionary:
	if not has_resolution_review():
		return {}
	return _resolution_payload(
		_resolution_review_snapshot,
		include_debug_reasons
	).duplicate(true)


## Leaves review exactly once. An ending is acknowledged without opening a week;
## otherwise the official opening transaction creates the next planning state.
func acknowledge_resolution() -> bool:
	if not has_resolution_review() or _campaign_state == null:
		return _fail("There is no resolution review to acknowledge.")
	if not _campaign_state.situation.ending_id.is_empty():
		_resolution_review_snapshot = null
		_phase = PHASE_ENDED
		_clear_error()
		campaign_replaced.emit()
		return true
	var catalog := _catalog()
	if catalog == null:
		return _fail("DataCatalog is unavailable.")
	var next_week: int = _campaign_state.week_index + 1
	var archive := ContractOfferService.archive_declined(
		_campaign_state,
		next_week
	)
	if not archive.is_success():
		return _fail("Declined offers could not be archived.", archive.issues)
	var opening_base: CampaignState = _campaign_state.duplicate_state()
	if not archive.operations.is_empty():
		var archive_transaction = CampaignTransaction.apply(
			opening_base,
			archive.operations
		)
		if not archive_transaction.is_success():
			return _fail(
				"Declined offers could not be archived.",
				archive_transaction.issues
			)
		opening_base = archive_transaction.new_state
	var situation = catalog.call(
		"get_situation",
		opening_base.situation.definition_id
	)
	var request := WeekFlowCoordinator.WeekOpeningRequest.create(
		next_week,
		opening_base,
		catalog.call("get_all_adventurers"),
		catalog.call("get_all_factions"),
		catalog.call("get_all_contracts"),
		catalog.call("get_all_faction_actions"),
		catalog.call("get_all_problems"),
		situation,
		archive.suppression_keys
	)
	var opening := WeekFlowCoordinator.open_week(request)
	if not opening.is_success():
		return _fail("The next week could not be opened.", opening.issues)
	_campaign_state = opening.new_state.duplicate_state()
	_resolution_review_snapshot = null
	_phase = (
		PHASE_ENDED
		if not _campaign_state.situation.ending_id.is_empty()
		else PHASE_PLANNING
	)
	_clear_error()
	campaign_replaced.emit()
	return true


## Uses the accepted projector command and swaps state only after success.
func mark_message_read(message_id: StringName) -> bool:
	if _campaign_state == null:
		return _fail("No campaign is active.")
	var projection := WeeklyMessageProjector.mark_read(
		_campaign_state,
		message_id
	)
	if not projection.is_success():
		return _fail(
			"Message could not be marked read.",
			projection.issues
		)
	_campaign_state = projection.new_state.duplicate_state()
	_clear_error()
	message_read.emit(message_id)
	return true


## Test seam for an isolated DataCatalog node; production uses the Autoload.
func set_catalog_for_testing(catalog: Node) -> void:
	_catalog_override = catalog


func _catalog() -> Node:
	if _catalog_override != null:
		return _catalog_override
	return get_node_or_null("/root/DataCatalog")


func _publish_loaded_campaign(
	state: CampaignState,
	setup_id: StringName,
	source_path: String
) -> bool:
	if state == null:
		return _fail("Loaded campaign state is unavailable.")
	var validation: PackedStringArray = state.validate()
	if not validation.is_empty():
		return _fail("Loaded campaign state is invalid.", validation)
	_campaign_state = state.duplicate_state()
	_campaign_setup_id = setup_id
	_resolution_review_snapshot = null
	_phase = PHASE_PLANNING
	_has_recovery_candidate = false
	_clear_error()
	campaign_replaced.emit()
	campaign_loaded.emit(source_path)
	return true


func _save_issue_messages(issues: Array) -> PackedStringArray:
	var messages := PackedStringArray()
	for issue in issues:
		messages.append(issue.display_text())
	return messages


func _planning_definitions() -> ContractPlanningDefinitions:
	var catalog := _catalog()
	if catalog == null:
		return null
	var contract_map: Dictionary[StringName, ContractDefinition] = {}
	for definition: ContractDefinition in catalog.call("get_all_contracts"):
		contract_map[definition.id] = definition
	var adventurer_map: Dictionary[StringName, AdventurerDefinition] = {}
	for definition: AdventurerDefinition in catalog.call("get_all_adventurers"):
		adventurer_map[definition.id] = definition
	var supply_map: Dictionary[StringName, SupplyDefinition] = {}
	for definition: SupplyDefinition in catalog.call("get_all_supplies"):
		supply_map[definition.id] = definition
	var clauses: Array[ContractClauseDefinition] = []
	clauses.assign(catalog.call("get_all_contract_clauses"))
	var method_tags: Array[MethodTagDefinition] = []
	method_tags.assign(catalog.call("get_all_method_tags"))
	return ContractPlanningDefinitions.create(
		contract_map,
		adventurer_map,
		supply_map,
		clauses,
		method_tags
	)


func _resolution_payload(
	week_resolution,
	include_debug_reasons: bool
) -> Dictionary:
	var payload := {
		"resolved_week": _campaign_state.week_index,
		"next_week": _campaign_state.week_index + 1,
		"ending_id": _campaign_state.situation.ending_id,
		"contract": {},
		"faction_actions": [],
		"state_changes": [],
		"reasons": [],
	}
	if (
		week_resolution.contract_resolve_result != null
		and week_resolution.contract_resolve_result.resolution != null
	):
		var resolution = week_resolution.contract_resolve_result.resolution
		var history_entry = _history_entry_for(
			resolution.contract_instance_id
		)
		var phase_rows: Array[Dictionary] = []
		for phase_result in resolution.phase_results:
			var check = phase_result.check_result
			phase_rows.append({
				"phase": phase_result.phase,
				"check_id": check.check_id,
				"check_type": check.check_type,
				"score": check.score,
				"result_tier": check.result_tier,
				"context_deltas": check.context_deltas.duplicate(true),
				"reasons": _reason_payloads(
					check.reason_entries,
					include_debug_reasons
				),
			})
		var clause_rows: Array[Dictionary] = []
		for clause in resolution.clause_results:
			clause_rows.append({
				"clause_id": clause.clause_id,
				"category": clause.category,
				"importance": clause.importance,
				"satisfied": clause.satisfied,
				"evidence": clause.evidence.duplicate(),
				"result_cap": clause.result_cap,
				"reasons": _reason_payloads(
					clause.reason_entries,
					include_debug_reasons
				),
			})
		var member_rows: Array[Dictionary] = []
		for outcome in resolution.member_outcomes:
			member_rows.append({
				"member_id": outcome.member_id,
				"fatigue_delta": outcome.fatigue_delta,
				"injury_result": outcome.injury_result,
				"injury_severity_after": outcome.injury_severity_after,
				"recovery_weeks_after": outcome.recovery_weeks_after,
				"is_available_after": outcome.is_available_after,
				"morale_delta": outcome.morale_delta,
				"reasons": _reason_payloads(
					outcome.reason_entries,
					include_debug_reasons
				),
			})
		payload["contract"] = {
			"contract_instance_id": resolution.contract_instance_id,
			"definition_id": (
				history_entry.contract_definition_id
				if history_entry != null else &""
			),
			"sponsor_faction_id": (
				history_entry.sponsor_faction_id
				if history_entry != null else &""
			),
			"initial_result_tier": resolution.initial_result_tier,
			"operational_result_tier": resolution.operational_result_tier,
			"result_tier": resolution.result_tier,
			"contract_score": resolution.contract_score,
			"reward": resolution.reward,
			"supply_cost_total": resolution.supply_cost_total,
			"consumed_supply_ids": resolution.consumed_supply_ids.duplicate(),
			"sponsor_relation_delta": resolution.sponsor_relation_delta,
			"outcome_tags": resolution.outcome_tags.duplicate(),
			"phases": phase_rows,
			"clauses": clause_rows,
			"members": member_rows,
			"reasons": _reason_payloads(
				resolution.reason_entries,
				include_debug_reasons
			),
		}
	if week_resolution.action_resolution_result != null:
		for commitment in (
			week_resolution.action_resolution_result.updated_commitments
		):
			payload["faction_actions"].append({
				"instance_id": commitment.instance_id,
				"faction_id": commitment.faction_id,
				"action_definition_id": commitment.action_definition_id,
				"status": commitment.status,
				"world_event_ids": commitment.world_event_ids.duplicate(),
			})
	for change in week_resolution.state_changes:
		payload["state_changes"].append({
			"target_id": change.target_id,
			"field_path": change.field_path,
			"old_value": _detached_variant(change.old_value),
			"new_value": _detached_variant(change.new_value),
			"reason_codes": change.reason_codes.duplicate(),
		})
	payload["reasons"] = _reason_payloads(
		week_resolution.reasons,
		include_debug_reasons
	)
	return payload


func _history_entry_for(contract_instance_id: StringName):
	for entry in _campaign_state.contract_history:
		if entry.contract_instance_id == contract_instance_id:
			return entry
	return null


func _reason_payloads(
	reasons: Array,
	include_debug_reasons: bool
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reason in reasons:
		if (
			reason.visibility == ReasonEntry.VISIBILITY_DEBUG
			and not include_debug_reasons
		):
			continue
		result.append({
			"code": reason.code,
			"category": reason.category,
			"source_id": reason.source_id,
			"target_id": reason.target_id,
			"amount": reason.amount,
			"localization_key": reason.localization_key,
			"parameters": reason.parameters,
			"phase": reason.phase,
			"visibility": reason.visibility,
		})
	return result


func _detached_variant(value: Variant) -> Variant:
	if value is Object and value.has_method("content_signature"):
		return value.call("content_signature")
	if typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return value


func _fail(message: String, issues: PackedStringArray = []) -> bool:
	_last_error = message
	_last_issues = issues.duplicate()
	session_error.emit(message)
	return false


func _clear_error() -> void:
	_last_error = ""
	_last_issues.clear()
