class_name CampaignState
extends RefCounted

const AdventurerState = preload(
	"res://game/domain/adventurers/adventurer_state.gd"
)
const GuildState = preload("res://game/domain/guild/guild_state.gd")
const FactionState = preload("res://game/domain/factions/faction_state.gd")
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const ContractPlanState = preload(
	"res://game/domain/contracts/contract_plan_state.gd"
)
const FactionActionCommitmentState = preload(
	"res://game/domain/factions/faction_action_commitment_state.gd"
)
const MessageState = preload("res://game/domain/messages/message_state.gd")

const CURRENT_SAVE_VERSION: int = 1

var save_version: int
var campaign_seed: int
var week_index: int
var guild: GuildState
var adventurers: Dictionary[StringName, AdventurerState] = {}
var factions: Dictionary[StringName, FactionState] = {}
var situation: SituationState
var contract_history: Array[ContractHistoryEntry]
var world_events: Array[WorldEventState]
var pending_contracts: Array[ContractOfferState]
var active_plan: ContractPlanState
var declined_offer_week: int
var faction_action_commitments: Array[FactionActionCommitmentState]
var message_history: Array[MessageState]


static func create(
	p_campaign_seed: int,
	p_week_index: int,
	p_guild: GuildState,
	p_adventurers: Dictionary[StringName, AdventurerState],
	p_factions: Dictionary[StringName, FactionState],
	p_situation: SituationState,
	p_contract_history: Array[ContractHistoryEntry] = [],
	p_world_events: Array[WorldEventState] = [],
	p_save_version: int = CURRENT_SAVE_VERSION,
	p_pending_contracts: Array[ContractOfferState] = [],
	p_active_plan: ContractPlanState = null,
	p_declined_offer_week: int = -1,
	p_faction_action_commitments: Array[FactionActionCommitmentState] = [],
	p_message_history: Array[MessageState] = []
) -> CampaignState:
	var state := CampaignState.new(
		p_save_version,
		p_campaign_seed,
		p_week_index,
		p_guild,
		p_adventurers,
		p_factions,
		p_situation,
		p_contract_history,
		p_world_events,
		p_pending_contracts,
		p_active_plan,
		p_declined_offer_week,
		p_faction_action_commitments,
		p_message_history
	)
	if not state.validate().is_empty():
		return null
	return state


func _init(
	p_save_version: int,
	p_campaign_seed: int,
	p_week_index: int,
	p_guild: GuildState,
	p_adventurers: Dictionary[StringName, AdventurerState],
	p_factions: Dictionary[StringName, FactionState],
	p_situation: SituationState,
	p_contract_history: Array[ContractHistoryEntry],
	p_world_events: Array[WorldEventState],
	p_pending_contracts: Array[ContractOfferState],
	p_active_plan: ContractPlanState,
	p_declined_offer_week: int,
	p_faction_action_commitments: Array[FactionActionCommitmentState],
	p_message_history: Array[MessageState]
) -> void:
	save_version = p_save_version
	campaign_seed = p_campaign_seed
	week_index = p_week_index
	guild = p_guild.duplicate_state() if p_guild != null else null
	for member_id: StringName in p_adventurers:
		var member: AdventurerState = p_adventurers[member_id]
		adventurers[member_id] = member.duplicate_state() if member != null else null
	for faction_id: StringName in p_factions:
		var faction: FactionState = p_factions[faction_id]
		factions[faction_id] = faction.duplicate_state() if faction != null else null
	situation = p_situation.duplicate_state() if p_situation != null else null
	for entry: ContractHistoryEntry in p_contract_history:
		contract_history.append(entry.duplicate_state() if entry != null else null)
	for event: WorldEventState in p_world_events:
		world_events.append(event.duplicate_state() if event != null else null)
	for offer: ContractOfferState in p_pending_contracts:
		pending_contracts.append(offer.duplicate_state() if offer != null else null)
	active_plan = p_active_plan.duplicate_state() if p_active_plan != null else null
	declined_offer_week = p_declined_offer_week
	for commitment: FactionActionCommitmentState in p_faction_action_commitments:
		faction_action_commitments.append(
			commitment.duplicate_state() if commitment != null else null
		)
	for message: MessageState in p_message_history:
		message_history.append(
			message.duplicate_state() if message != null else null
		)


