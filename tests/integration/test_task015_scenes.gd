extends RefCounted

const CONTRACT_SCENE = preload(
	"res://game/features/contract_planning/contract_planning_view.tscn"
)
const RESOLUTION_SCENE = preload(
	"res://game/features/resolution/resolution_view.tscn"
)
const SceneRouterScript = preload("res://game/app/scene_router.gd")
const Task015Fixtures = preload("res://tests/fixtures/task015_fixtures.gd")
const APP_SCENE = preload("res://game/app/app_root.tscn")
const CampaignBootstrapFixtures = preload(
	"res://tests/fixtures/campaign_bootstrap_fixtures.gd"
)
const PlanningPresenter = preload(
	"res://game/features/contract_planning/planning_presenter.gd"
)
const ResolutionPresenter = preload(
	"res://game/features/resolution/resolution_presenter.gd"
)
const UiText = preload("res://game/features/shared/ui_text.gd")


func run(scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_context_tabs_exist(),
		_test_resolution_route_guard_changes_after_resolve(scene_tree),
		_test_full_click_smoke(scene_tree),
		_test_squad_cards_render_all_capabilities(scene_tree),
		_test_resolution_tabs_render_localized_content(scene_tree),
	]


func _test_context_tabs_exist() -> Dictionary:
	var contracts: Control = CONTRACT_SCENE.instantiate()
	var resolution: Control = RESOLUTION_SCENE.instantiate()
	var passed: bool = contracts.find_child("OffersTab", true, false) != null \
		and contracts.find_child("DetailsTab", true, false) != null \
		and contracts.find_child("SquadTab", true, false) != null \
		and contracts.find_child("ReviewTab", true, false) != null \
		and resolution.find_child("SummaryTab", true, false) != null \
		and resolution.find_child("PhasesTab", true, false) != null \
		and resolution.find_child("MembersTab", true, false) != null \
		and resolution.find_child("WorldTab", true, false) != null \
		and resolution.find_child("ReasonsTab", true, false) != null
	contracts.free()
	resolution.free()
	return _result(
		"Planning and Resolution expose their fixed context tabs",
		passed,
		"A required Task015 context tab is missing."
	)


func _test_resolution_route_guard_changes_after_resolve(
	scene_tree: SceneTree
) -> Dictionary:
	var session := Task015Fixtures.create_session(151512)
	var router: Node = SceneRouterScript.new()
	router.call("set_session_for_testing", session)
	var container := Control.new()
	scene_tree.root.add_child(container)
	router.call("bind_screen_container", container)
	var before: bool = not router.call("navigate", &"resolution")
	session.call("resolve_current_week", true)
	var after: bool = router.call("navigate", &"resolution") \
		and container.get_child_count() == 1 \
		and container.get_child(0).name == "ResolutionView"
	container.queue_free()
	router.free()
	session.free()
	return _result(
		"Resolution route enables only for cached review",
		before and after,
		"Router guard did not follow GameSession review phase."
	)


func _test_full_click_smoke(scene_tree: SceneTree) -> Dictionary:
	var interaction_session := Task015Fixtures.create_session(151513)
	var interaction_catalog = interaction_session.call("_catalog")
	var app: Control = APP_SCENE.instantiate()
	scene_tree.root.add_child(app)
	var local_router: Node = SceneRouterScript.new()
	local_router.call("set_session_for_testing", interaction_session)
	local_router.call(
		"bind_screen_container",
		app.find_child("ScreenContainer", true, false)
	)
	var contracts_button: Button = app.find_child(
		"ContractsButton",
		true,
		false
	)
	contracts_button.pressed.emit()
	local_router.call("navigate", &"contracts")
	var planning = app.find_child("ContractPlanningView", true, false)
	if planning == null:
		app.queue_free()
		local_router.free()
		interaction_session.free()
		return _result(
			"planning-to-resolution click smoke",
			false,
			"Contracts route did not mount its feature scene."
		)
	var state = interaction_session.call("get_campaign_snapshot")
	var offer = Task015Fixtures.first_pending_offer(state)
	for binding: Array in [
		["offer_list", "OfferList"],
		["content", "Content"],
		["issue_label", "IssueLabel"],
		["accept_button", "AcceptButton"],
		["decline_button", "DeclineButton"],
	]:
		planning.set(
			binding[0],
			planning.find_child(binding[1], true, false)
		)
	var controller = planning.find_child(
		"ContractPlanningController",
		true,
		false
	)
	controller.call(
		"set_dependencies_for_testing",
		interaction_session,
		interaction_catalog
	)
	controller.call("_on_offer_selected", offer.instance_id)
	for member_id: StringName in Task015Fixtures.first_four_members(state):
		controller.call("_on_member_toggled", member_id)
	controller.call("_on_accept_requested")
	var accepted = interaction_session.call(
		"get_campaign_snapshot"
	).active_plan != null
	interaction_session.call("resolve_current_week", false)
	local_router.call("navigate", &"resolution")
	var reviewed: bool = interaction_session.call("has_resolution_review") \
		and app.find_child("ResolutionView", true, false) != null
	interaction_session.call("acknowledge_resolution")
	var continued: bool = interaction_session.call("get_phase") == &"planning" \
		and interaction_session.call("get_campaign_snapshot").week_index == 2
	app.queue_free()
	local_router.free()
	interaction_session.free()
	return _result(
		"planning-to-resolution click smoke",
		accepted and reviewed and continued,
		"accepted=%s reviewed=%s continued=%s phase=%s week=%d"
		% [
			accepted,
			reviewed,
			continued,
			&"planning" if continued else &"unknown",
			2 if continued else -1,
		]
	)


