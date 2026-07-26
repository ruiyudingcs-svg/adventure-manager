class_name SaveService
extends RefCounted

const SaveIssue = preload("res://game/persistence/save_issue.gd")
const SaveResult = preload("res://game/persistence/save_result.gd")
const LoadResult = preload("res://game/persistence/load_result.gd")
const SaveMetadataResult = preload(
	"res://game/persistence/save_metadata_result.gd"
)
const CampaignStateCodec = preload(
	"res://game/persistence/campaign_state_codec.gd"
)
const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const StableId = preload("res://game/core/ids/stable_id.gd")

const FORMAT: String = "adventure_manager_campaign"
const SAVE_VERSION: int = 1
const TEMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"


## Writes schema-v1 JSON via verified same-directory temp and backup replacement.
func save_planning_state(
	path: String,
	setup_id: StringName,
	campaign_state: CampaignState
) -> SaveResult:
	var result := SaveResult.new()
	if path.is_empty():
		result.issues.append(_issue(
			path, "$", &"invalid_path", "Save path cannot be empty."
		))
		return result
	if not StableId.is_valid(setup_id):
		result.issues.append(_issue(
			path,
			"$.campaign_setup_id",
			&"invalid_setup",
			"Campaign setup ID is required."
		))
	if campaign_state == null:
		result.issues.append(_issue(
			path,
			"$.campaign_state",
			&"missing_state",
			"CampaignState is required."
		))
	elif not campaign_state.validate().is_empty():
		result.issues.append(_issue(
			path,
			"$.campaign_state",
			&"invalid_state",
			"CampaignState validation failed before serialization."
		))
	if not result.issues.is_empty():
		return result

	var state_dto := CampaignStateCodec.encode_state(campaign_state)
	result.canonical_state_json = JSON.stringify(state_dto, "", true, true)
	var envelope := {
		"format": FORMAT,
		"save_version": SAVE_VERSION,
		"campaign_setup_id": String(setup_id),
		"saved_at_unix_seconds": int(Time.get_unix_time_from_system()),
		"campaign_state": state_dto,
	}
	var json_text := JSON.stringify(envelope, "\t", true, true) + "\n"
	var temp_path := path + TEMP_SUFFIX
	var backup_path := path + BACKUP_SUFFIX
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	var directory := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			result.issues.append(_file_error(
				path, &"create_directory_failed", mkdir_error
			))
			return result
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		result.issues.append(_file_error(
			temp_path, &"temporary_write_failed", FileAccess.get_open_error()
		))
		return result
	file.store_string(json_text)
	file.flush()
	file.close()

	var verification := _load_single(temp_path, null)
	if (
		not verification.is_success()
		or verification.campaign_setup_id != setup_id
		or verification.canonical_state_json != result.canonical_state_json
	):
		result.issues.append_array(verification.issues)
		if verification.issues.is_empty():
			result.issues.append(_issue(
				temp_path,
				"$",
				&"temporary_verification_failed",
				"Temporary save content did not match the source state."
			))
		DirAccess.remove_absolute(absolute_temp)
		return result

	var had_existing := FileAccess.file_exists(path)
	if FileAccess.file_exists(backup_path):
		var stale_backup_error := DirAccess.remove_absolute(absolute_backup)
		if stale_backup_error != OK:
			result.issues.append(_file_error(
				backup_path, &"backup_cleanup_failed", stale_backup_error
			))
			DirAccess.remove_absolute(absolute_temp)
			return result
	if had_existing:
		var backup_error := DirAccess.rename_absolute(
			absolute_path, absolute_backup
		)
		if backup_error != OK:
			result.issues.append(_file_error(
				path, &"backup_create_failed", backup_error
			))
			DirAccess.remove_absolute(absolute_temp)
			return result
	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_path)
	if replace_error != OK:
		if had_existing and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		result.issues.append(_file_error(
			path, &"atomic_replace_failed", replace_error
		))
		return result
	if had_existing and FileAccess.file_exists(backup_path):
		var cleanup_error := DirAccess.remove_absolute(absolute_backup)
		if cleanup_error != OK:
			result.issues.append(_file_error(
				backup_path, &"backup_cleanup_failed", cleanup_error
			))
			return result
	result.path = path
	return result


