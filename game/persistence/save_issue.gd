class_name SaveIssue
extends RefCounted

var code: StringName
var file_path: String
var json_path: String
var message: String


static func create(
	p_code: StringName,
	p_file_path: String,
	p_json_path: String,
	p_message: String
) -> SaveIssue:
	return SaveIssue.new(p_code, p_file_path, p_json_path, p_message)


func _init(
	p_code: StringName,
	p_file_path: String,
	p_json_path: String,
	p_message: String
) -> void:
	code = p_code
	file_path = p_file_path
	json_path = p_json_path
	message = p_message


func display_text() -> String:
	var location := file_path
	if not json_path.is_empty():
		location += " " + json_path
	return "%s: %s" % [location, message]
