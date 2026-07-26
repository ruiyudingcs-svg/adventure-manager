class_name CampaignStateCodec
extends RefCounted

const SaveIssue = preload("res://game/persistence/save_issue.gd")
const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const GuildState = preload("res://game/domain/guild/guild_state.gd")
const AdventurerState = preload(
	"res://game/domain/adventurers/adventurer_state.gd"
)
const FactionState = preload("res://game/domain/factions/faction_state.gd")
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
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
const MissionContext = preload(
	"res://game/domain/contracts/mission_context.gd"
)
const ContractPlanState = preload(
	"res://game/domain/contracts/contract_plan_state.gd"
)
const FactionActionCommitmentState = preload(
	"res://game/domain/factions/faction_action_commitment_state.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const MessageState = preload("res://game/domain/messages/message_state.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const StateChange = preload("res://game/core/result/state_change.gd")
const StableId = preload("res://game/core/ids/stable_id.gd")


class DecodeResult extends RefCounted:
	var state: CampaignState
	var issues: Array[SaveIssue]

	func is_success() -> bool:
		return state != null and issues.is_empty()


## Produces the complete schema-v1 DTO. Definitions remain stable IDs only.
static func encode_state(state: CampaignState) -> Dictionary:
	var adventurers: Dictionary = {}
	for member_id: StringName in state.adventurers:
		var member: AdventurerState = state.adventurers[member_id]
		adventurers[String(member_id)] = {
			"definition_id": String(member.definition_id),
			"fatigue": member.get_fatigue(),
			"morale": member.get_morale(),
			"injury_severity": member.get_injury_severity(),
			"recovery_weeks_remaining": member.get_recovery_weeks_remaining(),
			"growth_xp": member.get_growth_xp(),
			"is_available": member.get_is_available(),
			"relationship_deltas": _encode_id_int_dictionary(
				member.get_relationship_deltas()
			),
			"recent_assignment_count": member.get_recent_assignment_count(),
			"recent_neglect_count": member.get_recent_neglect_count(),
		}
	var factions: Dictionary = {}
	for faction_id: StringName in state.factions:
		var faction: FactionState = state.factions[faction_id]
		factions[String(faction_id)] = {
			"definition_id": String(faction.definition_id),
			"relation": faction.relation,
			"influence": faction.influence,
		}
	var offers: Array = []
	for offer: ContractOfferState in state.pending_contracts:
		offers.append(_encode_offer(offer))
	var commitments: Array = []
	for commitment: FactionActionCommitmentState \
			in state.faction_action_commitments:
		commitments.append(_encode_commitment(commitment))
	var history: Array = []
	for entry: ContractHistoryEntry in state.contract_history:
		history.append(_encode_history(entry))
	var events: Array = []
	for event: WorldEventState in state.world_events:
		events.append(_encode_world_event(event))
	var messages: Array = []
	for message: MessageState in state.message_history:
		messages.append(_encode_message(message))
	return {
		"save_version": state.save_version,
		"campaign_seed": state.campaign_seed,
		"week_index": state.week_index,
		"guild": {
			"gold": state.guild.gold,
			"reputation": state.guild.reputation,
			"base_cohesion": state.guild.base_cohesion,
			"weekly_maintenance": state.guild.weekly_maintenance,
		},
		"adventurers": adventurers,
		"factions": factions,
		"situation": _encode_situation(state.situation),
		"pending_contracts": offers,
		"active_plan": (
			null if state.active_plan == null
			else _encode_plan(state.active_plan)
		),
		"declined_offer_week": state.declined_offer_week,
		"faction_action_commitments": commitments,
		"contract_history": history,
		"world_events": events,
		"message_history": messages,
	}


static func canonical_state_json(state: CampaignState) -> String:
	return JSON.stringify(encode_state(state), "", true, true)


static func decode_state(dto: Variant, file_path: String) -> DecodeResult:
	var result := DecodeResult.new()
	if typeof(dto) != TYPE_DICTIONARY:
		result.issues.append(_issue(
			file_path,
			"$.campaign_state",
			&"wrong_type",
			"Expected an object."
		))
		return result
	var root: Dictionary = dto
	var save_version := _read_int(
		root, "save_version", "$.campaign_state", file_path, result.issues
	)
	var campaign_seed := _read_int(
		root, "campaign_seed", "$.campaign_state", file_path, result.issues
	)
	var week_index := _read_int(
		root, "week_index", "$.campaign_state", file_path, result.issues
	)
	var guild_dto := _read_dictionary(
		root, "guild", "$.campaign_state", file_path, result.issues
	)
	var guild := GuildState.create(
		_read_int(guild_dto, "gold", "$.campaign_state.guild", file_path, result.issues),
		_read_int(
			guild_dto, "reputation", "$.campaign_state.guild", file_path, result.issues
		),
		_read_int(
			guild_dto, "base_cohesion", "$.campaign_state.guild", file_path, result.issues
		),
		_read_int(
			guild_dto,
			"weekly_maintenance",
			"$.campaign_state.guild",
			file_path,
			result.issues
		)
	)

	var adventurers: Dictionary[StringName, AdventurerState] = {}
	var adventurer_dto := _read_dictionary(
		root, "adventurers", "$.campaign_state", file_path, result.issues
	)
	for key: Variant in adventurer_dto:
		var path := "$.campaign_state.adventurers.%s" % key
		var item := _expect_dictionary(
			adventurer_dto[key], path, file_path, result.issues
		)
		var relationships := _decode_id_int_dictionary(
			_read_dictionary(item, "relationship_deltas", path, file_path, result.issues),
			path + ".relationship_deltas",
			file_path,
			result.issues
		)
		var member := AdventurerState.create(
			_read_id(item, "definition_id", path, file_path, result.issues),
			_read_int(item, "fatigue", path, file_path, result.issues),
			_read_int(item, "morale", path, file_path, result.issues),
			_read_int(item, "injury_severity", path, file_path, result.issues),
			_read_int(
				item, "recovery_weeks_remaining", path, file_path, result.issues
			),
			_read_int(item, "growth_xp", path, file_path, result.issues),
			_read_bool(item, "is_available", path, file_path, result.issues),
			relationships,
			_read_int(
				item, "recent_assignment_count", path, file_path, result.issues
			),
			_read_int(item, "recent_neglect_count", path, file_path, result.issues)
		)
		if member != null:
			adventurers[StringName(str(key))] = member
		else:
			result.issues.append(_invalid(
				file_path, path, "AdventurerState values are invalid."
			))

	var factions: Dictionary[StringName, FactionState] = {}
	var faction_dto := _read_dictionary(
		root, "factions", "$.campaign_state", file_path, result.issues
	)
	for key: Variant in faction_dto:
		var path := "$.campaign_state.factions.%s" % key
		var item := _expect_dictionary(
			faction_dto[key], path, file_path, result.issues
		)
		var faction := FactionState.create(
			_read_id(item, "definition_id", path, file_path, result.issues),
			_read_int(item, "relation", path, file_path, result.issues),
			_read_int(item, "influence", path, file_path, result.issues)
		)
		if faction != null:
			factions[StringName(str(key))] = faction
		else:
			result.issues.append(_invalid(
				file_path, path, "FactionState values are invalid."
			))

	var situation := _decode_situation(
		_read_dictionary(
			root, "situation", "$.campaign_state", file_path, result.issues
		),
		file_path,
		result.issues
	)
	var offers: Array[ContractOfferState] = []
	var offer_dto := _read_array(
		root, "pending_contracts", "$.campaign_state", file_path, result.issues
	)
	for index: int in range(offer_dto.size()):
		var offer := _decode_offer(
			offer_dto[index],
			"$.campaign_state.pending_contracts[%d]" % index,
			file_path,
			result.issues
		)
		if offer != null:
			offers.append(offer)
	var active_plan: ContractPlanState
	if root.has("active_plan") and root["active_plan"] != null:
		active_plan = _decode_plan(
			root["active_plan"],
			"$.campaign_state.active_plan",
			file_path,
			result.issues
		)
	elif not root.has("active_plan"):
		result.issues.append(_missing(
			file_path, "$.campaign_state.active_plan"
		))
	var commitments: Array[FactionActionCommitmentState] = []
	var commitment_dto := _read_array(
		root,
		"faction_action_commitments",
		"$.campaign_state",
		file_path,
		result.issues
	)
	for index: int in range(commitment_dto.size()):
		var commitment := _decode_commitment(
			commitment_dto[index],
			"$.campaign_state.faction_action_commitments[%d]" % index,
			file_path,
			result.issues
		)
		if commitment != null:
			commitments.append(commitment)
	var history: Array[ContractHistoryEntry] = []
	var history_dto := _read_array(
		root, "contract_history", "$.campaign_state", file_path, result.issues
	)
	for index: int in range(history_dto.size()):
		var entry := _decode_history(
			history_dto[index],
			"$.campaign_state.contract_history[%d]" % index,
			file_path,
			result.issues
		)
		if entry != null:
			history.append(entry)
	var events: Array[WorldEventState] = []
	var event_dto := _read_array(
		root, "world_events", "$.campaign_state", file_path, result.issues
	)
	for index: int in range(event_dto.size()):
		var event := _decode_world_event(
			event_dto[index],
			"$.campaign_state.world_events[%d]" % index,
			file_path,
			result.issues
		)
		if event != null:
			events.append(event)
	var messages: Array[MessageState] = []
	var message_dto := _read_array(
		root, "message_history", "$.campaign_state", file_path, result.issues
	)
	for index: int in range(message_dto.size()):
		var message := _decode_message(
			message_dto[index],
			"$.campaign_state.message_history[%d]" % index,
			file_path,
			result.issues
		)
		if message != null:
			messages.append(message)
	var declined_offer_week := _read_int(
		root,
		"declined_offer_week",
		"$.campaign_state",
		file_path,
		result.issues
	)
	if guild == null:
		result.issues.append(_invalid(
			file_path, "$.campaign_state.guild", "Guild values are invalid."
		))
	if not result.issues.is_empty():
		return result
	result.state = CampaignState.create(
		campaign_seed,
		week_index,
		guild,
		adventurers,
		factions,
		situation,
		history,
		events,
		save_version,
		offers,
		active_plan,
		declined_offer_week,
		commitments,
		messages
	)
	if result.state == null:
		result.issues.append(_invalid(
			file_path,
			"$.campaign_state",
			"CampaignState validation failed."
		))
	return result


static func _encode_situation(state: SituationState) -> Dictionary:
	var problems: Dictionary = {}
	for problem_id: StringName in state.problems:
		var problem: WorldProblemState = state.problems[problem_id]
		problems[String(problem_id)] = {
			"definition_id": String(problem.definition_id),
			"status": String(problem.status),
			"opened_week": problem.opened_week,
			"response_deadline_week": problem.response_deadline_week,
			"closed_week": problem.closed_week,
			"source_event_id": String(problem.source_event_id),
			"resolution_reason_code": String(problem.resolution_reason_code),
		}
	return {
		"definition_id": String(state.definition_id),
		"phase_id": String(state.phase_id),
		"clock_values": _encode_id_int_dictionary(state.clock_values),
		"triggered_rule_ids": _encode_ids(state.triggered_rule_ids),
		"unlocked_contract_ids": _encode_ids(state.unlocked_contract_ids),
		"problems": problems,
		"ending_id": String(state.ending_id),
	}


static func _encode_offer(offer: ContractOfferState) -> Dictionary:
	return {
		"instance_id": String(offer.instance_id),
		"definition_id": String(offer.definition_id),
		"sponsor_faction_id": String(offer.sponsor_faction_id),
		"origin_type": String(offer.origin_type),
		"related_problem_id": String(offer.related_problem_id),
		"target_lock_key": String(offer.target_lock_key),
		"offered_week": offer.offered_week,
		"expires_week": offer.expires_week,
		"offered_reward": offer.offered_reward,
		"applied_relation_tier": String(offer.applied_relation_tier),
		"sponsor_relation_snapshot": offer.sponsor_relation_snapshot,
		"problem_urgency_at_offer": offer.problem_urgency_at_offer,
		"generation_reason_entries": _encode_reasons(
			offer.generation_reason_entries
		),
		"locked_seed": offer.locked_seed,
		"instantiation_snapshot": _encode_snapshot(
			offer.instantiation_snapshot
		),
		"status": String(offer.status),
		"resolved_week": offer.resolved_week,
		"terminal_reason_code": String(offer.terminal_reason_code),
	}


static func _encode_snapshot(
	snapshot: ContractInstantiationSnapshot
) -> Dictionary:
	var bindings: Array = []
	for binding: CheckDifficultyBinding in snapshot.check_difficulty_deltas:
		bindings.append({
			"check_id": String(binding.check_id),
			"difficulty_delta": binding.difficulty_delta,
			"reason_codes": _encode_ids(binding.reason_codes),
		})
	return {
		"evaluated_week": snapshot.evaluated_week,
		"check_difficulty_deltas": bindings,
		"initial_context": _encode_context(snapshot.initial_context),
		"reason_entries": _encode_reasons(snapshot.reason_entries),
	}


static func _encode_context(context: MissionContext) -> Dictionary:
	var values: Dictionary = {}
	for key: StringName in MissionContext.CONTEXT_KEYS:
		values[String(key)] = context.get_value(key)
	return {
		"values": values,
		"outcome_tags": _encode_ids(context.outcome_tags),
		"used_method_tags": _encode_ids(context.used_method_tags),
	}


static func _encode_plan(plan: ContractPlanState) -> Dictionary:
	return {
		"contract_instance_id": String(plan.contract_instance_id),
		"selected_member_ids": _encode_ids(plan.selected_member_ids),
		"selected_supply_ids": _encode_ids(plan.selected_supply_ids),
		"approach": String(plan.approach),
	}


static func _encode_commitment(
	commitment: FactionActionCommitmentState
) -> Dictionary:
	return {
		"instance_id": String(commitment.instance_id),
		"faction_id": String(commitment.faction_id),
		"action_definition_id": String(commitment.action_definition_id),
		"target_problem_id": String(commitment.target_problem_id),
		"target_lock_key": String(commitment.target_lock_key),
		"committed_week": commitment.committed_week,
		"resolves_at_week": commitment.resolves_at_week,
		"reserved_influence": commitment.reserved_influence,
		"commitment_reason_entries": _encode_reasons(
			commitment.commitment_reason_entries
		),
		"status": String(commitment.status),
		"resolved_week": commitment.resolved_week,
		"world_event_ids": _encode_ids(commitment.world_event_ids),
	}


static func _encode_history(entry: ContractHistoryEntry) -> Dictionary:
	var changes: Array = []
	for change: StateChange in entry.state_changes:
		changes.append({
			"target_id": String(change.target_id),
			"field_path": change.field_path,
			"old_value": _encode_variant(change.old_value),
			"new_value": _encode_variant(change.new_value),
			"reason_codes": _encode_ids(change.reason_codes),
		})
	return {
		"week_index": entry.week_index,
		"offered_week": entry.offered_week,
		"contract_instance_id": String(entry.contract_instance_id),
		"contract_definition_id": String(entry.contract_definition_id),
		"sponsor_faction_id": String(entry.sponsor_faction_id),
		"origin_type": String(entry.origin_type),
		"related_problem_id": String(entry.related_problem_id),
		"target_lock_key": String(entry.target_lock_key),
		"terminal_status": String(entry.terminal_status),
		"terminal_reason_code": String(entry.terminal_reason_code),
		"member_ids": _encode_ids(entry.member_ids),
		"supply_ids": _encode_ids(entry.supply_ids),
		"approach": String(entry.approach),
		"result_tier": String(entry.result_tier),
		"reward_received": entry.reward_received,
		"trace_summary": _encode_variant(entry.trace_summary),
		"state_changes": changes,
		"world_event_ids": _encode_ids(entry.world_event_ids),
		"generation_reason_entries": _encode_reasons(
			entry.generation_reason_entries
		),
	}


static func _encode_world_event(event: WorldEventState) -> Dictionary:
	return {
		"instance_id": String(event.instance_id),
		"event_key": String(event.event_key),
		"week_index": event.week_index,
		"source_id": String(event.source_id),
		"related_problem_id": String(event.related_problem_id),
		"effect_reason_codes": _encode_ids(event.effect_reason_codes),
		"visibility": String(event.visibility),
	}


static func _encode_message(message: MessageState) -> Dictionary:
	return {
		"instance_id": String(message.instance_id),
		"week_index": message.week_index,
		"category": String(message.category),
		"source_type": String(message.source_type),
		"source_id": String(message.source_id),
		"title_key": String(message.title_key),
		"body_key": String(message.body_key),
		"parameters": _encode_variant(message.parameters),
		"importance": String(message.importance),
		"sort_order": message.sort_order,
		"is_read": message.is_read,
	}


static func _encode_reasons(reasons: Array) -> Array:
	var values: Array = []
	for reason: ReasonEntry in reasons:
		values.append({
			"code": String(reason.code),
			"category": String(reason.category),
			"source_id": String(reason.source_id),
			"target_id": String(reason.target_id),
			"amount": reason.amount,
			"localization_key": String(reason.localization_key),
			"parameters": _encode_variant(reason.parameters),
			"phase": String(reason.phase),
			"visibility": String(reason.visibility),
		})
	return values


static func _decode_situation(
	dto: Dictionary,
	file_path: String,
	issues: Array[SaveIssue]
) -> SituationState:
	var path := "$.campaign_state.situation"
	var clocks := _decode_id_int_dictionary(
		_read_dictionary(dto, "clock_values", path, file_path, issues),
		path + ".clock_values",
		file_path,
		issues
	)
	var problems: Dictionary[StringName, WorldProblemState] = {}
	var problem_dto := _read_dictionary(
		dto, "problems", path, file_path, issues
	)
	for key: Variant in problem_dto:
		var item_path := path + ".problems.%s" % key
		var item := _expect_dictionary(
			problem_dto[key], item_path, file_path, issues
		)
		var problem := WorldProblemState.create(
			_read_id(item, "definition_id", item_path, file_path, issues),
			_read_id(item, "status", item_path, file_path, issues),
			_read_int(item, "opened_week", item_path, file_path, issues),
			_read_int(
				item, "response_deadline_week", item_path, file_path, issues
			),
			_read_int(item, "closed_week", item_path, file_path, issues),
			_read_id(
				item, "source_event_id", item_path, file_path, issues, true
			),
			_read_id(
				item,
				"resolution_reason_code",
				item_path,
				file_path,
				issues,
				true
			)
		)
		if problem != null:
			problems[StringName(str(key))] = problem
		else:
			issues.append(_invalid(
				file_path, item_path, "WorldProblemState values are invalid."
			))
	var state := SituationState.create(
		_read_id(dto, "definition_id", path, file_path, issues),
		_read_id(dto, "phase_id", path, file_path, issues),
		clocks,
		_decode_ids(
			_read_array(dto, "triggered_rule_ids", path, file_path, issues),
			path + ".triggered_rule_ids",
			file_path,
			issues
		),
		_decode_ids(
			_read_array(dto, "unlocked_contract_ids", path, file_path, issues),
			path + ".unlocked_contract_ids",
			file_path,
			issues
		),
		problems,
		_read_id(dto, "ending_id", path, file_path, issues, true)
	)
	if state == null:
		issues.append(_invalid(file_path, path, "SituationState is invalid."))
	return state


static func _decode_offer(
	value: Variant,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> ContractOfferState:
	var dto := _expect_dictionary(value, path, file_path, issues)
	var reasons := _decode_reasons(
		_read_array(dto, "generation_reason_entries", path, file_path, issues),
		path + ".generation_reason_entries",
		file_path,
		issues
	)
	var snapshot := _decode_snapshot(
		_read_dictionary(
			dto, "instantiation_snapshot", path, file_path, issues
		),
		path + ".instantiation_snapshot",
		file_path,
		issues
	)
	var offer := ContractOfferState.create(
		_read_id(dto, "instance_id", path, file_path, issues),
		_read_id(dto, "definition_id", path, file_path, issues),
		_read_id(dto, "sponsor_faction_id", path, file_path, issues),
		_read_id(dto, "origin_type", path, file_path, issues),
		_read_id(dto, "related_problem_id", path, file_path, issues, true),
		_read_id(dto, "target_lock_key", path, file_path, issues),
		_read_int(dto, "offered_week", path, file_path, issues),
		_read_int(dto, "expires_week", path, file_path, issues),
		_read_int(dto, "offered_reward", path, file_path, issues),
		_read_id(dto, "applied_relation_tier", path, file_path, issues),
		_read_int(dto, "sponsor_relation_snapshot", path, file_path, issues),
		_read_int(dto, "problem_urgency_at_offer", path, file_path, issues),
		reasons,
		_read_int(dto, "locked_seed", path, file_path, issues),
		snapshot,
		_read_id(dto, "status", path, file_path, issues),
		_read_int(dto, "resolved_week", path, file_path, issues),
		_read_id(dto, "terminal_reason_code", path, file_path, issues, true)
	)
	if offer == null:
		issues.append(_invalid(file_path, path, "ContractOfferState is invalid."))
	return offer


static func _decode_snapshot(
	dto: Dictionary,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> ContractInstantiationSnapshot:
	var bindings: Array[CheckDifficultyBinding] = []
	var binding_dto := _read_array(
		dto, "check_difficulty_deltas", path, file_path, issues
	)
	for index: int in range(binding_dto.size()):
		var item_path := path + ".check_difficulty_deltas[%d]" % index
		var item := _expect_dictionary(
			binding_dto[index], item_path, file_path, issues
		)
		var binding := CheckDifficultyBinding.create(
			_read_id(item, "check_id", item_path, file_path, issues),
			_read_int(item, "difficulty_delta", item_path, file_path, issues),
			_decode_ids(
				_read_array(item, "reason_codes", item_path, file_path, issues),
				item_path + ".reason_codes",
				file_path,
				issues
			)
		)
		if binding != null:
			bindings.append(binding)
	var context := _decode_context(
		_read_dictionary(dto, "initial_context", path, file_path, issues),
		path + ".initial_context",
		file_path,
		issues
	)
	var snapshot := ContractInstantiationSnapshot.create(
		_read_int(dto, "evaluated_week", path, file_path, issues),
		bindings,
		context,
		_decode_reasons(
			_read_array(dto, "reason_entries", path, file_path, issues),
			path + ".reason_entries",
			file_path,
			issues
		)
	)
	if snapshot == null:
		issues.append(_invalid(
			file_path, path, "ContractInstantiationSnapshot is invalid."
		))
	return snapshot


static func _decode_context(
	dto: Dictionary,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> MissionContext:
	var values := _decode_id_int_dictionary(
		_read_dictionary(dto, "values", path, file_path, issues),
		path + ".values",
		file_path,
		issues
	)
	for key: StringName in MissionContext.CONTEXT_KEYS:
		if not values.has(key):
			issues.append(_missing(file_path, path + ".values." + String(key)))
	for key: StringName in values:
		if not MissionContext.CONTEXT_KEYS.has(key):
			issues.append(_invalid(
				file_path, path + ".values." + String(key),
				"Unknown MissionContext key."
			))
		elif values[key] < 0 or values[key] > 10:
			issues.append(_invalid(
				file_path, path + ".values." + String(key),
				"MissionContext value must be between 0 and 10."
			))
	var outcomes := _decode_ids(
		_read_array(dto, "outcome_tags", path, file_path, issues),
		path + ".outcome_tags",
		file_path,
		issues
	)
	var methods := _decode_ids(
		_read_array(dto, "used_method_tags", path, file_path, issues),
		path + ".used_method_tags",
		file_path,
		issues
	)
	return MissionContext.new(values, outcomes, methods)


static func _decode_plan(
	value: Variant,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> ContractPlanState:
	var dto := _expect_dictionary(value, path, file_path, issues)
	var plan := ContractPlanState.create(
		_read_id(dto, "contract_instance_id", path, file_path, issues),
		_decode_ids(
			_read_array(dto, "selected_member_ids", path, file_path, issues),
			path + ".selected_member_ids",
			file_path,
			issues
		),
		_decode_ids(
			_read_array(dto, "selected_supply_ids", path, file_path, issues),
			path + ".selected_supply_ids",
			file_path,
			issues
		),
		_read_id(dto, "approach", path, file_path, issues)
	)
	if plan == null:
		issues.append(_invalid(file_path, path, "ContractPlanState is invalid."))
	return plan


static func _decode_commitment(
	value: Variant,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> FactionActionCommitmentState:
	var dto := _expect_dictionary(value, path, file_path, issues)
	var commitment := FactionActionCommitmentState.new(
		_read_id(dto, "instance_id", path, file_path, issues),
		_read_id(dto, "faction_id", path, file_path, issues),
		_read_id(dto, "action_definition_id", path, file_path, issues),
		_read_id(dto, "target_problem_id", path, file_path, issues),
		_read_id(dto, "target_lock_key", path, file_path, issues),
		_read_int(dto, "committed_week", path, file_path, issues),
		_read_int(dto, "resolves_at_week", path, file_path, issues),
		_read_int(dto, "reserved_influence", path, file_path, issues),
		_decode_reasons(
			_read_array(
				dto, "commitment_reason_entries", path, file_path, issues
			),
			path + ".commitment_reason_entries",
			file_path,
			issues
		),
		_read_id(dto, "status", path, file_path, issues),
		_read_int(dto, "resolved_week", path, file_path, issues),
		_decode_ids(
			_read_array(dto, "world_event_ids", path, file_path, issues),
			path + ".world_event_ids",
			file_path,
			issues
		)
	)
	if not commitment.validate().is_empty():
		issues.append(_invalid(
			file_path, path, "FactionActionCommitmentState is invalid."
		))
		return null
	return commitment


static func _decode_history(
	value: Variant,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> ContractHistoryEntry:
	var dto := _expect_dictionary(value, path, file_path, issues)
	var changes: Array[StateChange] = []
	var change_dto := _read_array(
		dto, "state_changes", path, file_path, issues
	)
	for index: int in range(change_dto.size()):
		var item_path := path + ".state_changes[%d]" % index
		var item := _expect_dictionary(
			change_dto[index], item_path, file_path, issues
		)
		if not item.has("old_value"):
			issues.append(_missing(file_path, item_path + ".old_value"))
		if not item.has("new_value"):
			issues.append(_missing(file_path, item_path + ".new_value"))
		changes.append(StateChange.create(
			_read_id(item, "target_id", item_path, file_path, issues),
			_read_string(item, "field_path", item_path, file_path, issues),
			_decode_variant(
				item.get("old_value"),
				item_path + ".old_value",
				file_path,
				issues
			),
			_decode_variant(
				item.get("new_value"),
				item_path + ".new_value",
				file_path,
				issues
			),
			_decode_ids(
				_read_array(item, "reason_codes", item_path, file_path, issues),
				item_path + ".reason_codes",
				file_path,
				issues
			)
		))
	if not dto.has("trace_summary"):
		issues.append(_missing(file_path, path + ".trace_summary"))
	var trace_summary: Variant = _decode_variant(
		dto.get("trace_summary"),
		path + ".trace_summary",
		file_path,
		issues
	)
	if typeof(trace_summary) != TYPE_DICTIONARY:
		issues.append(_invalid(
			file_path, path + ".trace_summary", "Expected an object."
		))
		trace_summary = {}
	var entry := ContractHistoryEntry.new(
		_read_int(dto, "week_index", path, file_path, issues),
		_read_int(dto, "offered_week", path, file_path, issues),
		_read_id(dto, "contract_instance_id", path, file_path, issues),
		_read_id(dto, "contract_definition_id", path, file_path, issues),
		_read_id(dto, "sponsor_faction_id", path, file_path, issues),
		_read_id(dto, "origin_type", path, file_path, issues),
		_read_id(dto, "related_problem_id", path, file_path, issues, true),
		_read_id(dto, "target_lock_key", path, file_path, issues, true),
		_read_id(dto, "terminal_status", path, file_path, issues),
		_read_id(dto, "terminal_reason_code", path, file_path, issues),
		_decode_ids(
			_read_array(dto, "member_ids", path, file_path, issues),
			path + ".member_ids",
			file_path,
			issues
		),
		_decode_ids(
			_read_array(dto, "supply_ids", path, file_path, issues),
			path + ".supply_ids",
			file_path,
			issues
		),
		_read_id(dto, "approach", path, file_path, issues, true),
		_read_id(dto, "result_tier", path, file_path, issues, true),
		_read_int(dto, "reward_received", path, file_path, issues),
		trace_summary,
		changes,
		_decode_ids(
			_read_array(dto, "world_event_ids", path, file_path, issues),
			path + ".world_event_ids",
			file_path,
			issues
		),
		_decode_reasons(
			_read_array(
				dto, "generation_reason_entries", path, file_path, issues
			),
			path + ".generation_reason_entries",
			file_path,
			issues
		)
	)
	if not entry.validate().is_empty():
		issues.append(_invalid(
			file_path, path, "ContractHistoryEntry is invalid."
		))
		return null
	return entry


static func _decode_world_event(
	value: Variant,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> WorldEventState:
	var dto := _expect_dictionary(value, path, file_path, issues)
	var event := WorldEventState.create(
		_read_id(dto, "instance_id", path, file_path, issues),
		_read_id(dto, "event_key", path, file_path, issues),
		_read_int(dto, "week_index", path, file_path, issues),
		_read_id(dto, "source_id", path, file_path, issues),
		_read_id(dto, "related_problem_id", path, file_path, issues, true),
		_decode_ids(
			_read_array(dto, "effect_reason_codes", path, file_path, issues),
			path + ".effect_reason_codes",
			file_path,
			issues
		),
		_read_id(dto, "visibility", path, file_path, issues)
	)
	if event == null:
		issues.append(_invalid(file_path, path, "WorldEventState is invalid."))
	return event


static func _decode_message(
	value: Variant,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> MessageState:
	var dto := _expect_dictionary(value, path, file_path, issues)
	if not dto.has("parameters"):
		issues.append(_missing(file_path, path + ".parameters"))
	var parameters: Variant = _decode_variant(
		dto.get("parameters"), path + ".parameters", file_path, issues
	)
	if typeof(parameters) != TYPE_DICTIONARY:
		issues.append(_invalid(
			file_path, path + ".parameters", "Expected an object."
		))
		parameters = {}
	var message := MessageState.new(
		_read_id(dto, "instance_id", path, file_path, issues),
		_read_int(dto, "week_index", path, file_path, issues),
		_read_id(dto, "category", path, file_path, issues),
		_read_id(dto, "source_type", path, file_path, issues),
		_read_id(dto, "source_id", path, file_path, issues),
		_read_id(dto, "title_key", path, file_path, issues),
		_read_id(dto, "body_key", path, file_path, issues),
		parameters,
		_read_id(dto, "importance", path, file_path, issues),
		_read_int(dto, "sort_order", path, file_path, issues),
		_read_bool(dto, "is_read", path, file_path, issues)
	)
	if not message.validate().is_empty():
		issues.append(_invalid(file_path, path, "MessageState is invalid."))
		return null
	return message


static func _decode_reasons(
	values: Array,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> Array[ReasonEntry]:
	var reasons: Array[ReasonEntry] = []
	for index: int in range(values.size()):
		var item_path := path + "[%d]" % index
		var dto := _expect_dictionary(
			values[index], item_path, file_path, issues
		)
		if not dto.has("parameters"):
			issues.append(_missing(file_path, item_path + ".parameters"))
		var parameters: Variant = _decode_variant(
			dto.get("parameters"),
			item_path + ".parameters",
			file_path,
			issues
		)
		if typeof(parameters) != TYPE_DICTIONARY:
			issues.append(_invalid(
				file_path, item_path + ".parameters", "Expected an object."
			))
			parameters = {}
		var reason := ReasonEntry.create(
			_read_id(dto, "code", item_path, file_path, issues),
			_read_id(dto, "category", item_path, file_path, issues),
			_read_id(dto, "source_id", item_path, file_path, issues),
			_read_id(dto, "target_id", item_path, file_path, issues),
			_read_number(dto, "amount", item_path, file_path, issues),
			_read_id(
				dto, "localization_key", item_path, file_path, issues, true
			),
			parameters,
			_read_id(dto, "phase", item_path, file_path, issues, true),
			_read_id(dto, "visibility", item_path, file_path, issues)
		)
		for field_name: String in [
			"code",
			"category",
			"source_id",
			"target_id",
			"phase",
			"visibility",
		]:
			var field_value: StringName = StringName(dto.get(field_name, ""))
			if not field_value.is_empty() and not StableId.is_valid(field_value):
				issues.append(_invalid(
					file_path,
					item_path + "." + field_name,
					"Expected a stable ID."
				))
		if reason == null:
			issues.append(_invalid(file_path, item_path, "ReasonEntry is invalid."))
		else:
			reasons.append(reason)
	return reasons


## StringName values receive an explicit tag because plain JSON strings cannot
## preserve the distinction required by deterministic reason/message signatures.
static func _encode_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return {
				"__type": "integer",
				"value": value,
			}
		TYPE_STRING_NAME:
			return {
				"__type": "string_name",
				"value": String(value),
			}
		TYPE_ARRAY:
			var array: Array = []
			for item: Variant in value:
				array.append(_encode_variant(item))
			return array
		TYPE_DICTIONARY:
			var dictionary: Dictionary = {}
			for key: Variant in value:
				dictionary[String(key)] = _encode_variant(value[key])
			return dictionary
		_:
			return value


static func _decode_variant(
	value: Variant,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value
		if dictionary.get("__type") == "integer":
			var integer_value: Variant = dictionary.get("value")
			if not _is_json_integer(integer_value):
				issues.append(_invalid(
					file_path, path + ".value", "Expected an integer."
				))
				return 0
			return int(integer_value)
		if dictionary.get("__type") == "string_name":
			if typeof(dictionary.get("value")) != TYPE_STRING:
				issues.append(_invalid(
					file_path, path + ".value", "Expected a string."
				))
				return &""
			return StringName(dictionary["value"])
		var decoded: Dictionary = {}
		for key: Variant in dictionary:
			decoded[str(key)] = _decode_variant(
				dictionary[key],
				path + "." + str(key),
				file_path,
				issues
			)
		return decoded
	if typeof(value) == TYPE_ARRAY:
		var decoded: Array = []
		for index: int in range(value.size()):
			decoded.append(_decode_variant(
				value[index],
				path + "[%d]" % index,
				file_path,
				issues
			))
		return decoded
	if (
		value == null
		or typeof(value) == TYPE_BOOL
		or typeof(value) == TYPE_INT
		or typeof(value) == TYPE_FLOAT
		or typeof(value) == TYPE_STRING
	):
		return value
	issues.append(_invalid(
		file_path, path, "Unsupported JSON value type."
	))
	return null


static func _encode_ids(values: Array) -> Array:
	var encoded: Array = []
	for value: StringName in values:
		encoded.append(String(value))
	return encoded


static func _decode_ids(
	values: Array,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> Array[StringName]:
	var decoded: Array[StringName] = []
	for index: int in range(values.size()):
		if typeof(values[index]) != TYPE_STRING:
			issues.append(_invalid(
				file_path, path + "[%d]" % index, "Expected a string."
			))
			continue
		var value := StringName(values[index])
		if not StableId.is_valid(value):
			issues.append(_invalid(
				file_path, path + "[%d]" % index, "Expected a stable ID."
			))
			continue
		decoded.append(value)
	return decoded


static func _encode_id_int_dictionary(values: Dictionary) -> Dictionary:
	var encoded: Dictionary = {}
	for key: Variant in values:
		encoded[String(key)] = values[key]
	return encoded


static func _decode_id_int_dictionary(
	values: Dictionary,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> Dictionary[StringName, int]:
	var decoded: Dictionary[StringName, int] = {}
	for key: Variant in values:
		if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
			issues.append(_invalid(file_path, path, "Expected string keys."))
			continue
		var value: Variant = values[key]
		if not _is_json_integer(value):
			issues.append(_invalid(
				file_path, path + "." + str(key), "Expected an integer."
			))
			continue
		decoded[StringName(str(key))] = int(value)
	return decoded


static func _read_dictionary(
	parent: Dictionary,
	key: String,
	parent_path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> Dictionary:
	if not parent.has(key):
		issues.append(_missing(file_path, parent_path + "." + key))
		return {}
	return _expect_dictionary(
		parent[key], parent_path + "." + key, file_path, issues
	)


static func _expect_dictionary(
	value: Variant,
	path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		issues.append(_invalid(file_path, path, "Expected an object."))
		return {}
	return value


static func _read_array(
	parent: Dictionary,
	key: String,
	parent_path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> Array:
	if not parent.has(key):
		issues.append(_missing(file_path, parent_path + "." + key))
		return []
	if typeof(parent[key]) != TYPE_ARRAY:
		issues.append(_invalid(
			file_path, parent_path + "." + key, "Expected an array."
		))
		return []
	return parent[key]


static func _read_string(
	parent: Dictionary,
	key: String,
	parent_path: String,
	file_path: String,
	issues: Array[SaveIssue],
	allow_empty: bool = false
) -> String:
	if not parent.has(key):
		issues.append(_missing(file_path, parent_path + "." + key))
		return ""
	var value: Variant = parent[key]
	if typeof(value) != TYPE_STRING:
		issues.append(_invalid(
			file_path, parent_path + "." + key, "Expected a string."
		))
		return ""
	if not allow_empty and String(value).is_empty():
		issues.append(_invalid(
			file_path, parent_path + "." + key, "String cannot be empty."
		))
	return value


static func _read_id(
	parent: Dictionary,
	key: String,
	parent_path: String,
	file_path: String,
	issues: Array[SaveIssue],
	allow_empty: bool = false
) -> StringName:
	return StringName(_read_string(
		parent, key, parent_path, file_path, issues, allow_empty
	))


static func _read_int(
	parent: Dictionary,
	key: String,
	parent_path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> int:
	if not parent.has(key):
		issues.append(_missing(file_path, parent_path + "." + key))
		return 0
	var value: Variant = parent[key]
	if not _is_json_integer(value):
		issues.append(_invalid(
			file_path, parent_path + "." + key, "Expected an integer."
		))
		return 0
	return int(value)


static func _read_number(
	parent: Dictionary,
	key: String,
	parent_path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> float:
	if not parent.has(key):
		issues.append(_missing(file_path, parent_path + "." + key))
		return 0.0
	var value: Variant = parent[key]
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		issues.append(_invalid(
			file_path, parent_path + "." + key, "Expected a number."
		))
		return 0.0
	return float(value)


static func _read_bool(
	parent: Dictionary,
	key: String,
	parent_path: String,
	file_path: String,
	issues: Array[SaveIssue]
) -> bool:
	if not parent.has(key):
		issues.append(_missing(file_path, parent_path + "." + key))
		return false
	if typeof(parent[key]) != TYPE_BOOL:
		issues.append(_invalid(
			file_path, parent_path + "." + key, "Expected a boolean."
		))
		return false
	return parent[key]


static func _is_json_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (
		typeof(value) == TYPE_FLOAT
		and is_finite(value)
		and value == floor(value)
	)


static func _missing(file_path: String, path: String) -> SaveIssue:
	return _issue(file_path, path, &"missing_field", "Required field is missing.")


static func _invalid(
	file_path: String,
	path: String,
	message: String
) -> SaveIssue:
	return _issue(file_path, path, &"invalid_field", message)


static func _issue(
	file_path: String,
	path: String,
	code: StringName,
	message: String
) -> SaveIssue:
	return SaveIssue.create(code, file_path, path, message)
