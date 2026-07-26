extends RefCounted

const Task015Fixtures = preload("res://tests/fixtures/task015_fixtures.gd")
const SaveService = preload("res://game/persistence/save_service.gd")
const CampaignStateCodec = preload(
	"res://game/persistence/campaign_state_codec.gd"
)
const MissionContext = preload(
	"res://game/domain/contracts/mission_context.gd"
)
const ContractInstantiationSnapshot = preload(
	"res://game/domain/contracts/contract_instantiation_snapshot.gd"
)
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

const PATH_BASIC := "user://task016_basic.json"
const PATH_RECOVERY := "user://task016_recovery.json"
const PATH_INVALID := "user://task016_invalid.json"


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_first_week_round_trip_and_canonical_json(),
		_test_schema_rejects_version_type_and_missing_field(),
		_test_corrupt_primary_exposes_backup_without_silent_recovery(),
		_test_invalid_source_does_not_replace_existing_save(),
		_test_nested_typed_values_are_deep_and_lossless(),
	]


func _test_first_week_round_trip_and_canonical_json() -> Dictionary:
	_cleanup(PATH_BASIC)
	var session := Task015Fixtures.create_session(160001)
	var catalog = session.call("_catalog")
	var state = session.call("get_campaign_snapshot")
	var service := SaveService.new()
	var first = service.save_planning_state(
		PATH_BASIC,
		&"campaign_setup_dragon_invasion_v0_1",
		state
	)
	if not first.is_success():
		session.free()
		_cleanup(PATH_BASIC)
		return _result(
			"first-week planning round trip preserves canonical state JSON",
			false,
			"Initial save failed: %s" % _issues_text(first.issues)
		)
	var loaded = service.load_planning_state(PATH_BASIC, catalog)
	var second = service.save_planning_state(
		PATH_BASIC,
		&"campaign_setup_dragon_invasion_v0_1",
		loaded.campaign_state
	)
	var passed: bool = first.is_success() \
		and loaded.is_success() \
		and second.is_success() \
		and first.canonical_state_json == loaded.canonical_state_json \
		and first.canonical_state_json == second.canonical_state_json \
		and loaded.campaign_state != state
	session.free()
	_cleanup(PATH_BASIC)
	return _result(
		"first-week planning round trip preserves canonical state JSON",
		passed,
		"Save/load failed or canonical state content drifted."
	)


func _test_schema_rejects_version_type_and_missing_field() -> Dictionary:
	_cleanup(PATH_INVALID)
	var session := Task015Fixtures.create_session(160002)
	var service := SaveService.new()
	service.save_planning_state(
		PATH_INVALID,
		&"campaign_setup_dragon_invasion_v0_1",
		session.call("get_campaign_snapshot")
	)
	if not FileAccess.file_exists(PATH_INVALID):
		session.free()
		return _result(
			"schema rejects future version missing field and wrong type",
			false,
			"Fixture save was not created."
		)
	var envelope: Dictionary = JSON.parse_string(_read(PATH_INVALID))
	envelope["save_version"] = 99
	_write(PATH_INVALID, JSON.stringify(envelope))
	var future = service.load_planning_state(PATH_INVALID, session.call("_catalog"))
	envelope["save_version"] = 1
	envelope["campaign_state"].erase("guild")
	_write(PATH_INVALID, JSON.stringify(envelope))
	var missing = service.load_planning_state(PATH_INVALID, session.call("_catalog"))
	envelope["campaign_state"]["guild"] = "wrong"
	_write(PATH_INVALID, JSON.stringify(envelope))
	var wrong = service.load_planning_state(PATH_INVALID, session.call("_catalog"))
	var passed: bool = not future.is_success() \
		and _has_issue(future.issues, &"unsupported_version") \
		and not missing.is_success() \
		and _has_issue(missing.issues, &"missing_field") \
		and not wrong.is_success() \
		and _has_issue(wrong.issues, &"invalid_field")
	session.free()
	_cleanup(PATH_INVALID)
	return _result(
		"schema rejects future version missing field and wrong type",
		passed,
		"One malformed envelope was accepted or lacked a typed issue."
	)


func _test_corrupt_primary_exposes_backup_without_silent_recovery() -> Dictionary:
	_cleanup(PATH_RECOVERY)
	var session := Task015Fixtures.create_session(160003)
	var service := SaveService.new()
	var saved = service.save_planning_state(
		PATH_RECOVERY,
		&"campaign_setup_dragon_invasion_v0_1",
		session.call("get_campaign_snapshot")
	)
	if not saved.is_success():
		session.free()
		return _result(
			"corrupt primary exposes valid backup without silent recovery",
			false,
			"Fixture save failed: %s" % _issues_text(saved.issues)
		)
	_write(PATH_RECOVERY + ".bak", _read(PATH_RECOVERY))
	_write(PATH_RECOVERY, "{broken")
	var loaded = service.load_planning_state(
		PATH_RECOVERY,
		session.call("_catalog")
	)
	var passed: bool = saved.is_success() \
		and not loaded.is_success() \
		and loaded.campaign_state == null \
		and loaded.has_recovery_candidate() \
		and loaded.recovery_state != null \
		and loaded.recovery_state.week_index == 1
	session.free()
	_cleanup(PATH_RECOVERY)
	return _result(
		"corrupt primary exposes valid backup without silent recovery",
		passed,
		"Backup was unavailable, silently loaded, or failed validation."
	)


