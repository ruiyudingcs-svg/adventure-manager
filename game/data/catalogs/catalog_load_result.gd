## Result of validation, compilation, and optional catalog publication.
class_name CatalogLoadResult
extends RefCounted

const ValidationIssue = preload("res://game/data/catalogs/validation_issue.gd")

var issues: Array[ValidationIssue]


## Creates a load result with copied structured issues.
static func create(p_issues: Array[ValidationIssue]) -> CatalogLoadResult:
	return CatalogLoadResult.new(p_issues)


func _init(p_issues: Array[ValidationIssue]) -> void:
	for issue: ValidationIssue in p_issues:
		issues.append(issue.duplicate_value())


## Reports whether validation, compilation, and atomic publication all succeeded.
func is_success() -> bool:
	return issues.is_empty()
