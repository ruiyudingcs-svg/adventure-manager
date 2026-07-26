## Renders DashboardViewData and emits only user intent.
extends Control

const UiText = preload("res://game/features/shared/ui_text.gd")
const DashboardViewData = preload(
	"res://game/features/dashboard/dashboard_view_data.gd"
)

signal message_opened(message_id: StringName)

@onready var empty_label: Label = %EmptyLabel
@onready var tabs: TabContainer = %Tabs
@onready var overview_summary: Label = %OverviewSummary
@onready var clocks_list: VBoxContainer = %ClocksList
@onready var offers_list: HBoxContainer = %OffersList
@onready var actions_list: VBoxContainer = %ActionsList
@onready var alerts_list: VBoxContainer = %AlertsList
@onready var problems_list: VBoxContainer = %ProblemsList
@onready var inbox_list: VBoxContainer = %InboxList
@onready var message_detail: RichTextLabel = %MessageDetail

var _view_data: DashboardViewData


func _ready() -> void:
	tabs.tab_changed.connect(func(tab_index: int) -> void:
		print("[UI DEBUG] dashboard tab pressed: %d" % tab_index)
	)
	tabs.set_tab_title(0, UiText.get_text(&"tab.dashboard.overview"))
	tabs.set_tab_title(1, UiText.get_text(&"tab.dashboard.problems"))
	tabs.set_tab_title(2, UiText.get_text(&"tab.dashboard.inbox"))
	_render()


func set_view_data(value: DashboardViewData) -> void:
	_view_data = value
	if is_node_ready():
		_render()


func _render() -> void:
	var has_data := _view_data != null
	empty_label.visible = not has_data
	tabs.visible = has_data
	if not has_data:
		return
	overview_summary.text = "%s · %s · %s %d · %s %d" % [
		UiText.get_text(_view_data.situation_name_key),
		UiText.get_text(_view_data.phase_name_key),
		UiText.get_text(&"label.gold"),
		_view_data.gold,
		UiText.get_text(&"label.reputation"),
		_view_data.reputation,
	]
	_render_clocks()
	_render_offers()
	_render_actions()
	_render_alerts()
	_render_problems()
	_render_inbox()


func _render_clocks() -> void:
	_clear(clocks_list)
	for item: DashboardViewData.ClockItem in _view_data.clocks:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = UiText.get_text(item.label_key)
		label.custom_minimum_size.x = 150
		var progress := ProgressBar.new()
		progress.max_value = item.maximum
		progress.value = item.value
		progress.show_percentage = false
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.custom_minimum_size.y = 20
		var value := Label.new()
		value.text = "%d / %d" % [item.value, item.maximum]
		value.custom_minimum_size.x = 72
		row.add_child(label)
		row.add_child(progress)
		row.add_child(value)
		clocks_list.add_child(row)


func _render_offers() -> void:
	_clear(offers_list)
	if _view_data.offers.is_empty():
		offers_list.add_child(_muted_label(
			UiText.get_text(&"dashboard.no_offers")
		))
		return
	for item: DashboardViewData.OfferItem in _view_data.offers:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 12)
		var layout := VBoxContainer.new()
		var sponsor := Label.new()
		sponsor.text = UiText.get_text(item.faction_name_key)
		sponsor.modulate = Color(0.72, 0.77, 0.86)
		var title := Label.new()
		title.text = UiText.get_text(item.title_key)
		title.add_theme_font_size_override("font_size", 18)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var detail := Label.new()
		detail.text = "%s %d · %s %d" % [
			UiText.get_text(&"label.reward"),
			item.reward,
			UiText.get_text(&"label.remaining_turns"),
			item.remaining_turns,
		]
		layout.add_child(sponsor)
		layout.add_child(title)
		layout.add_child(detail)
		margin.add_child(layout)
		panel.add_child(margin)
		offers_list.add_child(panel)


func _render_actions() -> void:
	_clear(actions_list)
	if _view_data.committed_actions.is_empty():
		actions_list.add_child(_muted_label(
			UiText.get_text(&"dashboard.no_actions")
		))
		return
	for item: DashboardViewData.ActionItem in _view_data.committed_actions:
		var label := Label.new()
		label.text = "%s · %s → %s" % [
			UiText.get_text(item.faction_name_key),
			UiText.get_text(item.action_title_key),
			UiText.get_text(item.problem_title_key),
		]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		actions_list.add_child(label)
		for reason_key: StringName in item.player_reason_keys:
			actions_list.add_child(_muted_label(
				"  • %s" % UiText.get_text(reason_key)
			))


func _render_alerts() -> void:
	_clear(alerts_list)
	if _view_data.alert_keys.is_empty():
		alerts_list.add_child(_muted_label(
			UiText.get_text(&"dashboard.no_alerts")
		))
		return
	for key: StringName in _view_data.alert_keys:
		var label := Label.new()
		label.text = "• %s" % UiText.get_text(key)
		label.modulate = Color(0.96, 0.72, 0.4)
		alerts_list.add_child(label)


func _render_problems() -> void:
	_clear(problems_list)
	for item: DashboardViewData.ProblemItem in _view_data.problems:
		var panel := PanelContainer.new()
		var margin := MarginContainer.new()
		for side: String in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_%s" % side, 14)
		var layout := VBoxContainer.new()
		var title := Label.new()
		title.text = UiText.get_text(item.title_key)
		title.add_theme_font_size_override("font_size", 19)
		var status := Label.new()
		status.text = "%s：%s · %s：%s" % [
			UiText.get_text(&"label.urgency"),
			UiText.get_text(StringName("urgency.%s" % item.band)),
			UiText.get_text(&"label.remaining_turns"),
			(
				"—"
				if item.remaining_turns < 0
				else str(item.remaining_turns)
			),
		]
		layout.add_child(title)
		layout.add_child(status)
		for reason_key: StringName in item.player_reason_keys:
			layout.add_child(_muted_label(
				"• %s" % UiText.get_text(reason_key)
			))
		margin.add_child(layout)
		panel.add_child(margin)
		problems_list.add_child(panel)


func _render_inbox() -> void:
	_clear(inbox_list)
	message_detail.text = UiText.get_text(&"dashboard.select_message")
	if _view_data.messages.is_empty():
		inbox_list.add_child(_muted_label(
			UiText.get_text(&"dashboard.no_messages")
		))
		message_detail.text = UiText.get_text(&"dashboard.no_unread_messages")
		return
	var has_unread := false
	for item: DashboardViewData.MessageItem in _view_data.messages:
		has_unread = has_unread or not item.is_read
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s%s · %s" % [
			"" if item.is_read else "● ",
			UiText.get_text(item.title_key),
			UiText.get_text(StringName("importance.%s" % item.importance)),
		]
		button.tooltip_text = String(item.instance_id)
		button.pressed.connect(_open_message.bind(item))
		inbox_list.add_child(button)
	if not has_unread:
		message_detail.text = UiText.get_text(&"dashboard.no_unread_messages")


func _open_message(item: DashboardViewData.MessageItem) -> void:
	print("[UI DEBUG] dashboard message pressed: %s" % item.instance_id)
	message_detail.text = "[font_size=22]%s[/font_size]\n\n%s" % [
		UiText.get_text(item.title_key),
		UiText.get_text(item.body_key),
	]
	message_opened.emit(item.instance_id)


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.62, 0.67, 0.75)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		# A refresh can be requested by a child Button's own signal. Queueing the
		# release keeps the emitting Control alive until Godot unlocks it.
		child.queue_free()
