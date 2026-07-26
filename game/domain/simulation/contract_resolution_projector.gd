class_name ContractResolutionProjector
extends RefCounted

const CampaignState = preload(
	"res://game/domain/campaign/campaign_state.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const ContractResolution = preload(
	"res://game/domain/contracts/contract_resolution.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const MemberOutcome = preload(
	"res://game/domain/contracts/member_outcome.gd"
)
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const StateOperation = preload("res://game/core/result/state_operation.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const StableId = preload("res://game/core/ids/stable_id.gd")

const SOURCE_WORLD: int = 100
const SOURCE_OUTCOME: int = 300
const SOURCE_MEMBER: int = 400
const SOURCE_SPONSOR: int = 500
const SOURCE_HISTORY: int = 800


class ProjectionResult extends RefCounted:
	var operations: Array[StateOperation]
	var issues: PackedStringArray

	func is_success() -> bool:
		return issues.is_empty()


## Converts one locked resolution into a transaction batch. The base state is
## read only to preflight funds/targets and convert absolute member outcomes into
## deltas; mutation remains exclusively owned by CampaignTransaction.
static func project(
	base_state: CampaignState,
	resolution: ContractResolution,
	sponsor_faction_id: StringName,
	contract_definition_id: StringName,
	related_problem_id: StringName = &"",
	approach: StringName = &"balanced",
	offer: ContractOfferState = null
) -> ProjectionResult:
	var result := ProjectionResult.new()
	if base_state == null or resolution == null:
		result.issues.append("Projection requires CampaignState and ContractResolution.")
		return result
	if resolution.supply_cost_total < 0:
		result.issues.append("ContractResolution.supply_cost_total must be non-negative.")
	if resolution.reward < 0:
		result.issues.append("ContractResolution.reward must be non-negative.")
	if base_state.guild.gold < resolution.supply_cost_total:
		result.issues.append("Guild gold is insufficient for locked supply cost.")
	if not base_state.factions.has(sponsor_faction_id):
		result.issues.append("Unknown sponsor faction: %s." % sponsor_faction_id)
	if not StableId.is_valid(contract_definition_id):
		result.issues.append(StableId.validation_error(
			contract_definition_id,
			"contract_definition_id"
		))
	if not result.issues.is_empty():
		return result

	_append_numeric(
		result.operations,
		CampaignTransaction.TARGET_GUILD,
		CampaignTransaction.ID_GUILD,
		CampaignTransaction.FIELD_GOLD,
		resolution.reward,
		&"contract_reward",
		SOURCE_OUTCOME
	)
	_append_numeric(
		result.operations,
		CampaignTransaction.TARGET_GUILD,
		CampaignTransaction.ID_GUILD,
		CampaignTransaction.FIELD_GOLD,
		-resolution.supply_cost_total,
		&"supply_purchase",
		SOURCE_OUTCOME + 1
	)

	var ordered_outcomes: Array[MemberOutcome] = []
	ordered_outcomes.assign(resolution.member_outcomes)
	ordered_outcomes.sort_custom(_member_outcome_less)
	var member_ids: Array[StringName] = []
	var member_index: int = 0
	for outcome: MemberOutcome in ordered_outcomes:
		if not base_state.adventurers.has(outcome.member_id):
			result.issues.append("Unknown member outcome target: %s." % outcome.member_id)
			continue
		if member_ids.has(outcome.member_id):
			result.issues.append("Duplicate member outcome target: %s." % outcome.member_id)
			continue
		if (
			outcome.injury_severity_after < 0
			or outcome.injury_severity_after > 100
			or outcome.recovery_weeks_after < 0
		):
			result.issues.append("Member outcome has invalid terminal injury values.")
			continue
		member_ids.append(outcome.member_id)
		var member = base_state.adventurers[outcome.member_id]
		var source_order: int = SOURCE_MEMBER + member_index
		_append_numeric(
			result.operations,
			CampaignTransaction.TARGET_ADVENTURER,
			outcome.member_id,
			CampaignTransaction.FIELD_FATIGUE,
			outcome.fatigue_delta,
			&"contract_member_fatigue",
			source_order
		)
		_append_numeric(
			result.operations,
			CampaignTransaction.TARGET_ADVENTURER,
			outcome.member_id,
			CampaignTransaction.FIELD_INJURY_SEVERITY,
			outcome.injury_severity_after - member.get_injury_severity(),
			&"contract_member_injury",
			source_order
		)
		_append_numeric(
			result.operations,
			CampaignTransaction.TARGET_ADVENTURER,
			outcome.member_id,
			CampaignTransaction.FIELD_RECOVERY_WEEKS,
			outcome.recovery_weeks_after - member.get_recovery_weeks_remaining(),
			&"contract_member_recovery",
			source_order
		)
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_ADVENTURER,
			outcome.member_id,
			CampaignTransaction.FIELD_AVAILABILITY,
			StateOperation.OP_SET_ID,
			(
				CampaignTransaction.VALUE_AVAILABLE
				if outcome.is_available_after
				else CampaignTransaction.VALUE_UNAVAILABLE
			),
			&"contract_member_availability",
			source_order
		))
		_append_numeric(
			result.operations,
			CampaignTransaction.TARGET_ADVENTURER,
			outcome.member_id,
			CampaignTransaction.FIELD_MORALE,
			outcome.morale_delta,
			&"contract_member_morale",
			source_order
		)
		member_index += 1

	_append_numeric(
		result.operations,
		CampaignTransaction.TARGET_FACTION,
		sponsor_faction_id,
		CampaignTransaction.FIELD_RELATION,
		resolution.sponsor_relation_delta,
		&"contract_sponsor_relation",
		SOURCE_SPONSOR
	)

	var event_reason_map: Dictionary[StringName, Array] = {}
	var world_effect_index: int = 0
	for effect: WorldEffect in resolution.situation_outcomes:
		var world_source_order: int = SOURCE_WORLD + world_effect_index
		match effect.type:
			&"modify_clock":
				_append_numeric(
					result.operations,
					CampaignTransaction.TARGET_CLOCK,
					effect.target_id,
					CampaignTransaction.FIELD_VALUE,
					effect.amount,
					effect.reason_code,
					world_source_order
				)
			&"change_phase":
				_append_set(
					result.operations,
					base_state.situation.definition_id,
					CampaignTransaction.FIELD_PHASE_ID,
					effect.target_id,
					effect.reason_code,
					world_source_order
				)
			&"unlock_contract":
				result.operations.append(StateOperation.create(
					CampaignTransaction.TARGET_SITUATION,
					base_state.situation.definition_id,
					CampaignTransaction.FIELD_UNLOCKED_CONTRACT_IDS,
					StateOperation.OP_ADD_UNIQUE,
					effect.target_id,
					effect.reason_code,
					world_source_order
				))
			&"set_ending":
				_append_set(
					result.operations,
					base_state.situation.definition_id,
					CampaignTransaction.FIELD_ENDING_ID,
					effect.target_id,
					effect.reason_code,
					world_source_order
				)
			&"create_world_event":
				if not event_reason_map.has(effect.target_id):
					event_reason_map[effect.target_id] = []
				event_reason_map[effect.target_id].append(effect.reason_code)
			_:
				result.issues.append("Unsupported Task007 WorldEffect: %s." % effect.type)
		world_effect_index += 1

	if not result.issues.is_empty():
		result.operations.clear()
		return result

	var world_event_ids: Array[StringName] = []
	var event_keys: Array[StringName] = []
	event_keys.assign(event_reason_map.keys())
	event_keys.sort()
	for event_key: StringName in event_keys:
		var event_id := StringName("%s_%s" % [resolution.contract_instance_id, event_key])
		var reason_values: Array[StringName] = []
		reason_values.assign(event_reason_map[event_key])
		reason_values.sort()
		var event := WorldEventState.create(
			event_id,
			event_key,
			base_state.week_index,
			resolution.contract_instance_id,
			related_problem_id,
			reason_values
		)
		if event == null:
			result.issues.append("Could not create world event %s." % event_key)
			continue
		world_event_ids.append(event.instance_id)
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_WORLD_EVENTS,
			StateOperation.OP_APPEND_RECORD,
			event,
			reason_values[0],
			SOURCE_WORLD
		))

	var history: ContractHistoryEntry
	if offer == null:
		history = ContractHistoryEntry.create_resolved(
			base_state.week_index,
			resolution.contract_instance_id,
			contract_definition_id,
			sponsor_faction_id,
			related_problem_id,
			member_ids,
			resolution.consumed_supply_ids,
			approach,
			resolution.result_tier,
			resolution.reward,
			resolution.outcome_tags,
			world_event_ids
		)
	elif (
		offer.instance_id != resolution.contract_instance_id
		or offer.definition_id != contract_definition_id
		or offer.sponsor_faction_id != sponsor_faction_id
	):
		result.issues.append("Resolved Offer metadata does not match ContractResolution.")
	else:
		history = ContractHistoryEntry.new(
			base_state.week_index,
			offer.offered_week,
			offer.instance_id,
			offer.definition_id,
			offer.sponsor_faction_id,
			offer.origin_type,
			offer.related_problem_id,
			offer.target_lock_key,
			ContractHistoryEntry.STATUS_RESOLVED,
			&"contract_resolved",
			member_ids,
			resolution.consumed_supply_ids,
			approach,
			resolution.result_tier,
			resolution.reward,
			{"outcome_tags": resolution.outcome_tags.duplicate()},
			[],
			world_event_ids,
			offer.generation_reason_entries
		)
		if not history.validate().is_empty():
			history = null
	if history == null:
		result.issues.append("Could not create resolved contract history entry.")
	else:
		result.operations.append(StateOperation.create(
			CampaignTransaction.TARGET_CAMPAIGN,
			CampaignTransaction.ID_CAMPAIGN,
			CampaignTransaction.FIELD_CONTRACT_HISTORY,
			StateOperation.OP_APPEND_RECORD,
			history,
			&"contract_history",
			SOURCE_HISTORY
		))
	if not result.issues.is_empty():
		result.operations.clear()
	return result


static func _append_numeric(
	operations: Array[StateOperation],
	target_kind: StringName,
	target_id: StringName,
	field_id: StringName,
	value: int,
	reason_code: StringName,
	source_order: int
) -> void:
	if value == 0:
		return
	operations.append(StateOperation.create(
		target_kind,
		target_id,
		field_id,
		StateOperation.OP_ADD_INT,
		value,
		reason_code,
		source_order
	))


static func _append_set(
	operations: Array[StateOperation],
	situation_id: StringName,
	field_id: StringName,
	value: StringName,
	reason_code: StringName,
	source_order: int
) -> void:
	operations.append(StateOperation.create(
		CampaignTransaction.TARGET_SITUATION,
		situation_id,
		field_id,
		StateOperation.OP_SET_ID,
		value,
		reason_code,
		source_order
	))


static func _member_outcome_less(left: MemberOutcome, right: MemberOutcome) -> bool:
	return String(left.member_id) < String(right.member_id)
