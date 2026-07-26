extends RefCounted

const Task015Fixtures = preload("res://tests/fixtures/task015_fixtures.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_resolve_once_and_cached_review(),
		_test_skip_and_active_plan_are_exclusive(),
		_test_acknowledge_opens_once(),
		_test_two_consecutive_week_paths(),
	]


func _test_resolve_once_and_cached_review() -> Dictionary:
	var session := Task015Fixtures.create_session(151500)
	var command = Task015Fixtures.valid_command(
		session.call("get_campaign_snapshot")
	)
	var accepted: bool = session.call("accept_plan", command)
	var resolved: bool = session.call("resolve_current_week", false)
	var first: Dictionary = session.call(
		"get_resolution_review_snapshot"
	)
	first["resolved_week"] = 999
	var second: Dictionary = session.call(
		"get_resolution_review_snapshot"
	)
	var repeated: bool = not session.call("resolve_current_week", false)
	var passed: bool = accepted \
		and resolved \
		and repeated \
		and session.call("get_phase") == &"resolution_review" \
		and int(second.get("resolved_week", 0)) == 1 \
		and not second.get("contract", {}).is_empty()
	session.free()
	return _result(
		"week resolves once and review getter is detached",
		passed,
		"Resolution repeated or cached review leaked mutable ownership."
	)


func _test_skip_and_active_plan_are_exclusive() -> Dictionary:
	var skipping := Task015Fixtures.create_session(151501)
	var skipped: bool = skipping.call("resolve_current_week", true)
	var skip_review: Dictionary = skipping.call(
		"get_resolution_review_snapshot"
	)
	var planned := Task015Fixtures.create_session(151502)
	planned.call(
		"accept_plan",
		Task015Fixtures.valid_command(
			planned.call("get_campaign_snapshot")
		)
	)
	var illegal_skip: bool = not planned.call(
		"resolve_current_week",
		true
	)
	var passed: bool = skipped \
		and skip_review.get("contract", {}).is_empty() \
		and illegal_skip \
		and planned.call("get_phase") == &"planning"
	skipping.free()
	planned.free()
	return _result(
		"explicit skip and accepted plan are mutually exclusive",
		passed,
		"Skip path created a contract or bypassed an active plan."
	)


func _test_acknowledge_opens_once() -> Dictionary:
	var session := Task015Fixtures.create_session(151503)
	session.call("resolve_current_week", true)
	var acknowledged: bool = session.call("acknowledge_resolution")
	var state = session.call("get_campaign_snapshot")
	var repeated: bool = not session.call("acknowledge_resolution")
	var passed: bool = acknowledged \
		and repeated \
		and session.call("get_phase") == &"planning" \
		and state.week_index == 2 \
		and not session.call("has_resolution_review")
	session.free()
	return _result(
		"acknowledge opens the next week exactly once",
		passed,
		"Review acknowledgment repeated or failed to open week 2."
	)


func _test_two_consecutive_week_paths() -> Dictionary:
	var session := Task015Fixtures.create_session(151504)
	var accepted: bool = session.call(
		"accept_plan",
		Task015Fixtures.valid_command(
			session.call("get_campaign_snapshot")
		)
	)
	var resolved_contract: bool = session.call(
		"resolve_current_week",
		false
	)
	var opened_two: bool = session.call("acknowledge_resolution")
	var week_two = session.call("get_campaign_snapshot")
	var skipped: bool = session.call("resolve_current_week", true)
	var opened_three: bool = session.call("acknowledge_resolution")
	var final_state = session.call("get_campaign_snapshot")
	var passed: bool = accepted \
		and resolved_contract \
		and opened_two \
		and week_two.week_index == 2 \
		and skipped \
		and opened_three \
		and final_state.week_index == 3
	session.free()
	return _result(
		"contract week and explicit skip week form a continuous loop",
		passed,
		"Two consecutive week paths did not reach week 3."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
