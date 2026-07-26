class_name CheckDifficultyBinding
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")

const MIN_DIFFICULTY_DELTA: int = -20
const MAX_DIFFICULTY_DELTA: int = 20

var check_id: StringName
var difficulty_delta: int
var reason_codes: Array[StringName]


static func create(
	p_check_id: StringName,
	p_difficulty_delta: int,
	p_reason_codes: Array[StringName]
) -> CheckDifficultyBinding:
	var normalized_reason_codes: Array[StringName] = _stable_unique(p_reason_codes)
	if not validate_values(
		p_check_id,
		p_difficulty_delta,
		normalized_reason_codes
	).is_empty():
		return null
	return CheckDifficultyBinding.new(
		p_check_id,
		p_difficulty_delta,
		normalized_reason_codes
	)


func _init(
	p_check_id: StringName,
	p_difficulty_delta: int,
	p_reason_codes: Array[StringName]
) -> void:
	check_id = p_check_id
	difficulty_delta = p_difficulty_delta
	reason_codes.append_array(_stable_unique(p_reason_codes))


static func validate_values(
	p_check_id: StringName,
	p_difficulty_delta: int,
	p_reason_codes: Array[StringName]
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(p_check_id):
		errors.append(StableId.validation_error(
			p_check_id,
			"CheckDifficultyBinding.check_id"
		))
	if (
		p_difficulty_delta < MIN_DIFFICULTY_DELTA
		or p_difficulty_delta > MAX_DIFFICULTY_DELTA
	):
		errors.append(
			"CheckDifficultyBinding.difficulty_delta must be between %d and %d."
			% [MIN_DIFFICULTY_DELTA, MAX_DIFFICULTY_DELTA]
		)
	if p_difficulty_delta == 0:
		errors.append("CheckDifficultyBinding.difficulty_delta must be non-zero.")

	var seen: Dictionary[StringName, bool] = {}
	for reason_code: StringName in p_reason_codes:
		if not StableId.is_valid(reason_code):
			errors.append(StableId.validation_error(
				reason_code,
				"CheckDifficultyBinding.reason_codes item"
			))
		if seen.has(reason_code):
			errors.append(
				"CheckDifficultyBinding.reason_codes contains duplicate %s."
				% reason_code
			)
		seen[reason_code] = true
	if p_reason_codes.is_empty():
		errors.append(
			"CheckDifficultyBinding.reason_codes must explain a non-zero overlay."
		)
	return errors


func validate() -> PackedStringArray:
	return validate_values(check_id, difficulty_delta, reason_codes)


func duplicate_value() -> CheckDifficultyBinding:
	return CheckDifficultyBinding.new(check_id, difficulty_delta, reason_codes)


func content_signature() -> String:
	return "%s|%d|%s" % [check_id, difficulty_delta, reason_codes]


static func _stable_unique(source: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: StringName in source:
		if not result.has(value):
			result.append(value)
	return result
