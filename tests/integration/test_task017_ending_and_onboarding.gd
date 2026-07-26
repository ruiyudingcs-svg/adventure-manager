extends RefCounted

const EndingPresenter = preload(
	"res://game/features/ending/ending_presenter.gd"
)
const ENDING_SCENE = preload(
	"res://game/features/ending/ending_view.tscn"
)
const ONBOARDING_SCENE = preload(
	"res://game/features/onboarding/onboarding_view.tscn"
)
const DASHBOARD_SCENE = preload(
	"res://game/features/dashboard/dashboard_view.tscn"
)
const DashboardViewData = preload(
	"res://game/features/dashboard/dashboard_view_data.gd"
)
const SceneRouterScript = preload("res://game/app/scene_router.gd")
const GameSessionScript = preload("res://game/app/game_session.gd")
const CampaignBootstrapFixtures = preload(
	"res://tests/fixtures/campaign_bootstrap_fixtures.gd"
)
const UiText = preload("res://game/features/shared/ui_text.gd")
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldEventState = preload(
	"res://game/domain/situations/world_event_state.gd"
)


func run(scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_ending_projection_is_complete_and_read_only(),
		_test_ended_session_routes_only_to_ending(scene_tree),
		_test_onboarding_has_six_skippable_steps(scene_tree),
		_test_hardening_scenes_at_three_sizes(scene_tree),
		_test_missing_localization_is_visible(),
		_test_faction_intent_localizations_are_complete(),
		_test_situation_stable_sets_are_canonical(),
		_test_world_event_reason_codes_are_canonical(),
		_test_dashboard_inbox_refresh_is_signal_safe(scene_tree),
	]


func _test_ending_projection_is_complete_and_read_only() -> Dictionary:
	var catalog = CampaignBootstrapFixtures.create_catalog()
	var bootstrap = CampaignBootstrapFixtures.bootstrap(catalog, 170017)
	var state = bootstrap.new_state.duplicate_state()
	state.week_index = 10
	state.situation.phase_id = &"phase_ended"
	state.situation.ending_id = &"ending_mass_evacuation"
	var before: String = _ending_input_signature(state)
	var view_data = EndingPresenter.present(
		state,
		catalog.get_situation(state.situation.definition_id),
		catalog.get_all_endings(),
		catalog.get_all_problems(),
		catalog.get_all_contracts(),
		catalog.get_all_factions(),
		catalog.get_all_adventurers()
	)
	var passed: bool = view_data != null \
		and view_data.ending_id == &"ending_mass_evacuation" \
		and view_data.ending_week == 10 \
		and view_data.clocks.size() == 5 \
		and view_data.factions.size() == 3 \
		and view_data.members.size() == 8 \
		and view_data.reason_keys.size() <= 8 \
		and _ending_input_signature(state) == before
	return _result(
		"ending projection reads committed state without re-evaluation",
		passed,
		"Ending summary omitted required final fields or mutated CampaignState."
	)


func _test_ended_session_routes_only_to_ending(
	scene_tree: SceneTree
) -> Dictionary:
	var session: Node = GameSessionScript.new()
	session.call(
		"set_catalog_for_testing",
		CampaignBootstrapFixtures.create_catalog()
	)
	session.call(
		"start_new_campaign",
		CampaignBootstrapFixtures.SETUP_ID,
		170018
	)
	var state = session.get("_campaign_state")
	state.situation.phase_id = &"phase_ended"
	state.situation.ending_id = &"ending_dragon_slain_at_cost"
	session.set("_phase", &"ended")
	var router: Node = SceneRouterScript.new()
	router.call("set_session_for_testing", session)
	var container := Control.new()
	scene_tree.root.add_child(container)
	router.call("bind_screen_container", container)
	var dashboard_rejected: bool = not router.call("navigate", &"dashboard")
	var ending_opened: bool = router.call("navigate", &"ending")
	var passed: bool = dashboard_rejected \
		and ending_opened \
		and router.call("get_current_route") == &"ending" \
		and container.get_child_count() == 1
	container.queue_free()
	router.free()
	session.free()
	return _result(
		"ended session exposes only the internal ending route",
		passed,
		"Ended campaign returned to a planning screen or failed to mount ending."
	)


