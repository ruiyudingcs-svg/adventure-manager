extends RefCounted

const Task015Fixtures = preload("res://tests/fixtures/task015_fixtures.gd")
const ResolutionPresenter = preload(
	"res://game/features/resolution/resolution_presenter.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_result_projection_uses_cached_payload(),
		_test_skip_projection_has_no_contract(),
		_test_faction_action_title_uses_stable_id(),
	]


func _test_result_projection_uses_cached_payload() -> Dictionary:
	var session := Task015Fixtures.create_session(151510)
	var catalog = session.call("_catalog")
	session.call(
		"accept_plan",
		Task015Fixtures.valid_command(
			session.call("get_campaign_snapshot")
		)
	)
	session.call("resolve_current_week", false)
	var review: Dictionary = session.call(
		"get_resolution_review_snapshot"
	)
	var view_data = _present(catalog, review)
	var contract: Dictionary = review.get("contract", {})
	var debug_review: Dictionary = session.call(
		"get_resolution_review_snapshot",
		true
	)
	var default_has_debug := _has_debug_reason(review)
	var numeric_type_preserved := false
	var collection_type_preserved := false
	for change in view_data.changes:
		numeric_type_preserved = numeric_type_preserved or (
			typeof(change.old_value) == TYPE_INT
			and typeof(change.new_value) == TYPE_INT
		)
		collection_type_preserved = collection_type_preserved or (
			typeof(change.old_value) == TYPE_PACKED_STRING_ARRAY
			and typeof(change.new_value) == TYPE_PACKED_STRING_ARRAY
		)
	var passed: bool = view_data != null \
		and not view_data.skipped_contract \
		and view_data.final_tier == contract.get("result_tier") \
		and view_data.reward == int(contract.get("reward", -1)) \
		and view_data.supply_cost_total \
			== int(contract.get("supply_cost_total", -1)) \
		and view_data.phases.size() == 4 \
		and view_data.members.size() == 4 \
		and view_data.changes.size() \
			== review.get("state_changes", []).size() \
		and numeric_type_preserved \
		and collection_type_preserved \
		and not default_has_debug \
		and debug_review.get("reasons", []).size() \
			>= review.get("reasons", []).size()
	session.free()
	return _result(
		"ResultViewData copies cached WeekResolution and StateChange fields",
		passed,
		"Presenter guessed from final state or exposed debug reasons by default."
	)


func _test_skip_projection_has_no_contract() -> Dictionary:
	var session := Task015Fixtures.create_session(151511)
	var catalog = session.call("_catalog")
	session.call("resolve_current_week", true)
	var view_data = _present(
		catalog,
		session.call("get_resolution_review_snapshot")
	)
	var passed: bool = view_data != null \
		and view_data.skipped_contract \
		and view_data.phases.is_empty() \
		and view_data.members.is_empty()
	session.free()
	return _result(
		"skip review remains an explicit no-contract result",
		passed,
		"Skip review fabricated contract phases or member outcomes."
	)


func _test_faction_action_title_uses_stable_id() -> Dictionary:
	var session := Task015Fixtures.create_session(151512)
	var catalog = session.call("_catalog")
	var action_id: StringName = (
		catalog.get_all_faction_actions()[0].id
	)
	var review: Dictionary = {
		"resolved_week": 2,
		"next_week": 3,
		"faction_actions": [{
			"action_definition_id": action_id,
		}],
	}
	var view_data = _present(catalog, review)
	var passed: bool = view_data.faction_action_titles == [
		StringName("action.%s.title" % action_id),
	]
	session.free()
	return _result(
		"faction action title derives from its stable definition ID",
		passed,
		"Resolution presenter accessed a field outside the action schema."
	)


func _present(catalog, review: Dictionary):
	return ResolutionPresenter.present(
		review,
		catalog.get_all_contracts(),
		catalog.get_all_factions(),
		catalog.get_all_adventurers(),
		catalog.get_all_contract_clauses(),
		catalog.get_all_faction_actions()
	)


func _has_debug_reason(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if key == "visibility" and value[key] == &"debug":
				return true
			if _has_debug_reason(value[key]):
				return true
	elif value is Array:
		for child: Variant in value:
			if _has_debug_reason(child):
				return true
	return false


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
