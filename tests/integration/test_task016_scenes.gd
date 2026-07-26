extends RefCounted

const STARTUP_SCENE = preload(
	"res://game/features/shared/save_startup_view.tscn"
)


func run(scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_startup_view_mouse_intents(scene_tree),
	]


func _test_startup_view_mouse_intents(
	scene_tree: SceneTree
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	scene_tree.root.add_child(viewport)
	var view: Control = STARTUP_SCENE.instantiate()
	viewport.add_child(view)
	var continue_button: Button = view.find_child(
		"ContinueButton", true, false
	)
	var new_button: Button = view.find_child("NewGameButton", true, false)
	view.set("status_label", view.find_child("StatusLabel", true, false))
	view.set("continue_button", continue_button)
	view.call("_ready")
	var intents := [false, false]
	view.continue_requested.connect(func() -> void: intents[0] = true)
	view.new_game_requested.connect(func() -> void: intents[1] = true)
	view.call("set_status", "fixture", true)
	continue_button.pressed.emit()
	new_button.pressed.emit()
	var passed: bool = intents[0] \
		and intents[1] \
		and not continue_button.disabled \
		and view.mouse_filter == Control.MOUSE_FILTER_STOP
	viewport.free()
	return _result(
		"startup continue and new-game controls emit mouse intents",
		passed,
		"Startup overlay blocked or failed to emit a button intent."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