## Loads the primary file. A valid .bak is exposed but never silently published.
func load_planning_state(path: String, data_catalog: Node) -> LoadResult:
	var primary := _load_single(path, data_catalog)
	if primary.is_success():
		return primary
	var backup_path := path + BACKUP_SUFFIX
	if not FileAccess.file_exists(backup_path):
		return primary
	var backup := _load_single(backup_path, data_catalog)
	if backup.is_success():
		primary.recovery_path = backup_path
		primary.recovery_campaign_setup_id = backup.campaign_setup_id
		primary.recovery_saved_at_unix_seconds = (
			backup.saved_at_unix_seconds
		)
		primary.recovery_state = backup.campaign_state.duplicate_state()
		primary.recovery_canonical_state_json = (
			backup.canonical_state_json
		)
	return primary


func inspect_save(path: String) -> SaveMetadataResult:
	var metadata := SaveMetadataResult.new()
	metadata.path = path
	var loaded := _load_single(path, null)
	metadata.issues.append_array(loaded.issues)
	if loaded.campaign_state == null:
		return metadata
	metadata.format = FORMAT
	metadata.save_version = SAVE_VERSION
	metadata.campaign_setup_id = loaded.campaign_setup_id
	metadata.saved_at_unix_seconds = loaded.saved_at_unix_seconds
	metadata.week_index = loaded.campaign_state.week_index
	metadata.has_active_plan = loaded.campaign_state.active_plan != null
	return metadata


func _load_single(path: String, data_catalog: Node) -> LoadResult:
	var result := LoadResult.new()
	result.path = path
	if not FileAccess.file_exists(path):
		result.issues.append(_issue(
			path, "$", &"file_missing", "Save file does not exist."
		))
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.issues.append(_file_error(
			path, &"file_open_failed", FileAccess.get_open_error()
		))
		return result
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		result.issues.append(_issue(
			path,
			"$",
			&"json_parse_failed",
			"JSON parse failed at line %d: %s"
			% [json.get_error_line(), json.get_error_message()]
		))
		return result
	if typeof(json.data) != TYPE_DICTIONARY:
		result.issues.append(_issue(
			path, "$", &"wrong_root_type", "JSON root must be an object."
		))
		return result
	var root: Dictionary = json.data
	if typeof(root.get("format")) != TYPE_STRING:
		result.issues.append(_issue(
			path, "$.format", &"wrong_type", "Expected a string."
		))
	elif root["format"] != FORMAT:
		result.issues.append(_issue(
			path, "$.format", &"format_mismatch", "Save format is not supported."
		))
	var version := _envelope_int(root, "save_version", path, result.issues)
	if version != SAVE_VERSION:
		result.issues.append(_issue(
			path,
			"$.save_version",
			&"unsupported_version",
			"Save version %d is not supported." % version
		))
	if typeof(root.get("campaign_setup_id")) != TYPE_STRING \
			or not StableId.is_valid(StringName(root.get("campaign_setup_id"))):
		result.issues.append(_issue(
			path,
			"$.campaign_setup_id",
			&"invalid_setup",
			"Campaign setup ID must be a non-empty string."
		))
	else:
		result.campaign_setup_id = StringName(root["campaign_setup_id"])
	result.saved_at_unix_seconds = _envelope_int(
		root, "saved_at_unix_seconds", path, result.issues
	)
	if result.saved_at_unix_seconds < 0:
		result.issues.append(_issue(
			path,
			"$.saved_at_unix_seconds",
			&"invalid_metadata",
			"Saved timestamp must be non-negative."
		))
	if not root.has("campaign_state"):
		result.issues.append(_issue(
			path,
			"$.campaign_state",
			&"missing_field",
			"Required field is missing."
		))
		return result
	if not result.issues.is_empty():
		return result
	var decoded := CampaignStateCodec.decode_state(
		root["campaign_state"], path
	)
	result.issues.append_array(decoded.issues)
	if not decoded.is_success():
		return result
	result.campaign_state = decoded.state.duplicate_state()
	result.canonical_state_json = CampaignStateCodec.canonical_state_json(
		result.campaign_state
	)
	if data_catalog != null:
		result.issues.append_array(_validate_definition_closure(
			result.campaign_state,
			result.campaign_setup_id,
			data_catalog,
			path
		))
		if not result.issues.is_empty():
			result.campaign_state = null
			result.canonical_state_json = ""
	return result


