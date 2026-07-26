extends Control

const UiText = preload("res://game/features/shared/ui_text.gd")

const CAPABILITY_IDS: Array[StringName] = [
	&"frontline",
	&"offense",
	&"scouting",
	&"support",
	&"arcana",
	&"discipline",
]

signal offer_selected(offer_id: StringName)
signal member_toggled(member_id: StringName)
signal supply_toggled(supply_id: StringName)
signal approach_selected(approach: StringName)
signal accept_requested
signal decline_requested(offer_id: StringName)

@onready var offer_list: VBoxContainer = %OfferList
@onready var content: VBoxContainer = %Content
@onready var issue_label: Label = %IssueLabel
@onready var accept_button: Button = %AcceptButton
@onready var decline_button: Button = %DeclineButton

var _view_data
var _active_tab: StringName = &"offers"


func _ready() -> void:
	%OffersTab.pressed.connect(func() -> void: _set_tab(&"offers"))
	%DetailsTab.pressed.connect(func() -> void: _set_tab(&"details"))
	%SquadTab.pressed.connect(func() -> void: _set_tab(&"squad"))
	%ReviewTab.pressed.connect(func() -> void: _set_tab(&"review"))
	accept_button.pressed.connect(func() -> void: accept_requested.emit())
	decline_button.pressed.connect(_emit_decline)


func set_view_data(value) -> void:
	_view_data = value
	_render()


func show_inline_issue(key: String) -> void:
	issue_label.text = UiText.get_text(StringName(key))


func _set_tab(tab_id: StringName) -> void:
	print("[UI DEBUG] planning tab pressed: %s" % tab_id)
	_active_tab = tab_id
	_render_content()


func _render() -> void:
	_clear(offer_list)
	if _view_data == null:
		issue_label.text = UiText.get_text(&"planning.validation.no_campaign")
		accept_button.disabled = true
		decline_button.disabled = true
		_render_content()
		return
	for card in _view_data.offer_cards:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 88)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = card.is_declined_placeholder \
			or _view_data.plan_locked
		button.text = "%s\n%s · %s %d · %s %d" % [
			UiText.get_text(card.title_key),
			UiText.get_text(card.sponsor_name_key),
			UiText.get_text(&"label.reward"),
			card.reward,
			UiText.get_text(&"label.remaining_turns"),
			card.remaining_turns,
		]
		if card.is_declined_placeholder:
			button.text = "%s\n%s" % [
				button.text,
				UiText.get_text(&"planning.offer_declined"),
			]
		button.button_pressed = card.selected
		button.pressed.connect(func() -> void:
			offer_selected.emit(card.offer_instance_id)
		)
		offer_list.add_child(button)
	var issues := PackedStringArray()
	issues.append_array(_view_data.validation_issues)
	issue_label.text = (
		""
		if issues.is_empty()
		else _issue_text(issues[0])
	)
	accept_button.disabled = not _view_data.can_accept
	accept_button.tooltip_text = (
		""
		if _view_data.can_accept or issues.is_empty()
		else _issue_text(issues[0])
	)
	var selected_card = _selected_card()
	decline_button.disabled = (
		selected_card == null or not selected_card.can_decline
	)
	decline_button.tooltip_text = (
		UiText.get_text(&"planning.validation.decline_used")
		if _view_data.decline_quota_used else ""
	)
	_render_content()


func _render_content() -> void:
	_clear(content)
	if _view_data == null:
		return
	match _active_tab:
		&"offers":
			_render_offers()
		&"details":
			_render_details()
		&"squad":
			_render_squad()
		&"review":
			_render_review()


func _render_offers() -> void:
	_add_heading(UiText.get_text(&"planning.offers_heading"))
	_add_text(UiText.get_text(&"planning.offers_help"))
	for card in _view_data.offer_cards:
		_add_text("• %s — %s · %s %d · %s %d" % [
			UiText.get_text(card.title_key),
			UiText.get_text(card.sponsor_name_key),
			UiText.get_text(&"label.reward"),
			card.reward,
			UiText.get_text(&"planning.risk"),
			card.risk_level,
		])
		for reason_key: StringName in card.reason_keys:
			_add_text("  %s" % UiText.get_text(reason_key))


func _render_details() -> void:
	if _view_data.selected_offer_id.is_empty():
		_add_text(UiText.get_text(&"planning.validation.select_offer"))
		return
	_add_heading(UiText.get_text(_view_data.selected_title_key))
	_add_text(UiText.get_text(_view_data.selected_description_key))
	_add_heading(UiText.get_text(&"planning.four_phases"))
	for stage in _view_data.stages:
		_add_text("• %s — %s" % [
			UiText.get_text(StringName("phase.%s" % stage.phase)),
			UiText.get_text(StringName("check.%s" % stage.check_type)),
		])
	_add_heading(UiText.get_text(&"planning.clauses"))
	for clause in _view_data.clauses:
		_add_text("• [%s] %s\n  %s" % [
			UiText.get_text(StringName("clause.importance.%s" % clause.importance)),
			UiText.get_text(clause.title_key),
			UiText.get_text(clause.description_key),
		])