func _test_squad_cards_render_all_capabilities(
	scene_tree: SceneTree
) -> Dictionary:
	var session := Task015Fixtures.create_session(151514)
	var catalog = session.call("_catalog")
	var state = session.call("get_campaign_snapshot")
	var draft = Task015Fixtures.valid_draft(state)
	var view_data = PlanningPresenter.present(
		state,
		draft,
		catalog.get_all_contracts(),
		catalog.get_all_factions(),
		catalog.get_all_adventurers(),
		catalog.get_all_supplies(),
		catalog.get_all_contract_clauses(),
		null,
		[]
	)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	scene_tree.root.add_child(viewport)
	var planning: Control = CONTRACT_SCENE.instantiate()
	viewport.add_child(planning)
	for binding: Array in [
		["offer_list", "OfferList"],
		["content", "Content"],
		["issue_label", "IssueLabel"],
		["accept_button", "AcceptButton"],
		["decline_button", "DeclineButton"],
	]:
		planning.set(
			binding[0],
			planning.find_child(binding[1], true, false)
		)
	planning.set("_active_tab", &"squad")
	planning.call("set_view_data", view_data)
	var first_row = view_data.members[0]
	var member_button: Button
	for node: Node in planning.find_children("*", "Button", true, false):
		if node.tooltip_text == String(first_row.member_id):
			member_button = node as Button
			break
	var passed := member_button != null
	if member_button != null:
		for capability_id: StringName in [
			&"frontline",
			&"offense",
			&"scouting",
			&"support",
			&"arcana",
			&"discipline",
		]:
			var expected := "%s %d" % [
				UiText.get_text(StringName("capability.%s" % capability_id)),
				first_row.capabilities[capability_id],
			]
			passed = passed and member_button.text.contains(expected)
	viewport.queue_free()
	session.free()
	return _result(
		"squad member cards render six capability values and current status",
		passed,
		"A squad member card omitted one or more decision-relevant capabilities."
	)


func _test_resolution_tabs_render_localized_content(
	scene_tree: SceneTree
) -> Dictionary:
	var session := Task015Fixtures.create_session(151513)
	var catalog = session.call("_catalog")
	var state = session.call("get_campaign_snapshot")
	session.call("accept_plan", Task015Fixtures.valid_command(state))
	session.call("resolve_current_week", false)
	var review: Dictionary = session.call("get_resolution_review_snapshot")
	var view_data = ResolutionPresenter.present(
		review,
		catalog.get_all_contracts(),
		catalog.get_all_factions(),
		catalog.get_all_adventurers(),
		catalog.get_all_contract_clauses(),
		catalog.get_all_faction_actions()
	)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	scene_tree.root.add_child(viewport)
	var resolution: Control = RESOLUTION_SCENE.instantiate()
	viewport.add_child(resolution)
	resolution.set(
		"content",
		resolution.find_child("Content", true, false)
	)
	resolution.set("_active_tab", &"phases")
	resolution.call("set_view_data", view_data)
	var phase_text := _all_label_text(resolution)
	resolution.call("_set_tab", &"world")
	var world_text := _all_label_text(resolution)
	resolution.call("_set_tab", &"reasons")
	var reason_text := _all_label_text(resolution)
	var passed := phase_text.contains("队伍能力与判定需求匹配") \
		and not phase_text.contains("[MISSING:") \
		and world_text.contains(
			"佩尔·军需官 · 可出勤状态: 可出勤 → 不可出勤"
		) \
		and world_text.contains(
			"战役 · 合同历史: 0 条记录 → 1 条记录"
		) \
		and not world_text.contains("[MISSING:") \
		and not world_text.contains("contract_offer_498a1c26|") \
		and not world_text.contains("message_925d69d1|") \
		and not reason_text.contains("[MISSING:") \
		and not reason_text.contains("%s (") \
		and not reason_text.contains("%+g")
	viewport.queue_free()
	session.free()
	return _result(
		"resolution tabs localize reasons and suppress raw state signatures",
		passed,
		"PHASES:\n%s\nWORLD:\n%s\nREASONS:\n%s" % [
			phase_text,
			world_text,
			reason_text,
		]
	)


func _all_label_text(root: Node) -> String:
	var parts := PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
