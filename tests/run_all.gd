extends SceneTree

const TEST_ROOT: String = "res://tests"
const TEST_FILE_PREFIX: String = "test_"

var _passed_count: int = 0
var _failed_count: int = 0


func _initialize() -> void:
	print("Adventure Manager test runner")
	var test_paths: PackedStringArray = _requested_test_paths()
	if test_paths.is_empty():
		test_paths = _discover_test_paths(TEST_ROOT)
	if test_paths.is_empty():
		_record_failure("test discovery", "No test files were found.")
	else:
		for test_path: String in test_paths:
			_run_test_file(test_path)

	print("Summary: %d passed, %d failed" % [_passed_count, _failed_count])
	quit(0 if _failed_count == 0 else 1)


func _requested_test_paths() -> PackedStringArray:
	var requested_paths := PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--test-file="):
			requested_paths.append(argument.trim_prefix("--test-file="))
	requested_paths.sort()
	return requested_paths


func _discover_test_paths(directory_path: String) -> PackedStringArray:
	var discovered_paths := PackedStringArray()
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		_record_failure("test discovery", "Cannot open %s." % directory_path)
		return discovered_paths

	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if not entry_name.begins_with("."):
			var entry_path: String = directory_path.path_join(entry_name)
			if directory.current_is_dir():
				discovered_paths.append_array(_discover_test_paths(entry_path))
			elif entry_name.begins_with(TEST_FILE_PREFIX) and entry_name.ends_with(".gd"):
				discovered_paths.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
	discovered_paths.sort()
	return discovered_paths


func _run_test_file(test_path: String) -> void:
	var test_script: Script = ResourceLoader.load(test_path, "Script") as Script
	if test_script == null:
		_record_failure(test_path, "Test script could not be loaded.")
		return
	if not test_script.can_instantiate():
		_record_failure(test_path, "Test script has parse errors and cannot be instantiated.")
		return

	var test_case: Object = test_script.new()
	if test_case == null or not test_case.has_method("run"):
		_record_failure(test_path, "Test script must provide run(scene_tree).")
		return

	var raw_results: Variant = test_case.call("run", self)
	if typeof(raw_results) != TYPE_ARRAY:
		_record_failure(test_path, "Test run() must return an Array of result dictionaries.")
		return

	var results: Array = raw_results
	for raw_result: Variant in results:
		if typeof(raw_result) != TYPE_DICTIONARY:
			_record_failure(test_path, "Test result is not a Dictionary.")
			continue

		var result: Dictionary = raw_result
		var result_name: String = str(result.get("name", "unnamed test"))
		var passed: bool = bool(result.get("passed", false))
		var message: String = str(result.get("message", ""))
		if passed:
			_passed_count += 1
			print("[PASS] %s :: %s" % [test_path, result_name])
		else:
			_record_failure("%s :: %s" % [test_path, result_name], message)


func _record_failure(test_name: String, message: String) -> void:
	_failed_count += 1
	push_error("[FAIL] %s — %s" % [test_name, message])
