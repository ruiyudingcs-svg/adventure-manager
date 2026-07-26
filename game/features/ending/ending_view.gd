extends Control

const UiText = preload("res://game/features/shared/ui_text.gd")
const EndingViewData = preload(
	"res://game/features/ending/ending_view_data.gd"
)

signal new_game_requested
signal title_requested

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var week_label: Label = %WeekLabel
@onready var content: VBoxContainer = %Content

var _view_data: EndingViewData


func _ready() -> void:
	%NewGameButton.pressed.connect(func() -> void:
		new_game_requested.emit()
	)
	%TitleButton.pressed.connect(func() -> void:
		title_requested.emit()
	)
	_render()


func set_view_data(value: EndingViewData) -> void:
	_view_data = value
	if is_node_ready():
		_render()


func _render() -> void:
	_clear(content)
	if _view_data == null:
		title_label.text = UiText.get_text(&"ending.unavailable")
		description_label.text = ""
		week_label.text = ""
		return
	title_label.text = UiText.get_text(_view_data.title_key)
	description_label.text = UiText.get_text(_view_data.description_key)
	week_label.text = UiText.get_text(&"ending.week") % _view_data.ending_week

	_add_heading(UiText.get_text(&"ending.clocks"))
	for row: EndingViewData.ClockRow in _view_data.clocks:
		_add_text("%s  %d / 100" % [
			UiText.get_text(row.label_key),
			row.value,
		])

	_add_heading(UiText.get_text(&"ending.events"))
	if _view_data.events.is_empty():
		_add_muted(UiText.get_text(&"ending.no_events"))
	for row: EndingViewData.EventRow in _view_data.events:
		_add_text("• %s · %s" % [
			UiText.get_text(&"label.week_format") % row.week_index,
			UiText.get_text(row.event_key),
		])

	_add_heading(UiText.get_text(&"ending.problems"))
	for row: EndingViewData.ProblemRow in _view_data.problems:
		var closed_suffix := (
			" · %s" % (UiText.get_text(&"ending.closed_week") % row.closed_week)
			if row.closed_week >= 0 else ""
		)
		_add_text("• %s · %s%s" % [
			UiText.get_text(row.title_key),
			UiText.get_text(StringName("problem_status.%s" % row.status)),
			closed_suffix,
		])

	_add_heading(UiText.get_text(&"ending.contracts"))
	if _view_data.contracts.is_empty():
		_add_muted(UiText.get_text(&"ending.no_contracts"))
	for row: EndingViewData.ContractRow in _view_data.contracts:
		var tier_text := (
			" · %s" % UiText.get_text(StringName("tier.%s" % row.result_tier))
			if not row.result_tier.is_empty() else ""
		)
		_add_text("• %s · %s · %s%s · %s %d" % [
			UiText.get_text(&"label.week_format") % row.week_index,
			UiText.get_text(row.title_key),
			UiText.get_text(StringName(
				"contract_status.%s" % row.terminal_status
			)),
			tier_text,
			UiText.get_text(&"label.reward"),
			row.reward,
		])

	_add_heading(UiText.get_text(&"ending.factions"))
	for row: EndingViewData.FactionRow in _view_data.factions:
		_add_text("• %s · %s %+d" % [
			UiText.get_text(row.name_key),
			UiText.get_text(&"ending.relation"),
			row.relation,
		])

	_add_heading(UiText.get_text(&"ending.members"))
	for row: EndingViewData.MemberRow in _view_data.members:
		_add_text("• %s · %s %d · %s %d (%s %d) · %s %d" % [
			row.display_name,
			UiText.get_text(&"label.fatigue"),
			row.fatigue,
			UiText.get_text(&"label.injury"),
			row.injury_severity,
			UiText.get_text(&"label.recovery_weeks"),
			row.recovery_weeks,
			UiText.get_text(&"label.morale"),
			row.morale,
		])

	_add_heading(UiText.get_text(&"ending.reasons"))
	if _view_data.reason_keys.is_empty():
		_add_muted(UiText.get_text(&"ending.no_reasons"))
	for reason_key: StringName in _view_data.reason_keys:
		_add_text("• %s" % UiText.get_text(reason_key))


func _add_heading(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.93, 0.79, 0.43))
	content.add_child(label)


func _add_text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)


func _add_muted(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.modulate = Color(0.62, 0.67, 0.75)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
