extends Control

const AppShellPresenter = preload(
	"res://game/features/shared/app_shell_presenter.gd"
)
const UiText = preload("res://game/features/shared/ui_text.gd")
const SAVE_STARTUP_SCENE = preload(
	"res://game/features/shared/save_startup_view.tscn"
)
const ONBOARDING_SCENE = preload(
	"res://game/features/onboarding/onboarding_view.tscn"
)
const DEFAULT_SETUP_ID: StringName = &"campaign_setup_dragon_invasion_v0_1"

@onready var screen_container: Control = %ScreenContainer
@onready var dashboard_button: Button = %DashboardButton
@onready var contracts_button: Button = %ContractsButton
@onready var roster_button: Button = %RosterButton
@onready var resolution_button: Button = %ResolutionButton
@onready var page_title: Label = %PageTitle
@onready var week_label: Label = %WeekLabel
@onready var gold_label: Label = %GoldLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var inbox_label: Label = %InboxLabel
@onready var save_button: Button = %SaveButton
@onready var primary_action: Button = %PrimaryAction
@onready var error_panel: PanelContainer = %ErrorPanel
@onready var error_label: Label = %ErrorLabel

var _startup_view: Control
var _onboarding_view: Control
var _onboarding_completed: bool


func _ready() -> void:
	print("[UI DEBUG] AppRoot ready")
	TranslationServer.set_locale("zh_CN")
	assert(screen_container != null, "AppRoot requires ScreenContainer.")
	var session := get_node_or_null("/root/GameSession")
	var router := get_node_or_null("/root/SceneRouter")
	assert(session != null, "AppRoot requires GameSession Autoload.")
	assert(router != null, "AppRoot requires SceneRouter Autoload.")
	_connect_navigation(router)
	session.campaign_replaced.connect(_on_campaign_replaced)
	session.message_read.connect(_on_message_read)
	session.session_error.connect(_show_error)
	router.route_changed.connect(_on_route_changed)
	router.ending_action_requested.connect(_on_ending_action_requested)
	router.call("bind_screen_container", screen_container)
	if session.call("has_campaign"):
		router.call("navigate", &"dashboard")
	else:
		_show_startup(session, router)
	_refresh_shell()


func _connect_navigation(router: Node) -> void:
	dashboard_button.pressed.connect(
		_on_navigation_pressed.bind(router, &"dashboard")
	)
	contracts_button.pressed.connect(
		_on_navigation_pressed.bind(router, &"contracts")
	)
	roster_button.pressed.connect(
		_on_navigation_pressed.bind(router, &"roster")
	)
	resolution_button.pressed.connect(
		_on_navigation_pressed.bind(router, &"resolution")
	)
	save_button.pressed.connect(_on_save_pressed)
	primary_action.pressed.connect(_on_primary_action)


func _on_navigation_pressed(router: Node, route_id: StringName) -> void:
	print("[UI DEBUG] navigation pressed: %s" % route_id)
	var accepted: bool = router.call("navigate", route_id)
	print("[UI DEBUG] navigation result: %s -> %s" % [route_id, accepted])


func _refresh_shell() -> void:
	var session := get_node_or_null("/root/GameSession")
	var router := get_node_or_null("/root/SceneRouter")
	if session == null or router == null:
		return
	var view_data := AppShellPresenter.present(
		session.call("get_campaign_snapshot"),
		session.call("get_phase"),
		router.call("get_current_route")
	)
	page_title.text = UiText.get_text(view_data.page_title_key)
	week_label.text = UiText.get_text(&"label.week_format") \
		% view_data.week_index
	gold_label.text = "%s %d" % [
		UiText.get_text(&"label.gold"),
		view_data.gold,
	]
	reputation_label.text = "%s %d" % [
		UiText.get_text(&"label.reputation"),
		view_data.reputation,
	]
	inbox_label.text = "%s %d" % [
		UiText.get_text(&"label.unread"),
		view_data.unread_messages,
	]
	resolution_button.disabled = not view_data.resolution_enabled
	var phase: StringName = session.call("get_phase")
	var ended := phase == &"ended"
	save_button.visible = not ended
	save_button.disabled = phase != &"planning"
	save_button.tooltip_text = (
		UiText.get_text(&"save.only_planning")
		if save_button.disabled else UiText.get_text(&"save.button_help")
	)
	primary_action.visible = view_data.primary_action_visible
	primary_action.text = UiText.get_text(view_data.primary_action_key)
	primary_action.disabled = not view_data.primary_action_enabled
	primary_action.tooltip_text = (
		UiText.get_text(view_data.primary_action_disabled_reason_key)
		if primary_action.disabled
			and not view_data.primary_action_disabled_reason_key.is_empty()
		else ""
	)
	for button: Button in [
		dashboard_button,
		contracts_button,
		roster_button,
		resolution_button,
	]:
		button.disabled = ended or (
			button == resolution_button and not view_data.resolution_enabled
		)
	resolution_button.tooltip_text = (
		UiText.get_text(&"resolution.unavailable_help")
		if resolution_button.disabled and not ended else ""
	)
	for pair: Array in [
		[dashboard_button, &"dashboard"],
		[contracts_button, &"contracts"],
		[roster_button, &"roster"],
		[resolution_button, &"resolution"],
	]:
		pair[0].button_pressed = pair[1] == view_data.route_id


