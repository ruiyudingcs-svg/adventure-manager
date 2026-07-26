extends Control

const UiText = preload("res://game/features/shared/ui_text.gd")

const HIDDEN_CHANGE_FIELDS: Array[StringName] = [
	&"terminal_reason_code",
	&"resolution_reason_code",
]

@onready var content: VBoxContainer = %Content
var _view_data
var _active_tab: StringName = &"summary"


func _ready() -> void:
	%SummaryTab.pressed.connect(func() -> void: _set_tab(&"summary"))
	%PhasesTab.pressed.connect(func() -> void: _set_tab(&"phases"))
	%MembersTab.pressed.connect(func() -> void: _set_tab(&"members"))
	%WorldTab.pressed.connect(func() -> void: _set_tab(&"world"))
	%ReasonsTab.pressed.connect(func() -> void: _set_tab(&"reasons"))


func set_view_data(value) -> void:
	_view_data = value
	_render()


func _set_tab(tab_id: StringName) -> void:
	print("[UI DEBUG] resolution tab pressed: %s" % tab_id)
	_active_tab = tab_id
	_render()


func _render() -> void:
	_clear()
	if _view_data == null:
		_add_text(UiText.get_text(&"resolution.none"))
		return
	match _active_tab:
		&"summary":
			_render_summary()
		&"phases":
			_render_phases()
		&"members":
			_render_members()
		&"world":
			_render_world()
		&"reasons":
			_render_reasons()


func _render_summary() -> void:
	_add_heading("%s %d" % [
		UiText.get_text(&"resolution.week_result"),
		_view_data.resolved_week,
	])
	if _view_data.skipped_contract:
		_add_text(UiText.get_text(&"resolution.contract_skipped"))
	else:
		_add_heading(UiText.get_text(_view_data.contract_title_key))
		_add_text("%s · %s" % [
			UiText.get_text(_view_data.sponsor_name_key),
			UiText.get_text(StringName("tier.%s" % _view_data.final_tier)),
		])
		_add_text("%s %d · %s %d" % [
			UiText.get_text(&"resolution.reward"),
			_view_data.reward,
			UiText.get_text(&"resolution.supply_cost"),
			_view_data.supply_cost_total,
		])
		_add_text("%s %+d" % [
			UiText.get_text(&"resolution.sponsor_relation"),
			_view_data.sponsor_relation_delta,
		])
	if not _view_data.ending_id.is_empty():
		_add_text("%s: %s" % [
			UiText.get_text(&"resolution.ending"),
			UiText.get_text(StringName(
				"ending.%s.title" % _view_data.ending_id
			)),
		])


func _render_phases() -> void:
	for phase in _view_data.phases:
		_add_heading(UiText.get_text(StringName("phase.%s" % phase.phase)))
		_add_text("%s · %s %d · %s" % [
			UiText.get_text(StringName("check.%s" % phase.check_type)),
			UiText.get_text(&"resolution.score"),
			phase.score,
			UiText.get_text(StringName("tier.%s" % phase.result_tier)),
		])
		for key: StringName in phase.reason_keys:
			_add_text("  • %s" % UiText.get_text(key))
	for clause in _view_data.clauses:
		_add_text("• [%s] %s — %s" % [
			UiText.get_text(StringName(
				"clause.importance.%s" % clause.importance
			)),
			UiText.get_text(clause.title_key),
			UiText.get_text(
				&"resolution.clause_met"
				if clause.satisfied
				else &"resolution.clause_breached"
			),
		])


func _render_members() -> void:
	for member in _view_data.members:
		_add_heading(member.display_name)
		_add_text("%s %+d · %s %s · %s %+d" % [
			UiText.get_text(&"label.fatigue"),
			member.fatigue_delta,
			UiText.get_text(&"label.injury"),
			UiText.get_text(StringName(
				"injury_result.%s" % member.injury_result
			)),
			UiText.get_text(&"label.morale"),
			member.morale_delta,
		])


