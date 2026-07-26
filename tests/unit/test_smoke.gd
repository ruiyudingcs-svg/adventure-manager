extends RefCounted

const MAIN_SCENE_PATH: String = "res://game/app/app_root.tscn"


func run(scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var scene_exists: bool = ResourceLoader.exists(MAIN_SCENE_PATH, "PackedScene")
	results.append(_result(
		"main scene path exists",
		scene_exists,
		"Expected %s to exist." % MAIN_SCENE_PATH
	))
	if not scene_exists:
		return results

	var packed_scene: PackedScene = ResourceLoader.load(MAIN_SCENE_PATH, "PackedScene") as PackedScene
	var scene_loaded: bool = packed_scene != null
	results.append(_result(
		"main scene loads",
		scene_loaded,
		"Expected %s to load as PackedScene." % MAIN_SCENE_PATH
	))
	if not scene_loaded:
		return results

	var app_root: Node = packed_scene.instantiate()
	var app_root_instantiated: bool = app_root != null and app_root.name == "AppRoot"
	results.append(_result(
		"app root instantiates",
		app_root_instantiated,
		"Expected an AppRoot scene instance."
	))
	if app_root == null:
		return results

	scene_tree.root.add_child(app_root)
	var screen_container: Node = app_root.find_child(
		"ScreenContainer",
		true,
		false
	)
	results.append(_result(
		"screen container exists",
		screen_container != null,
		"Expected AppRoot to expose SceneRouter's ScreenContainer."
	))

	app_root.free()
	results.append(_result(
		"app root releases",
		not is_instance_valid(app_root),
		"Expected the instantiated scene to be released."
	))
	return results


func _result(test_name: String, passed: bool, failure_message: String) -> Dictionary:
	return {
		"name": test_name,
		"passed": passed,
		"message": "" if passed else failure_message,
	}
