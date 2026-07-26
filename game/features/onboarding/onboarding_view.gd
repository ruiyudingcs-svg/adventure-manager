extends Control

const UiText = preload("res://game/features/shared/ui_text.gd")
const STEP_COUNT: int = 6

signal completed
signal skipped

@onready var progress_label: Label = %ProgressLabel
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var next_button: Button = %NextButton

var _step_index: int


func _ready() -> void:
	%SkipButton.pressed.connect(func() -> void:
		skipped.emit()
	)
	next_button.pressed.connect(_advance)
	_render()


func get_step_index() -> int:
	return _step_index


func _advance() -> void:
	if _step_index >= STEP_COUNT - 1:
		completed.emit()
		return
	_step_index += 1
	_render()


func _render() -> void:
	progress_label.text = UiText.get_text(&"onboarding.progress") % [
		_step_index + 1,
		STEP_COUNT,
	]
	title_label.text = UiText.get_text(StringName(
		"onboarding.step_%d.title" % (_step_index + 1)
	))
	body_label.text = UiText.get_text(StringName(
		"onboarding.step_%d.body" % (_step_index + 1)
	))
	next_button.text = UiText.get_text(
		&"onboarding.finish"
		if _step_index == STEP_COUNT - 1
		else &"onboarding.next"
	)
