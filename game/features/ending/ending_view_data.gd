## Detached, read-only projection of the committed final CampaignState.
class_name EndingViewData
extends RefCounted


class ClockRow extends RefCounted:
	var id: StringName
	var label_key: StringName
	var value: int


class EventRow extends RefCounted:
	var event_key: StringName
	var week_index: int


class ProblemRow extends RefCounted:
	var title_key: StringName
	var status: StringName
	var closed_week: int


class ContractRow extends RefCounted:
	var title_key: StringName
	var terminal_status: StringName
	var result_tier: StringName
	var reward: int
	var week_index: int


class FactionRow extends RefCounted:
	var name_key: StringName
	var relation: int


class MemberRow extends RefCounted:
	var display_name: String
	var fatigue: int
	var injury_severity: int
	var recovery_weeks: int
	var morale: int


var ending_id: StringName
var title_key: StringName
var description_key: StringName
var ending_week: int
var clocks: Array[ClockRow]
var events: Array[EventRow]
var problems: Array[ProblemRow]
var contracts: Array[ContractRow]
var factions: Array[FactionRow]
var members: Array[MemberRow]
var reason_keys: Array[StringName]