func _on_route_changed(_route_id: StringName) -> void:
	_refresh_shell()


func _on_campaign_replaced() -> void:
	_refresh_shell()
	var session := get_node_or_null("/root/GameSession")
	var router := get_node_or_null("/root/SceneRouter")
	if session != null and router != null \
			and session.call("get_phase") == &"ended":
		router.call("navigate", &"ending")


func _on_message_read(_message_id: StringName) -> void:
	_refresh_shell()


func _show_error(message: String) -> void:
	error_label.text = message
	error_panel.visible = true


func _show_feedback(message: String) -> void:
	error_label.text = message
	error_panel.visible = true


func _dismiss_error() -> void:
	error_panel.visible = false


func _on_primary_action() -> void:
	var session := get_node_or_null("/root/GameSession")
	var router := get_node_or_null("/root/SceneRouter")
	print("[UI DEBUG] primary action pressed")
	if session == null or router == null:
		print("[UI DEBUG] primary action rejected: missing session/router")
		return
	var phase: StringName = session.call("get_phase")
	print("[UI DEBUG] primary action phase: %s" % phase)
	match phase:
		&"planning":
			var state = session.call("get_campaign_snapshot")
			if state == null:
				print("[UI DEBUG] primary action rejected: no campaign snapshot")
				return
			if state.active_plan == null:
				print("[UI DEBUG] opening skip-contract confirmation")
				_confirm_skip_contract(session, router)
			else:
				var resolved: bool = session.call(
					"resolve_current_week",
					false
				)
				print("[UI DEBUG] dispatch resolution result: %s" % resolved)
				if resolved:
					router.call("navigate", &"resolution")
		&"resolution_review":
			var acknowledged: bool = session.call("acknowledge_resolution")
			print("[UI DEBUG] acknowledge resolution result: %s" % acknowledged)
			if acknowledged:
				router.call(
					"navigate",
					&"ending"
					if session.call("get_phase") == &"ended"
					else &"dashboard"
				)
		_:
			print("[UI DEBUG] primary action ignored in phase: %s" % phase)


func _on_save_pressed() -> void:
	print("[UI DEBUG] save pressed")
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		print("[UI DEBUG] save rejected: missing session")
		return
	var saved: bool = session.call("save_game")
	print("[UI DEBUG] save result: %s" % saved)
	_show_feedback(
		UiText.get_text(&"save.success")
		if saved else UiText.get_text(&"save.failed")
	)
	_refresh_shell()


func _show_startup(session: Node, router: Node) -> void:
	if _startup_view != null:
		_startup_view.queue_free()
	_startup_view = SAVE_STARTUP_SCENE.instantiate()
	$ModalLayer.add_child(_startup_view)
	var metadata = session.call("inspect_save")
	var can_continue: bool = metadata != null and metadata.is_success()
	var status := UiText.get_text(&"save.no_save")
	var save_path: String = session.call("get_default_save_path")
	var primary_corrupt := false
	if can_continue:
		status = UiText.get_text(&"save.found") % metadata.week_index
	elif metadata != null and not metadata.issues.is_empty() \
			and metadata.issues[0].code != &"file_missing":
		primary_corrupt = true
		status = UiText.get_text(&"save.corrupt")
	if not can_continue and (
		FileAccess.file_exists(save_path + ".bak")
		or primary_corrupt
	):
		session.call("load_game")
		if session.call("has_recovery_candidate"):
			can_continue = true
			status = UiText.get_text(&"save.recovery_available")
	_startup_view.call("set_status", status, can_continue)
	_startup_view.connect(
		&"continue_requested",
		_on_continue_requested.bind(session, router)
	)
	_startup_view.connect(
		&"new_game_requested",
		_on_new_game_requested.bind(session, router)
	)


func _on_continue_requested(session: Node, router: Node) -> void:
	var loaded: bool = session.call("load_game")
	print("[UI DEBUG] continue load result: %s" % loaded)
	if loaded:
		_close_startup()
		router.call("navigate", &"dashboard")
		_refresh_shell()
		return
	if session.call("has_recovery_candidate"):
		_confirm_recovery(session, router)
	else:
		_startup_view.call(
			"set_status",
			UiText.get_text(&"save.load_failed"),
			false
		)


