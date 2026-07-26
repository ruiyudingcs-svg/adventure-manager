class_name PlanningViewData
extends RefCounted


class OfferCard extends RefCounted:
	var offer_instance_id: StringName
	var title_key: StringName
	var sponsor_name_key: StringName
	var reward: int
	var remaining_turns: int
	var risk_level: int
	var origin_type: StringName
	var status: StringName
	var selected: bool
	var can_decline: bool
	var is_declined_placeholder: bool
	var reason_keys: Array[StringName]


class StageRow extends RefCounted:
	var phase: StringName
	var check_type: StringName


class ClauseRow extends RefCounted:
	var clause_id: StringName
	var title_key: StringName
	var description_key: StringName
	var category: StringName
	var importance: StringName
	var forecast_status: StringName


class MemberRow extends RefCounted:
	var member_id: StringName
	var display_name: String
	var selected: bool
	var available: bool
	var fatigue: int
	var morale: int
	var injury: int
	var capabilities: Dictionary[StringName, int]
	var attitude_status: StringName
	var injury_risk_band: StringName


class SupplyRow extends RefCounted:
	var supply_id: StringName
	var display_name_key: StringName
	var cost: int
	var selected: bool
	var allowed: bool


var offer_cards: Array[OfferCard]
var selected_offer_id: StringName
var selected_title_key: StringName
var selected_description_key: StringName
var selected_reward: int
var selected_risk_level: int
var stages: Array[StageRow]
var clauses: Array[ClauseRow]
var members: Array[MemberRow]
var supplies: Array[SupplyRow]
var approach: StringName
var selected_member_count: int
var selected_supply_count: int
var plan_signature: String
var likely_tier_low: StringName
var likely_tier_high: StringName
var supply_cost_total: int
var warning_keys: Array[StringName]
var validation_issues: PackedStringArray
var can_accept: bool
var plan_locked: bool
var decline_quota_used: bool
