## Structured catalog diagnostic with stable location and error code.
class_name ValidationIssue
extends RefCounted

var code: StringName
var resource_path: String
var field_path: String
var message: String


## Creates one structured, stable catalog diagnostic.
static func create(
	p_code: StringName,
	p_resource_path: String,
	p_field_path: String,
	p_message: String
) -> ValidationIssue:
	return ValidationIssue.new(p_code, p_resource_path, p_field_path, p_message)


func _init(
	p_code: StringName,
	p_resource_path: String,
	p_field_path: String,
	p_message: String
) -> void:
	code = p_code
	resource_path = p_resource_path
	field_path = p_field_path
	message = p_message


## Returns a detached copy for result and caller isolation.
func duplicate_value() -> ValidationIssue:
	return ValidationIssue.new(code, resource_path, field_path, message)