## Validates owned state and all references that can be checked without Definitions.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if save_version != CURRENT_SAVE_VERSION:
		errors.append("CampaignState.save_version is unsupported: %d." % save_version)
	if week_index < 0:
		errors.append("CampaignState.week_index must be non-negative.")
	if guild == null:
		errors.append("CampaignState.guild is required.")
	else:
		errors.append_array(guild.validate())
	if situation == null:
		errors.append("CampaignState.situation is required.")
	else:
		errors.append_array(situation.validate())

	for member_id: StringName in adventurers:
		var member: AdventurerState = adventurers[member_id]
		if member == null:
			errors.append("CampaignState adventurer %s is null." % member_id)
			continue
		if member.definition_id != member_id:
			errors.append("CampaignState adventurer key must equal its definition ID.")
		errors.append_array(AdventurerState.validate_values(
			member.definition_id,
			member.get_fatigue(),
			member.get_morale(),
			member.get_injury_severity(),
			member.get_recovery_weeks_remaining(),
			member.get_growth_xp(),
			member.get_relationship_deltas(),
			member.get_recent_assignment_count(),
			member.get_recent_neglect_count()
		))
		for target_id: StringName in member.get_relationship_deltas():
			if not adventurers.has(target_id):
				errors.append("Adventurer %s references missing member %s." % [member_id, target_id])

	for faction_id: StringName in factions:
		var faction: FactionState = factions[faction_id]
		if faction == null:
			errors.append("CampaignState faction %s is null." % faction_id)
			continue
		if faction.definition_id != faction_id:
			errors.append("CampaignState faction key must equal its definition ID.")
		errors.append_array(faction.validate())

	var event_ids: Dictionary[StringName, bool] = {}
	for event: WorldEventState in world_events:
		if event == null:
			errors.append("CampaignState.world_events cannot contain null.")
			continue
		errors.append_array(event.validate())
		if event_ids.has(event.instance_id):
			errors.append("Duplicate world event ID: %s." % event.instance_id)
		event_ids[event.instance_id] = true
		if (
			not event.related_problem_id.is_empty()
			and situation != null
			and not situation.problems.has(event.related_problem_id)
		):
			errors.append("World event references missing problem %s." % event.related_problem_id)

	var history_ids: Dictionary[StringName, bool] = {}
	for entry: ContractHistoryEntry in contract_history:
		if entry == null:
			errors.append("CampaignState.contract_history cannot contain null.")
			continue
		errors.append_array(entry.validate())
		if history_ids.has(entry.contract_instance_id):
			errors.append("Duplicate contract history ID: %s." % entry.contract_instance_id)
		history_ids[entry.contract_instance_id] = true
		if not factions.has(entry.sponsor_faction_id):
			errors.append("Contract history references missing faction %s." % entry.sponsor_faction_id)
		for member_id: StringName in entry.member_ids:
			if not adventurers.has(member_id):
				errors.append("Contract history references missing member %s." % member_id)
		for event_id: StringName in entry.world_event_ids:
			if not event_ids.has(event_id):
				errors.append("Contract history references missing event %s." % event_id)

	if declined_offer_week < -1 or declined_offer_week > week_index:
		errors.append(
			"CampaignState.declined_offer_week must be -1 or not exceed week_index."
		)
	var offer_ids: Dictionary[StringName, bool] = {}
	var locked_targets: Dictionary[StringName, bool] = {}
	var pending_factions: Dictionary[StringName, bool] = {}
	var accepted_offer_id: StringName = &""
	for offer: ContractOfferState in pending_contracts:
		if offer == null:
			errors.append("CampaignState.pending_contracts cannot contain null.")
			continue
		errors.append_array(offer.validate())
		if offer_ids.has(offer.instance_id):
			errors.append("Duplicate contract offer ID: %s." % offer.instance_id)
		offer_ids[offer.instance_id] = true
		if offer.offered_week > week_index:
			errors.append(
				"Contract offer %s cannot be offered in a future week."
				% offer.instance_id
			)
		if offer.resolved_week > week_index:
			errors.append(
				"Contract offer %s cannot resolve in a future week."
				% offer.instance_id
			)
		if offer.status == ContractOfferState.STATUS_PENDING:
			if pending_factions.has(offer.sponsor_faction_id):
				errors.append(
					"Faction %s has more than one pending contract offer."
					% offer.sponsor_faction_id
				)
			pending_factions[offer.sponsor_faction_id] = true
		elif offer.status == ContractOfferState.STATUS_ACCEPTED:
			if not accepted_offer_id.is_empty():
				errors.append("CampaignState may contain at most one accepted offer.")
			accepted_offer_id = offer.instance_id
		elif offer.status != ContractOfferState.STATUS_DECLINED:
			errors.append(
				"Only pending, accepted, or transient declined offers may remain in pending_contracts."
			)
		if (
			offer.status == ContractOfferState.STATUS_PENDING
			or offer.status == ContractOfferState.STATUS_ACCEPTED
		):
			if locked_targets.has(offer.target_lock_key):
				errors.append("Duplicate active contract target lock: %s." % offer.target_lock_key)
			locked_targets[offer.target_lock_key] = true
		if not factions.has(offer.sponsor_faction_id):
			errors.append(
				"Contract offer references missing faction %s." % offer.sponsor_faction_id
			)
		if (
			not offer.related_problem_id.is_empty()
			and situation != null
			and not situation.problems.has(offer.related_problem_id)
		):
			errors.append(
				"Contract offer references missing problem %s." % offer.related_problem_id
			)
	if active_plan == null:
		if not accepted_offer_id.is_empty():
			errors.append("Accepted contract offer requires CampaignState.active_plan.")
	else:
		errors.append_array(active_plan.validate())
		if active_plan.contract_instance_id != accepted_offer_id:
			errors.append(
				"CampaignState.active_plan must reference the sole accepted offer."
			)
		for member_id: StringName in active_plan.selected_member_ids:
			if not adventurers.has(member_id):
				errors.append("Active plan references missing member %s." % member_id)

	var commitment_ids: Dictionary[StringName, bool] = {}
	var committed_faction_weeks: Dictionary[String, bool] = {}
	for commitment: FactionActionCommitmentState in faction_action_commitments:
		if commitment == null:
			errors.append(
				"CampaignState.faction_action_commitments cannot contain null."
			)
			continue
		errors.append_array(commitment.validate())
		if commitment_ids.has(commitment.instance_id):
			errors.append(
				"Duplicate faction action commitment ID: %s."
				% commitment.instance_id
			)
		commitment_ids[commitment.instance_id] = true
		if not factions.has(commitment.faction_id):
			errors.append(
				"Faction action commitment references missing faction %s."
				% commitment.faction_id
			)
		if commitment.committed_week > week_index:
			errors.append("Faction action commitment cannot be created in a future week.")
		# Week-end effects are dated for the opening boundary of week N + 1,
		# while CampaignState.week_index advances only in the next open_week call.
		if commitment.resolved_week > week_index + 1:
			errors.append(
				"Faction action commitment cannot resolve beyond the next week."
			)
		if commitment.status == FactionActionCommitmentState.STATUS_COMMITTED:
			var faction_week_key := "%s|%d" % [
				commitment.faction_id,
				commitment.committed_week,
			]
			if committed_faction_weeks.has(faction_week_key):
				errors.append(
					"A faction can have at most one committed action per week."
				)
			committed_faction_weeks[faction_week_key] = true
			if locked_targets.has(commitment.target_lock_key):
				errors.append(
					"Duplicate active target lock: %s."
					% commitment.target_lock_key
				)
			locked_targets[commitment.target_lock_key] = true
		for event_id: StringName in commitment.world_event_ids:
			if not event_ids.has(event_id):
				errors.append(
					"Faction action commitment references missing event %s."
					% event_id
				)

	var message_ids: Dictionary[StringName, bool] = {}
	var message_sort_slots: Dictionary[String, bool] = {}
	for message: MessageState in message_history:
		if message == null:
			errors.append("CampaignState.message_history cannot contain null.")
			continue
		errors.append_array(message.validate())
		if message_ids.has(message.instance_id):
			errors.append("Duplicate message ID: %s." % message.instance_id)
		message_ids[message.instance_id] = true
		if message.week_index > week_index:
			errors.append("Message cannot be dated in a future week.")
		var sort_slot := "%d|%d" % [message.week_index, message.sort_order]
		if message_sort_slots.has(sort_slot):
			errors.append(
				"Message sort_order must be unique within its week: %s."
				% sort_slot
			)
		message_sort_slots[sort_slot] = true
	return errors


func duplicate_state() -> CampaignState:
	return CampaignState.new(
		save_version,
		campaign_seed,
		week_index,
		guild,
		adventurers,
		factions,
		situation,
		contract_history,
		world_events,
		pending_contracts,
		active_plan,
		declined_offer_week,
		faction_action_commitments,
		message_history
	)
