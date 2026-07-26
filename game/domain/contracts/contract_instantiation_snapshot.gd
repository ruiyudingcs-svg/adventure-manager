class_name ContractInstantiationSnapshot
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const CheckDifficultyBinding = preload(
	"res://game/domain/contracts/check_difficulty_binding.gd"
)
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

var evaluated_week: int
var check_difficulty_deltas: Array[CheckDifficultyBinding]
var initial_context: MissionContext
var reason_entries: Array[ReasonEntry]


static func create(
	p_evaluated_week: int,
	p_check_difficulty_deltas: Array[CheckDifficultyBinding],
	p_initial_context: MissionContext,
	p_reason_entries: Array[ReasonEntry]
) -> ContractInstantiationSnapshot:
	var normalized_bindings: Array[CheckDifficultyBinding] = (
		_copy_and_sort_bindings(p_check_difficulty_deltas)
	)
	var normalized_reasons: Array[ReasonEntry] = _stable_unique_reasons(
		p_reason_entries
	)
	if not validate_values(
		p_evaluated_week,
		normalized_bindings,
		p_initial_context,
		normalized_reasons
	).is_empty():
		return null
	return ContractInstantiationSnapshot.new(
		p_evaluated_week,
		normalized_bindings,
		p_initial_context,
		normalized_reasons
	)


func _init(
	p_evaluated_week: int,
	p_check_difficulty_deltas: Array[CheckDifficultyBinding],
	p_initial_context: MissionContext,
	p_reason_entries: Array[ReasonEntry]
) -> void:
	evaluated_week = p_evaluated_week
	check_difficulty_deltas = _copy_and_sort_bindings(
		p_check_difficulty_deltas
	)
	initial_context = (
		p_initial_context.duplicate_value()
		if p_initial_context != null
		else null
	)
	for reason: ReasonEntry in _stable_unique_reasons(p_reason_entries):
		reason_entries.append(reason.duplicate_value() if reason != null else null)


static func validate_values(
	p_evaluated_week: int,
	p_check_difficulty_deltas: Array[CheckDifficultyBinding],
	p_initial_context: MissionContext,
	p_reason_entries: Array[ReasonEntry]
) -> PackedStringArray:
	var errors := PackedStringArray()
	if p_evaluated_week < 0:
		errors.append(
			"ContractInstantiationSnapshot.evaluated_week must be non-negative."
		)
	if p_initial_context == null:
		errors.append(
			"ContractInstantiationSnapshot.initial_context must not be null."
		)

	var previous_check_id := ""
	var seen: Dictionary[StringName, bool] = {}
	for binding: CheckDifficultyBinding in p_check_difficulty_deltas:
		if binding == null:
			errors.append(
				"ContractInstantiationSnapshot.check_difficulty_deltas contains null."
			)
			continue
		errors.append_array(binding.validate())
		if seen.has(binding.check_id):
			errors.append(
				"ContractInstantiationSnapshot.check_difficulty_deltas contains "
				+ "duplicate check %s." % binding.check_id
			)
		var current_check_id: String = String(binding.check_id)
		if not previous_check_id.is_empty() and current_check_id < previous_check_id:
			errors.append(
				"ContractInstantiationSnapshot.check_difficulty_deltas must be "
				+ "sorted by check_id."
			)
		previous_check_id = current_check_id
		seen[binding.check_id] = true

	var seen_reason_codes: Dictionary[StringName, bool] = {}
	for reason: ReasonEntry in p_reason_entries:
		if reason == null:
			errors.append(
				"ContractInstantiationSnapshot.reason_entries contains null."
			)
			continue
		if not StableId.is_valid(reason.code):
			errors.append(StableId.validation_error(
				reason.code,
				"ContractInstantiationSnapshot reason code"
			))
		if seen_reason_codes.has(reason.code):
			errors.append(
				"ContractInstantiationSnapshot.reason_entries contains "
				+ "duplicate reason code %s." % reason.code
			)
		seen_reason_codes[reason.code] = true
	return errors


func validate() -> PackedStringArray:
	return validate_values(
		evaluated_week,
		check_difficulty_deltas,
		initial_context,
		reason_entries
	)


func duplicate_value() -> ContractInstantiationSnapshot:
	return ContractInstantiationSnapshot.new(
		evaluated_week,
		check_difficulty_deltas,
		initial_context,
		reason_entries
	)


func content_signature() -> String:
	var binding_parts := PackedStringArray()
	for binding: CheckDifficultyBinding in check_difficulty_deltas:
		binding_parts.append(
			"<null>" if binding == null else binding.content_signature()
		)

	var context_parts := PackedStringArray()
	if initial_context != null:
		for key: StringName in MissionContext.CONTEXT_KEYS:
			context_parts.append("%s:%d" % [key, initial_context.get_value(key)])
		context_parts.append("outcome_tags:%s" % [initial_context.outcome_tags])
		context_parts.append("used_method_tags:%s" % [initial_context.used_method_tags])

	var reason_parts := PackedStringArray()
	for reason: ReasonEntry in reason_entries:
		reason_parts.append(_reason_signature(reason))

	return "%d|%s|%s|%s" % [
		evaluated_week,
		binding_parts,
		context_parts,
		reason_parts,
	]


static func _copy_and_sort_bindings(
	source: Array[CheckDifficultyBinding]
) -> Array[CheckDifficultyBinding]:
	var copied: Array[CheckDifficultyBinding] = []
	for binding: CheckDifficultyBinding in source:
		copied.append(binding.duplicate_value() if binding != null else null)
	copied.sort_custom(_binding_less)
	return copied


static func _binding_less(
	left: CheckDifficultyBinding,
	right: CheckDifficultyBinding
) -> bool:
	if left == null:
		return right != null
	if right == null:
		return false
	return String(left.check_id) < String(right.check_id)


static func _stable_unique_reasons(
	source: Array[ReasonEntry]
) -> Array[ReasonEntry]:
	var result: Array[ReasonEntry] = []
	var seen: Dictionary[StringName, bool] = {}
	var included_null := false
	for reason: ReasonEntry in source:
		if reason == null:
			if not included_null:
				result.append(null)
				included_null = true
			continue
		if seen.has(reason.code):
			continue
		result.append(reason)
		seen[reason.code] = true
	return result


static func _reason_signature(reason: ReasonEntry) -> String:
	if reason == null:
		return "<null>"
	return "%s:%s:%s:%s:%s:%s:%s:%s:%s" % [
		reason.code,
		reason.category,
		reason.source_id,
		reason.target_id,
		reason.amount,
		reason.localization_key,
		_stable_variant_signature(reason.parameters),
		reason.phase,
		reason.visibility,
	]


static func _stable_variant_signature(value: Variant) -> String:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var entries := PackedStringArray()
		for key: Variant in dictionary:
			entries.append(
				"%s=%s" % [
					_stable_variant_signature(key),
					_stable_variant_signature(dictionary[key]),
				]
			)
		entries.sort()
		return "{%s}" % ",".join(entries)
	if value is Array:
		var values: Array = value
		var items := PackedStringArray()
		for item: Variant in values:
			items.append(_stable_variant_signature(item))
		return "[%s]" % ",".join(items)
	return "%s:%s" % [typeof(value), str(value)]
