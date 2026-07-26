class_name SaveMetadataResult
extends RefCounted

const SaveIssue = preload("res://game/persistence/save_issue.gd")

var path: String
var format: String
var save_version: int
var campaign_setup_id: StringName
var saved_at_unix_seconds: int
var week_index: int
var has_active_plan: bool
var issues: Array[SaveIssue]


func is_success() -> bool:
	return issues.is_empty() and format == "adventure_manager_campaign"
