## Detached member inspector and history projection.
class_name RosterViewData
extends RefCounted


class RelationshipItem extends RefCounted:
	var target_id: StringName
	var target_name_key: StringName
	var value: int


class RecordItem extends RefCounted:
	var week_index: int
	var contract_title_key: StringName
	var terminal_status: StringName
	var result_tier: StringName


class MemberItem extends RefCounted:
	var id: StringName
	var name_key: StringName
	var fallback_name: String
	var class_key: StringName
	var capabilities: Dictionary[StringName, int]
	var fatigue: int
	var morale: int
	var injury_severity: int
	var recovery_weeks: int
	var is_available: bool
	var trait_keys: Array[StringName]
	var values: Dictionary[StringName, int]
	var wage: int
	var relationships: Array[RelationshipItem]
	var recent_assignment_count: int
	var recent_neglect_count: int
	var recent_records: Array[RecordItem]


var members: Array[MemberItem]

