class_name WeeklyUpkeepResolver
extends RefCounted

const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const AdventurerState = preload(
	"res://game/domain/adventurers/adventurer_state.gd"
)
const WeeklyParticipationSnapshot = preload(
	"res://game/domain/campaign/weekly_participation_snapshot.gd"
)
const StateOperation = preload("res://game/core/result/state_operation.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)

const LIGHT_TREATMENT_COST: int = 10
const HEAVY_TREATMENT_COST: int = 20
const REST_FATIGUE_RECOVERY: int = 20
const SHORTFALL_MORALE_PENALTY: int = 5
const SHORTFALL_REPUTATION_PENALTY: int = 5
const RECENT_COUNT_CAP: int = 3

const SOURCE_PAYMENT: int = 10
const SOURCE_SHORTFALL: int = 20
const SOURCE_RECOVERY: int = 30
const SOURCE_RECENT: int = 100


class WeeklyUpkeepResult extends RefCounted:
	var operations: Array[StateOperation]
	var reason_entries: Array[ReasonEntry]
	var issues: PackedStringArray
	var required_upkeep: int
	var paid: int
	var shortfall: int

	func is_success() -> bool:
		return issues.is_empty()


## Produces Gate D operations only; it never interprets contract history.
static func resolve(
	current_week: int,
	campaign_state: CampaignState,
	adventurer_definitions: Array[AdventurerDefinition],
	previous_week_participation: WeeklyParticipationSnapshot
) -> WeeklyUpkeepResult:
	var result := WeeklyUpkeepResult.new()
	if campaign_state == null or previous_week_participation == null:
		result.issues.append("Weekly upkeep requires state and participation.")
		return result
	if current_week < 2 or current_week != campaign_state.week_index + 1:
		result.issues.append(
			"Weekly upkeep must open the next campaign week, starting at week 2."
		)
	if previous_week_participation.week_index != current_week - 1:
		result.issues.append("Participation snapshot must describe the previous week.")
	result.issues.append_array(campaign_state.validate())

	var definition_map: Dictionary[StringName, AdventurerDefinition] = {}
	for definition: AdventurerDefinition in adventurer_definitions:
		if (
			definition == null
			or definition_map.has(definition.id)
			or not campaign_state.adventurers.has(definition.id)
		):
			result.issues.append("Upkeep adventurer definitions are incomplete or duplicated.")
			continue
		definition_map[definition.id] = definition
	if definition_map.size() != campaign_state.adventurers.size():
		result.issues.append("Upkeep requires one definition for every current member.")

	var member_ids: Array[StringName] = []
	member_ids.assign(campaign_state.adventurers.keys())
	member_ids.sort()
	for member_id: StringName in previous_week_participation.assigned_member_ids:
		if not campaign_state.adventurers.has(member_id):
			result.issues.append("Participation references missing member %s." % member_id)
	for member_id: StringName in member_ids:
		_validate_injury_state(campaign_state.adventurers[member_id], result.issues)
	if not result.issues.is_empty():
		return _clear(result)

	var wage_total := 0
	var treatment_total := 0
	for member_id: StringName in member_ids:
		wage_total += definition_map[member_id].wage
		var injury: int = campaign_state.adventurers[member_id].get_injury_severity()
		if injury >= 80:
			treatment_total += HEAVY_TREATMENT_COST
			result.reason_entries.append(_reason(
				&"upkeep_heavy_treatment_required", member_id,
				HEAVY_TREATMENT_COST, ReasonEntry.VISIBILITY_DEBUG
			))
		elif injury >= 30:
			treatment_total += LIGHT_TREATMENT_COST
			result.reason_entries.append(_reason(
				&"upkeep_light_treatment_required", member_id,
				LIGHT_TREATMENT_COST, ReasonEntry.VISIBILITY_DEBUG
			))
	result.required_upkeep = (
		wage_total + campaign_state.guild.weekly_maintenance + treatment_total
	)
	result.paid = mini(campaign_state.guild.gold, result.required_upkeep)
	result.shortfall = result.required_upkeep - result.paid
	result.reason_entries.push_front(_reason(
		&"upkeep_maintenance_required", &"guild",
		campaign_state.guild.weekly_maintenance, ReasonEntry.VISIBILITY_DEBUG
	))
	result.reason_entries.push_front(_reason(
		&"upkeep_wages_required", &"guild", wage_total, ReasonEntry.VISIBILITY_DEBUG
	))
	if result.paid != 0:
		result.operations.append(_numeric(
			CampaignTransaction.TARGET_GUILD,
			CampaignTransaction.ID_GUILD,
			CampaignTransaction.FIELD_GOLD,
			-result.paid,
			&"upkeep_payment",
			SOURCE_PAYMENT
		))
		result.reason_entries.append(_reason(
			&"upkeep_payment", &"guild", -result.paid, ReasonEntry.VISIBILITY_PLAYER
		))
	if result.shortfall > 0:
		result.reason_entries.append(_reason(
			&"upkeep_shortfall", &"guild", result.shortfall,
			ReasonEntry.VISIBILITY_PLAYER
		))
		result.operations.append(_numeric(
			CampaignTransaction.TARGET_GUILD,
			CampaignTransaction.ID_GUILD,
			CampaignTransaction.FIELD_REPUTATION,
			-SHORTFALL_REPUTATION_PENALTY,
			&"upkeep_shortfall_reputation",
			SOURCE_SHORTFALL
		))
		result.reason_entries.append(_reason(
			&"upkeep_shortfall_reputation", &"guild",
			-SHORTFALL_REPUTATION_PENALTY, ReasonEntry.VISIBILITY_PLAYER
		))

	var assigned: Array[StringName] = previous_week_participation.assigned_member_ids
	for index: int in range(member_ids.size()):
		var member_id: StringName = member_ids[index]
		var member: AdventurerState = campaign_state.adventurers[member_id]
		var participated := assigned.has(member_id)
		if result.shortfall > 0:
			result.operations.append(_numeric(
				CampaignTransaction.TARGET_ADVENTURER,
				member_id,
				CampaignTransaction.FIELD_MORALE,
				-SHORTFALL_MORALE_PENALTY,
				&"upkeep_shortfall_morale",
				SOURCE_SHORTFALL + index + 1
			))
			result.reason_entries.append(_reason(
				&"upkeep_shortfall_morale", member_id,
				-SHORTFALL_MORALE_PENALTY, ReasonEntry.VISIBILITY_PLAYER
			))
		if not participated:
			var fatigue_delta: int = -mini(REST_FATIGUE_RECOVERY, member.get_fatigue())
			if fatigue_delta != 0:
				result.operations.append(_numeric(
					CampaignTransaction.TARGET_ADVENTURER,
					member_id,
					CampaignTransaction.FIELD_FATIGUE,
					fatigue_delta,
					&"rest_fatigue_recovery",
					SOURCE_RECOVERY + index
				))
				result.reason_entries.append(_reason(
					&"rest_fatigue_recovery", member_id, fatigue_delta,
					ReasonEntry.VISIBILITY_PLAYER
				))
		_append_injury_recovery(result, member_id, member, index)
		_append_recent_counts(result, member_id, member, participated, index)
	return result


static func _validate_injury_state(
	member: AdventurerState,
	issues: PackedStringArray
) -> void:
	var injury := member.get_injury_severity()
	var recovery := member.get_recovery_weeks_remaining()
	var available := member.get_is_available()
	if injury >= 1 and injury <= 29:
		issues.append("Member %s has unsupported injury severity." % member.definition_id)
	elif injury == 0 and recovery > 0:
		issues.append("Healthy member %s has a recovery clock." % member.definition_id)
	elif injury > 0 and recovery == 0:
		issues.append("Injured member %s has no recovery clock." % member.definition_id)
	elif injury >= 80 and available:
		issues.append("Heavily injured member %s is available." % member.definition_id)
	elif injury < 80 and not available:
		issues.append("Member %s is unavailable without a heavy injury." % member.definition_id)


static func _append_injury_recovery(
	result: WeeklyUpkeepResult,
	member_id: StringName,
	member: AdventurerState,
	index: int
) -> void:
	if member.get_injury_severity() == 0:
		return
	var recovery_after: int = maxi(0, member.get_recovery_weeks_remaining() - 1)
	result.operations.append(_numeric(
		CampaignTransaction.TARGET_ADVENTURER,
		member_id,
		CampaignTransaction.FIELD_RECOVERY_WEEKS,
		-1,
		&"injury_recovery_week_elapsed",
		SOURCE_RECOVERY + 20 + index
	))
	result.reason_entries.append(_reason(
		&"injury_recovery_week_elapsed", member_id, -1,
		ReasonEntry.VISIBILITY_PLAYER
	))
	if recovery_after != 0:
		return
	result.operations.append(_numeric(
		CampaignTransaction.TARGET_ADVENTURER,
		member_id,
		CampaignTransaction.FIELD_INJURY_SEVERITY,
		-member.get_injury_severity(),
		&"injury_recovered",
		SOURCE_RECOVERY + 40 + index
	))
	result.operations.append(StateOperation.create(
		CampaignTransaction.TARGET_ADVENTURER,
		member_id,
		CampaignTransaction.FIELD_AVAILABILITY,
		StateOperation.OP_SET_ID,
		CampaignTransaction.VALUE_AVAILABLE,
		&"injury_recovered",
		SOURCE_RECOVERY + 40 + index
	))
	result.reason_entries.append(_reason(
		&"injury_recovered", member_id, -member.get_injury_severity(),
		ReasonEntry.VISIBILITY_PLAYER
	))


static func _append_recent_counts(
	result: WeeklyUpkeepResult,
	member_id: StringName,
	member: AdventurerState,
	participated: bool,
	index: int
) -> void:
	var assignment_after: int
	var neglect_after: int
	if participated:
		assignment_after = mini(RECENT_COUNT_CAP, member.get_recent_assignment_count() + 1)
		neglect_after = 0
	elif member.get_is_available():
		assignment_after = 0
		neglect_after = mini(RECENT_COUNT_CAP, member.get_recent_neglect_count() + 1)
	else:
		assignment_after = 0
		neglect_after = member.get_recent_neglect_count()
	var assignment_delta := assignment_after - member.get_recent_assignment_count()
	var neglect_delta := neglect_after - member.get_recent_neglect_count()
	if assignment_delta != 0:
		result.operations.append(_numeric(
			CampaignTransaction.TARGET_ADVENTURER,
			member_id,
			CampaignTransaction.FIELD_RECENT_ASSIGNMENT_COUNT,
			assignment_delta,
			&"recent_assignment_updated",
			SOURCE_RECENT + index
		))
		result.reason_entries.append(_reason(
			&"recent_assignment_updated", member_id, assignment_delta,
			ReasonEntry.VISIBILITY_PLAYER
		))
	if neglect_delta != 0:
		result.operations.append(_numeric(
			CampaignTransaction.TARGET_ADVENTURER,
			member_id,
			CampaignTransaction.FIELD_RECENT_NEGLECT_COUNT,
			neglect_delta,
			&"recent_neglect_updated",
			SOURCE_RECENT + 20 + index
		))
		result.reason_entries.append(_reason(
			&"recent_neglect_updated", member_id, neglect_delta,
			ReasonEntry.VISIBILITY_PLAYER
		))


static func _numeric(
	target_kind: StringName,
	target_id: StringName,
	field_id: StringName,
	value: int,
	reason_code: StringName,
	source_order: int
) -> StateOperation:
	return StateOperation.create(
		target_kind, target_id, field_id, StateOperation.OP_ADD_INT,
		value, reason_code, source_order
	)


static func _reason(
	code: StringName,
	target_id: StringName,
	amount: float,
	visibility: StringName
) -> ReasonEntry:
	return ReasonEntry.create(
		code, &"upkeep", &"weekly_upkeep", target_id, amount,
		code, {}, &"week_start", visibility
	)


static func _clear(result: WeeklyUpkeepResult) -> WeeklyUpkeepResult:
	result.operations.clear()
	result.reason_entries.clear()
	return result
