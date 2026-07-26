extends Control

const UiText = preload("res://game/features/shared/ui_text.gd")

signal continue_requested
signal new_game_requested

@onready var status_label: Label = %StatusLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	%Title.text = UiText.get_text(&"save.start_title")
	%Subtitle.text = UiText.get_text(&"save.start_subtitle")
	continue_button.text = UiText.get_text(&"save.continue")
	%NewGameButton.text = UiText.get_text(&"save.new_game")
	continue_button.pressed.connect(func() -> void:
		print("[UI DEBUG] continue game pressed")
		continue_requested.emit()
	)
	%NewGameButton.pressed.connect(func() -> void:
		print("[UI DEBUG] new game pressed")
		new_game_requested.emit()
	)


func set_status(message: String, can_continue: bool) -> void:
	status_label.text = message
	continue_button.disabled = not can_continue