func _render_squad() -> void:
	_add_heading("%s (%d/4)" % [
		UiText.get_text(&"planning.squad"),
		_view_data.selected_member_count,
	])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for member in _view_data.members:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = member.selected
		button.disabled = _view_data.plan_locked or not member.available
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 116
		button.text = "%s\n%s\n%s\n%s %d · %s %d · %s %d" % [
			member.display_name,
			_capability_line(member, 0, 3),
			_capability_line(member, 3, 6),
			UiText.get_text(&"label.fatigue"),
			member.fatigue,
			UiText.get_text(&"label.morale"),
			member.morale,
			UiText.get_text(&"label.injury"),
			member.injury,
		]
		button.tooltip_text = String(member.member_id)
		button.pressed.connect(func() -> void:
			member_toggled.emit(member.member_id)
		)
		grid.add_child(button)
	content.add_child(grid)
	_add_heading("%s (%d/2)" % [
		UiText.get_text(&"planning.supplies"),
		_view_data.selected_supply_count,
	])
	for supply in _view_data.supplies:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = supply.selected
		button.disabled = (
			_view_data.plan_locked
			or not supply.allowed
			or _view_data.selected_offer_id.is_empty()
		)
		button.text = "%s · %s %d" % [
			UiText.get_text(supply.display_name_key),
			UiText.get_text(&"label.gold"),
			supply.cost,
		]
		button.pressed.connect(func() -> void:
			supply_toggled.emit(supply.supply_id)
		)
		content.add_child(button)
	_add_heading(UiText.get_text(&"planning.approach"))
	var option := OptionButton.new()
	for approach: StringName in [&"cautious", &"balanced", &"aggressive"]:
		option.add_item(UiText.get_text(StringName("approach.%s" % approach)))
		option.set_item_metadata(option.item_count - 1, approach)
		if approach == _view_data.approach:
			option.select(option.item_count - 1)
	option.disabled = _view_data.plan_locked
	option.item_selected.connect(func(index: int) -> void:
		approach_selected.emit(option.get_item_metadata(index))
	)
	content.add_child(option)


func _capability_line(member, from_index: int, to_index: int) -> String:
	var parts := PackedStringArray()
	for index: int in range(from_index, to_index):
		var capability_id: StringName = CAPABILITY_IDS[index]
		parts.append("%s %d" % [
			UiText.get_text(StringName("capability.%s" % capability_id)),
			int(member.capabilities.get(capability_id, 0)),
		])
	return " · ".join(parts)


func _render_review() -> void:
	if _view_data.selected_offer_id.is_empty():
		_add_text(UiText.get_text(&"planning.validation.select_offer"))
		return
	_add_heading(UiText.get_text(&"planning.review"))
	_add_text("%s: %d" % [
		UiText.get_text(&"planning.supply_cost"),
		_view_data.supply_cost_total,
	])
	if not _view_data.likely_tier_low.is_empty():
		_add_text("%s: %s — %s" % [
			UiText.get_text(&"planning.likely_range"),
			UiText.get_text(StringName(
				"tier.%s" % _view_data.likely_tier_low
			)),
			UiText.get_text(StringName(
				"tier.%s" % _view_data.likely_tier_high
			)),
		])
	for clause in _view_data.clauses:
		_add_text("• %s — %s" % [
			UiText.get_text(clause.title_key),
			UiText.get_text(StringName(
				"forecast.clause.%s" % (
					clause.forecast_status
					if not clause.forecast_status.is_empty() else &"unknown"
				)
			)),
		])
	for member in _view_data.members:
		if not member.selected:
			continue
		_add_text("• %s — %s / %s" % [
			member.display_name,
			UiText.get_text(StringName(
				"attitude.%s" % member.attitude_status
			)),
			UiText.get_text(StringName(
				"forecast.injury.%s" % member.injury_risk_band
			)),
		])
	for warning_key: StringName in _view_data.warning_keys:
		_add_text("⚠ %s" % UiText.get_text(warning_key))
	if _view_data.plan_locked:
		_add_text(UiText.get_text(&"planning.plan_locked"))


func _emit_decline() -> void:
	var selected_card = _selected_card()
	if selected_card != null:
		decline_requested.emit(selected_card.offer_instance_id)


func _selected_card():
	if _view_data == null:
		return null
	for card in _view_data.offer_cards:
		if card.selected:
			return card
	return null


func _add_heading(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.93, 0.79, 0.43))
	content.add_child(label)


func _add_text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)


func _issue_text(issue: String) -> String:
	if issue.begins_with("planning."):
		return UiText.get_text(StringName(issue))
	var normalized := issue.to_lower()
	if "exactly four" in normalized:
		return UiText.get_text(&"planning.validation.four_members")
	if "at most two" in normalized:
		return UiText.get_text(&"planning.validation.two_supplies")
	if "unavailable" in normalized:
		return UiText.get_text(&"planning.validation.member_unavailable")
	if "refuses" in normalized or "opposed" in normalized:
		return UiText.get_text(&"planning.validation.member_refuses")
	if "supply" in normalized and (
		"unknown" in normalized or "not allowed" in normalized
	):
		return UiText.get_text(&"planning.validation.supply_invalid")
	if "gold" in normalized or "budget" in normalized:
		return UiText.get_text(&"planning.validation.over_budget")
	if "offer" in normalized:
		return UiText.get_text(&"planning.validation.offer_locked")
	return issue


func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