func _render_world() -> void:
	for title_key: StringName in _view_data.faction_action_titles:
		_add_text("• %s" % UiText.get_text(title_key))
	for change in _view_data.changes:
		if not _is_visible_change(change.field_path):
			continue
		_add_text("• %s · %s: %s → %s" % [
			_entity_label(
				change.target_id,
				StringName(change.field_path.get_slice(".", 0))
			),
			_field_label(change.field_path),
			_change_value(change.field_path, change.old_value),
			_change_value(change.field_path, change.new_value),
		])


func _render_reasons() -> void:
	for reason in _view_data.reasons:
		var key: StringName = (
			reason.localization_key
			if not reason.localization_key.is_empty() else reason.code
		)
		var description := UiText.get_text(key)
		var amount_text := _signed_number(reason.amount)
		if reason.target_id.is_empty():
			_add_text("• %s (%s)" % [description, amount_text])
		else:
			_add_text("• %s · %s (%s)" % [
				description,
				_entity_label(reason.target_id),
				amount_text,
			])


func _add_heading(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.93, 0.79, 0.43))
	content.add_child(label)


func _add_text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)


func _field_label(field_path: String) -> String:
	var leaf := _field_leaf(field_path)
	return UiText.get_text(StringName("state_field.%s" % leaf))


func _change_value(field_path: String, value: Variant) -> String:
	var leaf := _field_leaf(field_path)
	if leaf == "active_plan":
		return UiText.get_text(
			&"state_value.none"
			if value == null or String(value).is_empty()
			else &"state_value.present"
		)
	if leaf == "availability":
		return UiText.get_text(
			StringName("status.%s" % String(value)),
			String(value)
		)
	if leaf == "status":
		var root := field_path.get_slice(".", 0)
		var prefix := "problem_status" if root == "problem" else "contract_status"
		return UiText.get_text(
			StringName("%s.%s" % [prefix, String(value)]),
			String(value)
		)
	if value == null or (value is String and value.is_empty()):
		return UiText.get_text(&"state_value.none")
	if value is Array or value is PackedStringArray:
		return UiText.get_text(&"state_value.record_count") % value.size()
	return str(value)


func _entity_label(
	entity_id: StringName,
	entity_kind: StringName = &""
) -> String:
	var raw := String(entity_id)
	if raw.begins_with("contract_offer_"):
		return UiText.get_text(&"state_target.contract", raw)
	if raw == "guild" or raw == "campaign":
		return UiText.get_text(
			StringName("state_target.%s" % entity_id),
			raw
		)
	var key_patterns: Array[String] = []
	match entity_kind:
		&"adventurer":
			key_patterns.append("adventurer.%s.name")
		&"faction":
			key_patterns.append("faction.%s.name")
		&"clock":
			key_patterns.append("clock.%s.name")
		&"problem":
			key_patterns.append("problem.%s.title")
		&"situation":
			key_patterns.append("situation.%s.name")
		_:
			key_patterns.assign([
				"adventurer.%s.name",
				"faction.%s.name",
				"clock.%s.name",
				"problem.%s.title",
				"situation.%s.name",
			])
	for pattern: String in key_patterns:
		var key := StringName(pattern % entity_id)
		var translated := TranslationServer.translate(key)
		if translated != String(key):
			return translated
	return raw


func _field_leaf(field_path: String) -> String:
	var segments: PackedStringArray = field_path.split(".")
	return (
		segments[segments.size() - 1]
		if not segments.is_empty() else field_path
	)


func _is_visible_change(field_path: String) -> bool:
	if field_path.begins_with("contract_offer."):
		return false
	return not HIDDEN_CHANGE_FIELDS.has(StringName(_field_leaf(field_path)))


func _signed_number(value: float) -> String:
	var magnitude := (
		str(absi(roundi(value)))
		if is_equal_approx(value, roundf(value))
		else "%.2f" % absf(value)
	)
	if value > 0.0:
		return "+" + magnitude
	if value < 0.0:
		return "-" + magnitude
	return "0"


func _clear() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
