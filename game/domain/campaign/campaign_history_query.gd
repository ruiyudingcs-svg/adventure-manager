class_name CampaignHistoryQuery
extends RefCounted

const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const ContractHistoryEntry = preload(
	"res://game/domain/campaign/contract_history_entry.gd"
)
const WeeklyParticipationSnapshot = preload(
	"res://game/domain/campaign/weekly_participation_snapshot.gd"
)


class ParticipationQueryResult extends RefCounted:
	var snapshot: WeeklyParticipationSnapshot
	var issues: PackedStringArray

	func is_success() -> bool:
		return snapshot != null and issues.is_empty()


## Projects player participation from committed resolved history. History remains
## the sole persisted attendance owner (Accepted Gate D, section 2).
static func participation_for_week(
	campaign_state: CampaignState,
	week_index: int
) -> ParticipationQueryResult:
	var result := ParticipationQueryResult.new()
	if campaign_state == null:
		result.issues.append("CampaignHistoryQuery requires CampaignState.")
		return result
	if week_index < 0:
		result.issues.append("Participation week must be non-negative.")
		return result

	var resolved_count := 0
	var assigned_ids: Array[StringName] = []
	for entry: ContractHistoryEntry in campaign_state.contract_history:
		if (
			entry.week_index != week_index
			or entry.terminal_status != ContractHistoryEntry.STATUS_RESOLVED
		):
			continue
		resolved_count += 1
		for member_id: StringName in entry.member_ids:
			if not campaign_state.adventurers.has(member_id):
				result.issues.append(
					"Resolved history references missing member %s." % member_id
				)
			elif not assigned_ids.has(member_id):
				assigned_ids.append(member_id)
	if resolved_count > 1:
		result.issues.append(
			"Week %d contains more than one resolved player contract." % week_index
		)
	if not result.issues.is_empty():
		return result
	assigned_ids.sort()
	result.snapshot = WeeklyParticipationSnapshot.new(week_index, assigned_ids)
	return result
