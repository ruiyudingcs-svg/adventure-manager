class_name MissionContextReducer
extends RefCounted

const MissionContext = preload("res://game/domain/contracts/mission_context.gd")


static func validate_deltas(
	deltas: Array[Dictionary]
) -> PackedStringArray:
	var errors := PackedStringArray()
	for delta: Dictionary in deltas:
		if not delta.has("key") or not delta.has("amount") or not delta.has("source_id"):
			errors.append("MissionContext delta must contain key, amount, and source_id.")
		elif not MissionContext.CONTEXT_KEYS.has(delta["key"]):
			errors.append("Unknown MissionContext key: %s." % delta["key"])
	return errors


static func apply(
	context: MissionContext,
	deltas: Array[Dictionary],
	outcome_tags: Array[StringName] = [],
	method_tags: Array[StringName] = []
) -> MissionContext:
	assert(context != null)
	assert(validate_deltas(deltas).is_empty())
	var values: Dictionary[StringName, int] = {}
	var totals: Dictionary[StringName, int] = {}
	for key: StringName in MissionContext.CONTEXT_KEYS:
		values[key] = context.get_value(key)
		totals[key] = 0
	for delta: Dictionary in deltas:
		var key: StringName = delta["key"]
		var amount: int = delta["amount"]
		totals[key] += amount
	for key: StringName in MissionContext.CONTEXT_KEYS:
		values[key] = clampi(values[key] + totals[key], 0, 10)

	var merged_outcome_tags: Array[StringName] = context.outcome_tags
	for tag: StringName in outcome_tags:
		if not merged_outcome_tags.has(tag):
			merged_outcome_tags.append(tag)
	var merged_method_tags: Array[StringName] = context.used_method_tags
	for tag: StringName in method_tags:
		if not merged_method_tags.has(tag):
			merged_method_tags.append(tag)
	return MissionContext.new(values, merged_outcome_tags, merged_method_tags)
