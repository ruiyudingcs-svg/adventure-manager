class_name StableId
extends RefCounted


static func is_valid(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty() or text.begins_with("_") or text.ends_with("_"):
		return false

	var previous_was_underscore := false
	for index: int in range(text.length()):
		var code_point: int = text.unicode_at(index)
		var is_lowercase_letter: bool = code_point >= 97 and code_point <= 122
		var is_digit: bool = code_point >= 48 and code_point <= 57
		var is_underscore: bool = code_point == 95
		if not is_lowercase_letter and not is_digit and not is_underscore:
			return false
		if index == 0 and not is_lowercase_letter:
			return false
		if is_underscore and previous_was_underscore:
			return false
		previous_was_underscore = is_underscore
	return true


static func validation_error(value: StringName, field_name: String = "id") -> String:
	if is_valid(value):
		return ""
	return "%s must be a non-empty lower snake_case identifier." % field_name
