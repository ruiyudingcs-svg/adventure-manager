extends RefCounted

const SceneRouterScript = preload("res://game/app/scene_router.gd")
const GameSessionScript = preload("res://game/app/game_session.gd")
const CampaignBootstrapFixtures = preload(
	"res://tests/fixtures/campaign_bootstrap_fixtures.gd"
)
const APP_SCENE = preload("res://game/app/app_root.tscn")
const DASHBOARD_SCENE = preload(
	"res://game/features/dashboard/dashboard_view.tscn"
)
const ROSTER_SCENE = preload("res://game/features/roster/roster_view.tscn")
const RosterViewData = preload(
	"res://game/features/roster/roster_view_data.gd"
)


func run(scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_router(scene_tree),
		_test_feature_scenes(),
		_test_app_shell_sizes(scene_tree),
		_test_roster_member_click_is_signal_safe(scene_tree),
	]


func _test_router(scene_tree: SceneTree) -> Dictionary:
	var router: Node = SceneRouterScript.new()
	var session: Node = GameSessionScript.new()
	session.call(
		"set_catalog_for_testing",
		CampaignBootstrapFixtures.create_catalog()
	)
	session.call(
		"start_new_campaign",
		CampaignBootstrapFixtures.SETUP_ID,
		140014
	)
	router.call("set_session_for_testing", session)
	var container := Control.new()
	scene_tree.root.add_child(container)
	router.call("bind_screen_container", container)
	var dashboard: bool = router.call("navigate", &"dashboard")
	var dashboard_one: bool = container.get_child_count() == 1
	var roster: bool = router.call("navigate", &"roster")
	var roster_one: bool = container.get_child_count() == 1
	var contracts: bool = router.call("navigate", &"contracts")
	var contracts_one: bool = container.get_child_count() == 1
	var resolution_disabled: bool = not router.call(
		"navigate",
		&"resolution"
	)
	var unknown_disabled: bool = not router.call("navigate", &"unknown")
	container.queue_free()
	router.free()
	session.free()
	return _result(
		"Router enforces whitelist resolution guard and one mounted screen",
		dashboard and dashboard_one \
			and roster and roster_one \
			and contracts and contracts_one \
			and resolution_disabled \
			and unknown_disabled,
		"Router mounted multiple screens or accepted a disabled route."
	)


func _test_feature_scenes() -> Dictionary:
	var dashboard: Control = DASHBOARD_SCENE.instantiate()
	var roster: Control = ROSTER_SCENE.instantiate()
	var passed: bool = dashboard != null \
		and dashboard.find_child("Tabs", true, false) != null \
		and dashboard.find_child("Overview", true, false) != null \
		and dashboard.find_child("Problems", true, false) != null \
		and dashboard.find_child("Inbox", true, false) != null \
		and roster != null \
		and roster.find_child("Members", true, false) != null \
		and roster.find_child("Relationships", true, false) != null \
		and roster.find_child("Recent Records", true, false) != null
	dashboard.free()
	roster.free()
	return _result(
		"Dashboard and Roster scenes expose fixed context tabs",
		passed,
		"A required scene or context tab was missing."
	)


func _test_app_shell_sizes(scene_tree: SceneTree) -> Dictionary:
	var passed := true
	for size: Vector2i in [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
	]:
		var viewport := SubViewport.new()
		viewport.size = size
		scene_tree.root.add_child(viewport)
		var app: Control = APP_SCENE.instantiate()
		viewport.add_child(app)
		passed = passed \
			and app.find_child("AppShell", true, false) != null \
			and app.find_child("Sidebar", true, false) != null \
			and app.find_child("TopToolbar", true, false) != null \
			and app.find_child("ScreenContainer", true, false) != null \
			and app.find_child("ModalLayer", true, false) != null \
			and viewport.size == size \
			and app.anchor_left == 0.0 \
			and app.anchor_top == 0.0 \
			and app.anchor_right == 1.0 \
			and app.anchor_bottom == 1.0
		viewport.free()
	return _result(
		"application shell instantiates at all three desktop sizes",
		passed,
		"One desktop size or required shell node failed."
	)


func _test_roster_member_click_is_signal_safe(
	scene_tree: SceneTree
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	scene_tree.root.add_child(viewport)
	var roster: Control = ROSTER_SCENE.instantiate()
	viewport.add_child(roster)
	for binding: Array in [
		["empty_label", "EmptyLabel"],
		["content", "Content"],
		["member_list", "MemberList"],
		["tabs", "Tabs"],
		["member_details", "MemberDetails"],
		["relationships_list", "RelationshipsList"],
		["records_list", "RecordsList"],
	]:
		roster.set(
			binding[0],
			roster.find_child(binding[1], true, false)
		)
	roster.call("set_view_data", _roster_data())
	roster.call("_render")
	var member_list: Node = roster.find_child("MemberList", true, false)
	var clicked_button: Button = member_list.get_child(1) as Button
	clicked_button.pressed.emit()
	var old_button_valid := is_instance_valid(clicked_button)
	var old_button_detached := old_button_valid \
		and clicked_button.get_parent() == null
	var replacements_present := member_list.get_child_count() == 2 \
		and member_list.get_child(1) != clicked_button
	var passed: bool = old_button_detached \
		and replacements_present \
		and roster.get("_selected_member_id") == &"member_b"
	viewport.queue_free()
	return _result(
		"roster member click rebuilds details without freeing its emitting button",
		passed,
		"Roster click lifecycle mismatch: valid=%s detached=%s replacements=%s."
			% [old_button_valid, old_button_detached, replacements_present]
	)


func _roster_data() -> RosterViewData:
	var data := RosterViewData.new()
	for definition: Dictionary in [
		{
			"id": &"member_a",
			"name_key": &"member.a.name",
			"fallback_name": "A",
		},
		{
			"id": &"member_b",
			"name_key": &"member.b.name",
			"fallback_name": "B",
		},
	]:
		var member := RosterViewData.MemberItem.new()
		member.id = definition["id"]
		member.name_key = definition["name_key"]
		member.fallback_name = definition["fallback_name"]
		member.class_key = &"class.test"
		member.is_available = true
		data.members.append(member)
	return data


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