func _test_onboarding_has_six_skippable_steps(
	scene_tree: SceneTree
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	scene_tree.root.add_child(viewport)
	var view: Control = ONBOARDING_SCENE.instantiate()
	viewport.add_child(view)
	view.set(
		"progress_label",
		view.find_child("ProgressLabel", true, false)
	)
	view.set("title_label", view.find_child("TitleLabel", true, false))
	view.set("body_label", view.find_child("BodyLabel", true, false))
	view.set("next_button", view.find_child("NextButton", true, false))
	view.call("_ready")
	var completed := [false]
	var skipped := [false]
	view.completed.connect(func() -> void: completed[0] = true)
	view.skipped.connect(func() -> void: skipped[0] = true)
	for expected_step: int in range(6):
		if view.call("get_step_index") != expected_step:
			viewport.free()
			return _result(
				"onboarding has six skippable session-only steps",
				false,
				"Onboarding step order changed at %d." % expected_step
			)
		view.call("_advance")
	view.find_child("SkipButton", true, false).pressed.emit()
	var passed: bool = completed[0] \
		and skipped[0] \
		and view.get("mouse_filter") == Control.MOUSE_FILTER_IGNORE
	viewport.free()
	return _result(
		"onboarding has six skippable session-only steps",
		passed,
		"Onboarding did not complete six steps or emit skip."
	)


func _test_hardening_scenes_at_three_sizes(
	scene_tree: SceneTree
) -> Dictionary:
	var passed := true
	for size: Vector2i in [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
	]:
		var viewport := SubViewport.new()
		viewport.size = size
		scene_tree.root.add_child(viewport)
		var ending: Control = ENDING_SCENE.instantiate()
		var onboarding: Control = ONBOARDING_SCENE.instantiate()
		viewport.add_child(ending)
		viewport.add_child(onboarding)
		passed = passed \
			and ending.find_child("Scroll", true, false) != null \
			and ending.find_child("NewGameButton", true, false) != null \
			and ending.find_child("TitleButton", true, false) != null \
			and onboarding.find_child("Panel", true, false) != null \
			and ending.anchor_right == 1.0 \
			and ending.anchor_bottom == 1.0 \
			and onboarding.anchor_right == 1.0 \
			and onboarding.anchor_bottom == 1.0
		viewport.free()
	return _result(
		"ending and onboarding instantiate at all desktop sizes",
		passed,
		"A hardening screen lost scrolling, actions, or full-viewport anchors."
	)


func _test_missing_localization_is_visible() -> Dictionary:
	return _result(
		"missing localization keys remain explicit",
		UiText.get_text(&"task017.deliberately_missing") \
			== "[MISSING:task017.deliberately_missing]",
		"Missing localization silently rendered as an empty string."
	)


func _test_faction_intent_localizations_are_complete() -> Dictionary:
	var missing := PackedStringArray()
	for key: StringName in [
		&"reason.faction_intent_base_priority",
		&"reason.faction_intent_urgency",
		&"reason.faction_intent_agenda_fit",
		&"reason.faction_intent_repeat_penalty",
	]:
		if UiText.get_text(key).begins_with("[MISSING:"):
			missing.append(key)
	return _result(
		"faction intent reasons have player-readable localization",
		missing.is_empty(),
		"Missing faction intent localization keys: %s." % missing
	)


func _test_situation_stable_sets_are_canonical() -> Dictionary:
	var state := SituationState.create(
		&"situation_test",
		&"phase_test",
		{&"clock_test": 0},
		[&"trigger_z", &"trigger_a"],
		[&"contract_z", &"contract_a"],
		{}
	)
	return _result(
		"situation stable-ID sets canonicalize at copy and load boundaries",
		state != null \
			and state.triggered_rule_ids.size() == 2 \
			and state.triggered_rule_ids[0] == &"trigger_a" \
			and state.triggered_rule_ids[1] == &"trigger_z" \
			and state.unlocked_contract_ids.size() == 2 \
			and state.unlocked_contract_ids[0] == &"contract_a" \
			and state.unlocked_contract_ids[1] == &"contract_z",
		"Situation stable sets retained insertion order: %s / %s."
			% [
				state.triggered_rule_ids if state != null else [],
				state.unlocked_contract_ids if state != null else [],
			]
	)


func _test_world_event_reason_codes_are_canonical() -> Dictionary:
	var event := WorldEventState.create(
		&"event_test_001",
		&"event_test",
		2,
		&"source_test",
		&"",
		[&"reason_z", &"reason_a"]
	)
	return _result(
		"world event reason-code sets canonicalize at copy and load boundaries",
		event != null \
			and event.effect_reason_codes.size() == 2 \
			and event.effect_reason_codes[0] == &"reason_a" \
			and event.effect_reason_codes[1] == &"reason_z",
		"World event reason codes retained insertion order: %s."
			% [event.effect_reason_codes if event != null else []]
	)


func _test_dashboard_inbox_refresh_is_signal_safe(
	scene_tree: SceneTree
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	scene_tree.root.add_child(viewport)
	var dashboard: Control = DASHBOARD_SCENE.instantiate()
	viewport.add_child(dashboard)
	for binding: Array in [
		["empty_label", "EmptyLabel"],
		["tabs", "Tabs"],
		["overview_summary", "OverviewSummary"],
		["clocks_list", "ClocksList"],
		["offers_list", "OffersList"],
		["actions_list", "ActionsList"],
		["alerts_list", "AlertsList"],
		["problems_list", "ProblemsList"],
		["inbox_list", "InboxList"],
		["message_detail", "MessageDetail"],
	]:
		dashboard.set(
			binding[0],
			dashboard.find_child(binding[1], true, false)
		)
	dashboard.call("set_view_data", _dashboard_data(false))
	dashboard.call("_render")
	var inbox: Node = dashboard.find_child("InboxList", true, false)
	var clicked_button: Button = inbox.get_child(0) as Button
	dashboard.message_opened.connect(func(_message_id: StringName) -> void:
		dashboard.call("set_view_data", _dashboard_data(true))
		dashboard.call("_render")
	)
	clicked_button.pressed.emit()
	var old_button_valid := is_instance_valid(clicked_button)
	var old_button_detached := old_button_valid \
		and clicked_button.get_parent() == null
	var replacement_present := inbox.get_child_count() == 1 \
		and inbox.get_child(0) != clicked_button
	var passed: bool = old_button_detached and replacement_present
	viewport.queue_free()
	return _result(
		"dashboard inbox refresh defers freeing its emitting message button",
		passed,
		"Inbox refresh lifecycle mismatch: valid=%s detached=%s replacement=%s."
			% [old_button_valid, old_button_detached, replacement_present]
	)


func _dashboard_data(is_read: bool) -> DashboardViewData:
	var data := DashboardViewData.new()
	data.week_index = 1
	data.gold = 200
	data.reputation = 0
	data.base_cohesion = 0
	data.situation_name_key = &"situation.dragon_invasion.name"
	data.phase_name_key = &"phase.dragon_approaches"
	var message := DashboardViewData.MessageItem.new()
	message.instance_id = &"message_signal_safety"
	message.week_index = 1
	message.title_key = &"message.contract_offers.title"
	message.body_key = &"message.contract_offers.body"
	message.importance = &"normal"
	message.is_read = is_read
	data.messages.append(message)
	return data


func _ending_input_signature(state) -> String:
	return "%d|%s|%s|%s|%d|%d" % [
		state.week_index,
		state.situation.phase_id,
		state.situation.ending_id,
		state.situation.clock_values,
		state.contract_history.size(),
		state.world_events.size(),
	]


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