func _validate_definition_closure(
	state: CampaignState,
	setup_id: StringName,
	catalog: Node,
	file_path: String
) -> Array[SaveIssue]:
	var issues: Array[SaveIssue] = []
	if not catalog.call("is_loaded"):
		issues.append(_issue(
			file_path,
			"$.campaign_setup_id",
			&"catalog_unavailable",
			"DataCatalog is not loaded."
		))
		return issues
	var setup = catalog.call("get_campaign_setup", setup_id)
	if setup == null:
		issues.append(_missing_definition(
			file_path, "$.campaign_setup_id", setup_id
		))
		return issues
	if state.situation.definition_id != setup.situation_definition_id:
		issues.append(_issue(
			file_path,
			"$.campaign_state.situation.definition_id",
			&"outside_setup_closure",
			"Situation is outside the selected setup."
		))
	var expected_members: Array[StringName] = setup.adventurer_ids.duplicate()
	expected_members.sort()
	var actual_members: Array[StringName] = []
	actual_members.assign(state.adventurers.keys())
	actual_members.sort()
	if actual_members != expected_members:
		issues.append(_issue(
			file_path,
			"$.campaign_state.adventurers",
			&"outside_setup_closure",
			"Adventurer IDs do not match the selected setup."
		))
	var expected_factions: Array[StringName] = []
	for faction_setup in setup.faction_setups:
		expected_factions.append(faction_setup.faction_id)
	expected_factions.sort()
	var actual_factions: Array[StringName] = []
	actual_factions.assign(state.factions.keys())
	actual_factions.sort()
	if actual_factions != expected_factions:
		issues.append(_issue(
			file_path,
			"$.campaign_state.factions",
			&"outside_setup_closure",
			"Faction IDs do not match the selected setup."
		))
	for member_id: StringName in state.adventurers:
		if catalog.call("get_adventurer", member_id) == null:
			issues.append(_missing_definition(
				file_path,
				"$.campaign_state.adventurers.%s" % member_id,
				member_id
			))
	for faction_id: StringName in state.factions:
		if catalog.call("get_faction", faction_id) == null:
			issues.append(_missing_definition(
				file_path,
				"$.campaign_state.factions.%s" % faction_id,
				faction_id
			))
	var situation = catalog.call(
		"get_situation", state.situation.definition_id
	)
	if situation == null:
		issues.append(_missing_definition(
			file_path,
			"$.campaign_state.situation.definition_id",
			state.situation.definition_id
		))
		return issues
	var clock_ids := _ids_of(situation.clock_definitions)
	for clock_id: StringName in state.situation.clock_values:
		if not clock_ids.has(clock_id):
			issues.append(_missing_definition(
				file_path,
				"$.campaign_state.situation.clock_values.%s" % clock_id,
				clock_id
			))
	var phase_ids := _ids_of(situation.phase_definitions)
	if not phase_ids.has(state.situation.phase_id):
		issues.append(_missing_definition(
			file_path,
			"$.campaign_state.situation.phase_id",
			state.situation.phase_id
		))
	var problem_ids := _ids_of(situation.problem_definitions)
	for problem_id: StringName in state.situation.problems:
		if not problem_ids.has(problem_id):
			issues.append(_missing_definition(
				file_path,
				"$.campaign_state.situation.problems.%s" % problem_id,
				problem_id
			))
	var rule_ids := _ids_of(situation.trigger_rules)
	for rule_id: StringName in state.situation.triggered_rule_ids:
		if not rule_ids.has(rule_id):
			issues.append(_missing_definition(
				file_path,
				"$.campaign_state.situation.triggered_rule_ids",
				rule_id
			))
	var ending_ids := _ids_of(situation.ending_definitions)
	if (
		not state.situation.ending_id.is_empty()
		and not ending_ids.has(state.situation.ending_id)
	):
		issues.append(_missing_definition(
			file_path,
			"$.campaign_state.situation.ending_id",
			state.situation.ending_id
		))
	for contract_id: StringName in state.situation.unlocked_contract_ids:
		_validate_contract_id(
			catalog, contract_id, file_path,
			"$.campaign_state.situation.unlocked_contract_ids", issues
		)
	for index: int in range(state.pending_contracts.size()):
		var offer = state.pending_contracts[index]
		var path := "$.campaign_state.pending_contracts[%d]" % index
		_validate_contract_id(
			catalog, offer.definition_id, file_path,
			path + ".definition_id", issues
		)
		if not expected_factions.has(offer.sponsor_faction_id):
			issues.append(_issue(
				file_path,
				path + ".sponsor_faction_id",
				&"outside_setup_closure",
				"Offer sponsor is outside the selected setup."
			))
		if (
			not offer.related_problem_id.is_empty()
			and not problem_ids.has(offer.related_problem_id)
		):
			issues.append(_missing_definition(
				file_path, path + ".related_problem_id",
				offer.related_problem_id
			))
		var contract = catalog.call("get_contract", offer.definition_id)
		if contract != null:
			var check_ids: Array[StringName] = []
			for stage in contract.stages:
				check_ids.append(stage.check.id)
			for binding in offer.instantiation_snapshot.check_difficulty_deltas:
				if not check_ids.has(binding.check_id):
					issues.append(_missing_definition(
						file_path,
						path + ".instantiation_snapshot.check_difficulty_deltas",
						binding.check_id
					))
	if state.active_plan != null:
		for supply_id: StringName in state.active_plan.selected_supply_ids:
			if catalog.call("get_supply", supply_id) == null:
				issues.append(_missing_definition(
					file_path,
					"$.campaign_state.active_plan.selected_supply_ids",
					supply_id
				))
	for index: int in range(state.faction_action_commitments.size()):
		var commitment = state.faction_action_commitments[index]
		var path := "$.campaign_state.faction_action_commitments[%d]" % index
		var action = catalog.call(
			"get_faction_action", commitment.action_definition_id
		)
		if action == null:
			issues.append(_missing_definition(
				file_path, path + ".action_definition_id",
				commitment.action_definition_id
			))
		var faction = catalog.call("get_faction", commitment.faction_id)
		if faction == null \
				or not faction.weekly_action_ids.has(
					commitment.action_definition_id
				):
			issues.append(_issue(
				file_path,
				path + ".action_definition_id",
				&"outside_setup_closure",
				"Faction action does not belong to the saved faction."
			))
		if not problem_ids.has(commitment.target_problem_id):
			issues.append(_missing_definition(
				file_path, path + ".target_problem_id",
				commitment.target_problem_id
			))
	for index: int in range(state.contract_history.size()):
		var entry = state.contract_history[index]
		var path := "$.campaign_state.contract_history[%d]" % index
		_validate_contract_id(
			catalog, entry.contract_definition_id, file_path,
			path + ".contract_definition_id", issues
		)
		for supply_id: StringName in entry.supply_ids:
			if catalog.call("get_supply", supply_id) == null:
				issues.append(_missing_definition(
					file_path, path + ".supply_ids", supply_id
				))
	return issues


