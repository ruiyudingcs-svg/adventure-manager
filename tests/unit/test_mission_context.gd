extends RefCounted

const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const MissionContextReducer = preload("res://game/domain/simulation/mission_context_reducer.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var context: MissionContext = MissionContext.create_default()
	var all_default_zero: bool = true
	for key: StringName in MissionContext.CONTEXT_KEYS:
		all_default_zero = all_default_zero and context.get_value(key) == 0
	results.append(_result(
		"all ten context values default to zero",
		MissionContext.CONTEXT_KEYS.size() == 10 and all_default_zero,
		"Expected ten known MissionContext keys with value zero."
	))

	var overlay: Array[Dictionary] = [
		MissionContext.create_delta(&"intel", 8, &"offer_a"),
		MissionContext.create_delta(&"intel", 7, &"offer_b"),
		MissionContext.create_delta(&"time_pressure", -4, &"offer_c"),
	]
	context = MissionContextReducer.apply(context, overlay)
	results.append(_result(
		"same-key overlay sums before one clamp",
		context.get_value(&"intel") == 10 and context.get_value(&"time_pressure") == 0,
		"Expected intel to clamp to 10 and time_pressure to clamp to 0."
	))

	var mixed_deltas: Array[Dictionary] = [
		MissionContext.create_delta(&"intel", -12, &"check_a"),
		MissionContext.create_delta(&"intel", 5, &"check_a"),
		MissionContext.create_delta(&"route_safety", 3, &"check_a"),
	]
	var before: MissionContext = context.duplicate_value()
	var outcome_tags: Array[StringName] = [&"shared", &"new_tag", &"shared"]
	var method_tags: Array[StringName] = [&"rescue", &"medical", &"rescue"]
	var updated: MissionContext = MissionContextReducer.apply(
		context,
		mixed_deltas,
		outcome_tags,
		method_tags
	)
	results.append(_result(
		"check deltas merge then update a new snapshot",
		updated.get_value(&"intel") == 3 \
			and updated.get_value(&"route_safety") == 3 \
			and before.get_value(&"intel") == 10 \
			and context.get_value(&"route_safety") == 0,
		"Expected summed intel delta -7 and no mutation of previous contexts."
	))
	results.append(_result(
		"outcome and method tags use first-appearance stable dedupe",
		updated.outcome_tags == [&"shared", &"new_tag"] \
			and updated.used_method_tags == [&"rescue", &"medical"],
		"Expected stable first-appearance tag order."
	))

	var invalid: Array[Dictionary] = [
		MissionContext.create_delta(&"not_a_context_key", 1, &"bad_fixture"),
	]
	results.append(_result(
		"unknown context keys are rejected",
		not MissionContextReducer.validate_deltas(invalid).is_empty(),
		"Expected an unknown MissionContext key validation error."
	))
	return results


func _result(test_name: String, passed: bool, failure_message: String) -> Dictionary:
	return {
		"name": test_name,
		"passed": passed,
		"message": "" if passed else failure_message,
	}
