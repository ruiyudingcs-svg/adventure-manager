class_name SaveResult
extends RefCounted

const SaveIssue = preload("res://game/persistence/save_issue.gd")

var path: String
var canonical_state_json: String
var issues: Array[SaveIssue]


func is_success() -> bool:
	return not path.is_empty() and issues.is_empty()
