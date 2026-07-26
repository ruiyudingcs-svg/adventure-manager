class_name ResolutionViewData
extends RefCounted


class PhaseRow extends RefCounted:
	var phase: StringName
	var check_type: StringName
	var score: int
	var result_tier: StringName
	var reason_keys: Array[StringName]


class ClauseRow extends RefCounted:
	var clause_id: StringName
	var title_key: StringName
	var importance: StringName
	var satisfied: bool
	var evidence: Array[StringName]


class MemberRow extends RefCounted:
	var member_id: StringName
	var display_name: String
	var fatigue_delta: int
	var injury_result: StringName
	var injury_severity_after: int
	var recovery_weeks_after: int
	var available_after: bool
	var morale_delta: int


class ChangeRow extends RefCounted:
	var target_id: StringName
	var field_path: String
	var old_value: Variant
	var new_value: Variant
	var reason_codes: Array[StringName]


class ReasonRow extends RefCounted:
	var code: StringName
	var localization_key: StringName
	var target_id: StringName
	var amount: float
	var phase: StringName


var resolved_week: int
var next_week: int
var ending_id: StringName
var skipped_contract: bool
var contract_title_key: StringName
var sponsor_name_key: StringName
var final_tier: StringName
var reward: int
var supply_cost_total: int
var sponsor_relation_delta: int
var phases: Array[PhaseRow]
var clauses: Array[ClauseRow]
var members: Array[MemberRow]
var changes: Array[ChangeRow]
var reasons: Array[ReasonRow]
var faction_action_titles: Array[StringName]