func _test_invalid_source_does_not_replace_existing_save() -> Dictionary:
	_cleanup(PATH_BASIC)
	var session := Task015Fixtures.create_session(160004)
	var service := SaveService.new()
	var state = session.call("get_campaign_snapshot")
	var saved = service.save_planning_state(
		PATH_BASIC,
		&"campaign_setup_dragon_invasion_v0_1",
		state
	)
	if not saved.is_success():
		session.free()
		return _result(
			"invalid source never replaces the existing save",
			false,
			"Fixture save failed: %s" % _issues_text(saved.issues)
		)
	var original := _read(PATH_BASIC)
	state.week_index = -1
	var rejected = service.save_planning_state(
		PATH_BASIC,
		&"campaign_setup_dragon_invasion_v0_1",
		state
	)
	var passed: bool = saved.is_success() \
		and not rejected.is_success() \
		and _read(PATH_BASIC) == original
	session.free()
	_cleanup(PATH_BASIC)
	return _result(
		"invalid source never replaces the existing save",
		passed,
		"Invalid CampaignState changed the formal save file."
	)


func _test_nested_typed_values_are_deep_and_lossless() -> Dictionary:
	_cleanup(PATH_BASIC)
	var session := Task015Fixtures.create_session(160005)
	var catalog = session.call("_catalog")
	var state = session.call("get_campaign_snapshot")
	var member_ids: Array[StringName] = []
	member_ids.assign(state.adventurers.keys())
	member_ids.sort()
	state.adventurers[member_ids[0]].set_relationship_delta(
		member_ids[1], -17
	)
	var nested_reason := ReasonEntry.create(
		&"save_nested_reason",
		&"save_test",
		&"save_test",
		state.pending_contracts[0].instance_id,
		3.5,
		&"reason.save_nested",
		{
			"id": &"typed_value",
			"count": 7,
			"nested": [&"tag_one", {"turns": 2}],
		},
		&"planning",
		&"debug"
	)
	var context_values: Dictionary[StringName, int] = {
		&"intel": 7,
		&"route_safety": 4,
	}
	var context := MissionContext.new(
		context_values,
		[&"outcome_saved"],
		[&"method_saved"]
	)
	var reasons: Array[ReasonEntry] = [nested_reason]
	state.pending_contracts[0].generation_reason_entries.append(
		nested_reason
	)
	state.pending_contracts[0].instantiation_snapshot = (
		ContractInstantiationSnapshot.create(
			state.pending_contracts[0].offered_week,
			[],
			context,
			reasons
		)
	)
	var service := SaveService.new()
	var saved = service.save_planning_state(
		PATH_BASIC,
		&"campaign_setup_dragon_invasion_v0_1",
		state
	)
	var loaded = service.load_planning_state(PATH_BASIC, catalog)
	var loaded_state = loaded.campaign_state
	var loaded_reason = (
		loaded_state.pending_contracts[0].generation_reason_entries[-1]
		if loaded_state != null else null
	)
	var passed: bool = saved.is_success() \
		and loaded.is_success() \
		and loaded_state.adventurers[member_ids[0]].get_relationship_deltas()[
			member_ids[1]
		] == -17 \
		and loaded_state.pending_contracts[0].instantiation_snapshot \
			.initial_context.get_value(&"intel") == 7 \
		and loaded_state.pending_contracts[0].instantiation_snapshot \
			.initial_context.outcome_tags == [&"outcome_saved"] \
		and loaded_reason != null \
		and typeof(loaded_reason.parameters["id"]) == TYPE_STRING_NAME \
		and typeof(loaded_reason.parameters["count"]) == TYPE_INT \
		and typeof(loaded_reason.parameters["nested"][1]["turns"]) == TYPE_INT \
		and CampaignStateCodec.canonical_state_json(state) \
			== CampaignStateCodec.canonical_state_json(loaded_state)
	session.free()
	_cleanup(PATH_BASIC)
	return _result(
		"nested relationships reasons and MissionContext round trip losslessly",
		passed,
		"Nested collection ownership or Variant types changed during JSON round trip."
	)


func _has_issue(issues: Array, code: StringName) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false


func _issues_text(issues: Array) -> String:
	var values := PackedStringArray()
	for issue in issues:
		values.append(issue.display_text())
	return " | ".join(values)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return text


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _cleanup(path: String) -> void:
	for candidate: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
