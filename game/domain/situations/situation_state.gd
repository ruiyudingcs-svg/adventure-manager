class_name SituationState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)

var definition_id: StringName
var phase_id: StringName
var clock_values: Dictionary[StringName, int] = {}
var triggered_rule_ids: Array[StringName]
var unlocked_contract_ids: Array[StringName]
var problems: Dictionary[StringName, WorldProblemState] = {}
var ending_id: StringName


static func create(
	p_definition_id: StringName,
	p_phase_id: StringName,
	p_clock_values: Dictionary[StringName, int],
	p_triggered_rule_ids: Array[StringName],
	p_unlocked_contract_ids: Array[StringName],
	p_problems: Dictionary[StringName, WorldProblemState],
	p_ending_id: StringName = &""
) -> SituationState:
	var state := SituationState.new(
		p_definition_id,
		p_phase_id,
		p_clock_values,
		p_triggered_rule_ids,
		p_unlocked_contract_ids,
		p_problems,
		p_ending_id
	)
	if not state.validate().is_empty():
		return null
	return state


func _init(
	p_definition_id: StringName,
	p_phase_id: StringName,
	p_clock_values: Dictionary[StringName, int],
	p_triggered_rule_ids: Array[StringName],
	p_unlocked_contract_ids: Array[StringName],
	p_problems: Dictionary[StringName, WorldProblemState],
	p_ending_id: StringName
) -> void:
	definition_id = p_definition_id
	phase_id = p_phase_id
	for clock_id: StringName in p_clock_values:
		clock_values[clock_id] = p_clock_values[clock_id]
	triggered_rule_ids.append_array(p_triggered_rule_ids)
	# These arrays are authoritative stable-ID sets. Canonicalizing at every
	# copy/load boundary prevents prior process history from changing save and
	# whole-campaign signatures; trigger execution order remains Definition-owned.
	triggered_rule_ids.sort_custom(_stable_id_less)
	unlocked_contract_ids.append_array(p_unlocked_contract_ids)
	unlocked_contract_ids.sort_custom(_stable_id_less)
	for problem_id: StringName in p_problems:
		var problem: WorldProblemState = p_problems[problem_id]
		problems[problem_id] = problem.duplicate_state()
	ending_id = p_ending_id


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(definition_id):
		errors.append(StableId.validation_error(
			definition_id,
			"SituationState.definition_id"
		))
	if not StableId.is_valid(phase_id):
		errors.append(StableId.validation_error(phase_id, "SituationState.phase_id"))
	for clock_id: StringName in clock_values:
		if not StableId.is_valid(clock_id):
			errors.append(StableId.validation_error(clock_id, "SituationState clock ID"))
		var clock_value: int = clock_values[clock_id]
		if clock_value < 0 or clock_value > 100:
			errors.append("SituationState clock %s must be between 0 and 100." % clock_id)
	_append_unique_id_errors(errors, triggered_rule_ids, "triggered_rule_ids")
	_append_unique_id_errors(errors, unlocked_contract_ids, "unlocked_contract_ids")
	for problem_id: StringName in problems:
		var problem: WorldProblemState = problems[problem_id]
		if problem == null:
			errors.append("SituationState problem %s is null." % problem_id)
			continue
		if problem.definition_id != problem_id:
			errors.append("SituationState problem key must equal its definition ID.")
		errors.append_array(problem.validate())
	if not ending_id.is_empty() and not StableId.is_valid(ending_id):
		errors.append(StableId.validation_error(ending_id, "SituationState.ending_id"))
	return errors


func duplicate_state() -> SituationState:
	return SituationState.new(
		definition_id,
		phase_id,
		clock_values,
		triggered_rule_ids,
		unlocked_contract_ids,
		problems,
		ending_id
	)


static func _append_unique_id_errors(
	errors: PackedStringArray,
	values: Array[StringName],
	field_name: String
) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for value: StringName in values:
		if not StableId.is_valid(value):
			errors.append(StableId.validation_error(value, "SituationState.%s item" % field_name))
		if seen.has(value):
			errors.append("SituationState.%s contains duplicate %s." % [field_name, value])
		seen[value] = true


static func _stable_id_less(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