func _on_new_game_requested(session: Node, router: Node) -> void:
	var path: String = session.call("get_default_save_path")
	var has_existing := FileAccess.file_exists(path) \
		or FileAccess.file_exists(path + ".bak")
	if not has_existing:
		_start_new_campaign(session, router, false)
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = UiText.get_text(&"save.new_confirm_title")
	dialog.dialog_text = UiText.get_text(&"save.new_confirm_body")
	dialog.ok_button_text = UiText.get_text(&"save.new_game")
	dialog.cancel_button_text = UiText.get_text(&"common.cancel")
	dialog.confirmed.connect(
		_start_new_campaign.bind(session, router, true)
	)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	$ModalLayer.add_child(dialog)
	dialog.popup_centered(Vector2i(480, 190))


func _start_new_campaign(
	session: Node,
	router: Node,
	overwrite_existing: bool
) -> void:
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.randomize()
	var started: bool = session.call(
		"start_new_campaign",
		DEFAULT_SETUP_ID,
		seed_rng.randi()
	)
	print("[UI DEBUG] new campaign result: %s" % started)
	if not started:
		if _startup_view != null:
			_startup_view.call(
				"set_status",
				UiText.get_text(&"save.new_failed"),
				false
			)
		else:
			_show_error(UiText.get_text(&"save.new_failed"))
		return
	if overwrite_existing and not session.call("save_game"):
		if _startup_view != null:
			_startup_view.call(
				"set_status",
				UiText.get_text(&"save.failed"),
				false
			)
		else:
			_show_error(UiText.get_text(&"save.failed"))
		return
	_close_startup()
	router.call("navigate", &"dashboard")
	_refresh_shell()
	_show_onboarding()


func _confirm_recovery(session: Node, router: Node) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = UiText.get_text(&"save.recovery_title")
	dialog.dialog_text = UiText.get_text(&"save.recovery_body")
	dialog.ok_button_text = UiText.get_text(&"save.recover")
	dialog.cancel_button_text = UiText.get_text(&"common.cancel")
	dialog.confirmed.connect(func() -> void:
		var loaded: bool = session.call("load_game", session.call(
			"get_default_save_path"
		), true)
		print("[UI DEBUG] recovery load result: %s" % loaded)
		if loaded:
			_close_startup()
			router.call("navigate", &"dashboard")
			_refresh_shell()
	)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	$ModalLayer.add_child(dialog)
	dialog.popup_centered(Vector2i(500, 200))


func _close_startup() -> void:
	if _startup_view == null:
		return
	_startup_view.queue_free()
	_startup_view = null


func _confirm_skip_contract(session: Node, router: Node) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = UiText.get_text(&"toolbar.skip_confirm_title")
	dialog.dialog_text = UiText.get_text(&"toolbar.skip_confirm_body")
	dialog.ok_button_text = UiText.get_text(&"toolbar.end_week")
	dialog.cancel_button_text = UiText.get_text(&"common.cancel")
	dialog.confirmed.connect(func() -> void:
		print("[UI DEBUG] skip-contract confirmation accepted")
		var resolved: bool = session.call("resolve_current_week", true)
		print("[UI DEBUG] skip resolution result: %s" % resolved)
		if resolved:
			router.call("navigate", &"resolution")
	)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	$ModalLayer.add_child(dialog)
	dialog.popup_centered(Vector2i(460, 180))


func _show_onboarding() -> void:
	if _onboarding_completed or _onboarding_view != null:
		return
	_onboarding_view = ONBOARDING_SCENE.instantiate()
	$ModalLayer.add_child(_onboarding_view)
	_onboarding_view.completed.connect(_finish_onboarding)
	_onboarding_view.skipped.connect(_finish_onboarding)


func _finish_onboarding() -> void:
	_onboarding_completed = true
	if _onboarding_view != null:
		_onboarding_view.queue_free()
		_onboarding_view = null


func _on_ending_action_requested(action_id: StringName) -> void:
	var session := get_node_or_null("/root/GameSession")
	var router := get_node_or_null("/root/SceneRouter")
	if session == null or router == null:
		return
	if action_id == &"title":
		_show_startup(session, router)
	elif action_id == &"new_game":
		var dialog := ConfirmationDialog.new()
		dialog.title = UiText.get_text(&"ending.new_confirm_title")
		dialog.dialog_text = UiText.get_text(&"ending.new_confirm_body")
		dialog.ok_button_text = UiText.get_text(&"save.new_game")
		dialog.cancel_button_text = UiText.get_text(&"common.cancel")
		dialog.confirmed.connect(
			_start_new_campaign.bind(session, router, true)
		)
		dialog.close_requested.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		dialog.confirmed.connect(dialog.queue_free)
		$ModalLayer.add_child(dialog)
		dialog.popup_centered(Vector2i(500, 200))
