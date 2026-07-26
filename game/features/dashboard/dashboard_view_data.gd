## Detached Dashboard projection. It intentionally contains no urgency score.
class_name DashboardViewData
extends RefCounted


class ClockItem extends RefCounted:
	var id: StringName
	var label_key: StringName
	var value: int
	var maximum: int


class OfferItem extends RefCounted:
	var instance_id: StringName
	var faction_name_key: StringName
	var title_key: StringName
	var reward: int
	var remaining_turns: int
	var status: StringName


class ProblemItem extends RefCounted:
	var id: StringName
	var title_key: StringName
	var band: StringName
	var remaining_turns: int
	var player_reason_keys: Array[StringName]


class MessageItem extends RefCounted:
	var instance_id: StringName
	var week_index: int
	var title_key: StringName
	var body_key: StringName
	var importance: StringName
	var is_read: bool
	var sort_order: int
	var parameters: Dictionary


class ActionItem extends RefCounted:
	var instance_id: StringName
	var faction_name_key: StringName
	var action_title_key: StringName
	var problem_title_key: StringName
	var player_reason_keys: Array[StringName]


var week_index: int
var gold: int
var reputation: int
var base_cohesion: int
var situation_name_key: StringName
var phase_name_key: StringName
var clocks: Array[ClockItem]
var offers: Array[OfferItem]
var problems: Array[ProblemItem]
var messages: Array[MessageItem]
var committed_actions: Array[ActionItem]
var alert_keys: Array[StringName]