static func _validate_contract_id(
	catalog: Node,
	contract_id: StringName,
	file_path: String,
	json_path: String,
	issues: Array[SaveIssue]
) -> void:
	if catalog.call("get_contract", contract_id) == null:
		issues.append(_missing_definition(
			file_path, json_path, contract_id
		))


static func _ids_of(values: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for value in values:
		ids.append(value.id)
	return ids


static func _envelope_int(
	root: Dictionary,
	key: String,
	path: String,
	issues: Array[SaveIssue]
) -> int:
	if not root.has(key):
		issues.append(_issue(
			path, "$." + key, &"missing_field", "Required field is missing."
		))
		return -1
	var value: Variant = root[key]
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	issues.append(_issue(
		path, "$." + key, &"wrong_type", "Expected an integer."
	))
	return -1


static func _missing_definition(
	file_path: String,
	json_path: String,
	definition_id: StringName
) -> SaveIssue:
	return _issue(
		file_path,
		json_path,
		&"missing_definition",
		"Definition does not exist in the setup catalog: %s." % definition_id
	)


static func _file_error(
	path: String,
	code: StringName,
	error: Error
) -> SaveIssue:
	return _issue(
		path, "$", code, "File operation failed with error %d." % error
	)


static func _issue(
	file_path: String,
	json_path: String,
	code: StringName,
	message: String
) -> SaveIssue:
	return SaveIssue.create(code, file_path, json_path, message)
