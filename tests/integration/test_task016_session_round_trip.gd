extends RefCounted

const Task015Fixtures = preload("res://tests/fixtures/task015_fixtures.gd")
const CampaignStateCodec = preload(
	"res://game/persistence/campaign_state_codec.gd"
)
const DeclineContractOfferCommand = preload(
	"res://game/domain/contracts/decline_contract_offer_command.gd"
)

const PATH_ACCEPTED := "user://task016_accepted.json"
const PATH_MIDGAME := "user://task016_midgame.json"
const PATH_PHASE := "user://task016_phase.json"
const PATH_CLOSURE := "user://task016_closure.json"


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_accepted_plan_replays_exact_week_resolution(),
		_test_midgame_decline_commitment_message_and_history_round_trip(),
		_test_failed_load_preserves_current_session(),
		_test_only_planning_phase_can_save(),
		_test_missing_definition_is_rejected(),
		_test_recovery_requires_explicit_confirmation(),
	]


func _test_accepted_plan_replays_exact_week_resolution() -> Dictionary:
	_cleanup(PATH_ACCEPTED)
	var source := Task015Fixtures.create_session(160101)
	var accepted: bool = source.call(
		"accept_plan",
		Task015Fixtures.valid_command(source.call("get_campaign_snapshot"))
	)
	var before = source.call("get_campaign_snapshot")
	var saved: bool = source.call("save_game", PATH_ACCEPTED)
	var loaded_session := Task015Fixtures.create_session(999999)
	var loaded: bool = loaded_session.call("load_game", PATH_ACCEPTED)
	var after = loaded_session.call("get_campaign_snapshot")
	var before_signature := CampaignStateCodec.canonical_state_json(before)
	var after_signature := CampaignStateCodec.canonical_state_json(after)
	var source_resolved: bool = source.call("resolve_current_week", false)
	var loaded_resolved: bool = loaded_session.call(
		"resolve_current_week", false
	)
	var source_final := CampaignStateCodec.canonical_state_json(
		source.call("get_campaign_snapshot")
	)
	var loaded_final := CampaignStateCodec.canonical_state_json(
		loaded_session.call("get_campaign_snapshot")
	)
	var source_review: Dictionary = source.call(
		"get_resolution_review_snapshot", true
	)
	var loaded_review: Dictionary = loaded_session.call(
		"get_resolution_review_snapshot", true
	)
	var passed: bool = accepted \
		and saved \
		and loaded \
		and before_signature == after_signature \
		and source_resolved \
		and loaded_resolved \
		and source_final == loaded_final \
		and var_to_str(source_review) == var_to_str(loaded_review)
	source.free()
	loaded_session.free()
	_cleanup(PATH_ACCEPTED)
	return _result(
		"accepted plan round trip reproduces the exact WeekResolution",
		passed,
		"Locked planning state, review payload, or committed final state drifted."
	)


func _test_midgame_decline_commitment_message_and_history_round_trip() -> Dictionary:
	_cleanup(PATH_MIDGAME)
	var source := Task015Fixtures.create_session(160102)
	source.call("resolve_current_week", true)
	source.call("acknowledge_resolution")
	var state = source.call("get_campaign_snapshot")
	if not state.message_history.is_empty():
		source.call(
			"mark_message_read",
			state.message_history[0].instance_id
		)
	state = source.call("get_campaign_snapshot")
	var offer = Task015Fixtures.first_pending_offer(state)
	var declined: bool = source.call(
		"decline_offer",
		DeclineContractOfferCommand.create(offer.instance_id)
	)
	var saved: bool = source.call("save_game", PATH_MIDGAME)
	var loaded_session := Task015Fixtures.create_session(1)
	var loaded: bool = loaded_session.call("load_game", PATH_MIDGAME)
	var source_state = source.call("get_campaign_snapshot")
	var loaded_state = loaded_session.call("get_campaign_snapshot")
	var has_read := false
	for message in loaded_state.message_history:
		if message.is_read:
			has_read = true
			break
	var has_declined := false
	for item in loaded_state.pending_contracts:
		if item.status == &"declined":
			has_declined = true
			break
	var passed: bool = declined \
		and saved \
		and loaded \
		and source_state.week_index == 2 \
		and not source_state.faction_action_commitments.is_empty() \
		and has_read \
		and has_declined \
		and CampaignStateCodec.canonical_state_json(source_state) \
			== CampaignStateCodec.canonical_state_json(loaded_state)
	source.free()
	loaded_session.free()
	_cleanup(PATH_MIDGAME)
	return _result(
		"midgame commitments declined slot messages and history round trip",
		passed,
		"One authoritative midgame collection was lost or changed."
	)


func _test_failed_load_preserves_current_session() -> Dictionary:
	_cleanup(PATH_PHASE)
	var session := Task015Fixtures.create_session(160103)
	var before := CampaignStateCodec.canonical_state_json(
		session.call("get_campaign_snapshot")
	)
	_write(PATH_PHASE, "{invalid")
	var loaded: bool = session.call("load_game", PATH_PHASE)
	var after := CampaignStateCodec.canonical_state_json(
		session.call("get_campaign_snapshot")
	)
	var passed: bool = not loaded \
		and before == after \
		and session.call("get_phase") == &"planning"
	session.free()
	_cleanup(PATH_PHASE)
	return _result(
		"failed load preserves the current GameSession atomically",
		passed,
		"Invalid JSON replaced or changed the active session."
	)


func _test_only_planning_phase_can_save() -> Dictionary:
	_cleanup(PATH_PHASE)
	var session := Task015Fixtures.create_session(160104)
	var planning_saved: bool = session.call("save_game", PATH_PHASE)
	var original := _read(PATH_PHASE)
	session.call("resolve_current_week", true)
	var review_rejected: bool = not session.call("save_game", PATH_PHASE)
	var unchanged: bool = _read(PATH_PHASE) == original
	session.call("acknowledge_resolution")
	var next_planning_saved: bool = session.call("save_game", PATH_PHASE)
	var passed: bool = planning_saved \
		and review_rejected \
		and unchanged \
		and next_planning_saved
	session.free()
	_cleanup(PATH_PHASE)
	return _result(
		"only planning phases can save",
		passed,
		"Resolution review wrote a half-resolution save or planning was blocked."
	)


func _test_missing_definition_is_rejected() -> Dictionary:
	_cleanup(PATH_CLOSURE)
	var session := Task015Fixtures.create_session(160105)
	session.call("save_game", PATH_CLOSURE)
	var envelope: Dictionary = JSON.parse_string(_read(PATH_CLOSURE))
	envelope["campaign_state"]["situation"][
		"unlocked_contract_ids"
	][0] = "missing_contract"
	_write(PATH_CLOSURE, JSON.stringify(envelope))
	var before := CampaignStateCodec.canonical_state_json(
		session.call("get_campaign_snapshot")
	)
	var loaded: bool = session.call("load_game", PATH_CLOSURE)
	var after := CampaignStateCodec.canonical_state_json(
		session.call("get_campaign_snapshot")
	)
	var issue_text := " ".join(
		session.call("get_last_issues") as PackedStringArray
	)
	var passed: bool = not loaded \
		and before == after \
		and (
			"missing_definition" in issue_text
			or "unlocked_contract_ids" in issue_text
			or "CampaignState" in issue_text
		)
	session.free()
	_cleanup(PATH_CLOSURE)
	return _result(
		"definition closure rejects unknown IDs without replacing session",
		passed,
		"Unknown Definition ID was accepted or current state changed."
	)


func _test_recovery_requires_explicit_confirmation() -> Dictionary:
	_cleanup(PATH_CLOSURE)
	var source := Task015Fixtures.create_session(160106)
	source.call("save_game", PATH_CLOSURE)
	_write(PATH_CLOSURE + ".bak", _read(PATH_CLOSURE))
	_write(PATH_CLOSURE, "{broken")
	var target := Task015Fixtures.create_session(777777)
	var target_before := CampaignStateCodec.canonical_state_json(
		target.call("get_campaign_snapshot")
	)
	var silent_load: bool = target.call("load_game", PATH_CLOSURE)
	var unchanged := target_before == CampaignStateCodec.canonical_state_json(
		target.call("get_campaign_snapshot")
	)
	var confirmed_load: bool = target.call(
		"load_game", PATH_CLOSURE, true
	)
	var source_signature := CampaignStateCodec.canonical_state_json(
		source.call("get_campaign_snapshot")
	)
	var recovered_signature := CampaignStateCodec.canonical_state_json(
		target.call("get_campaign_snapshot")
	)
	var passed: bool = not silent_load \
		and unchanged \
		and confirmed_load \
		and source_signature == recovered_signature
	source.free()
	target.free()
	_cleanup(PATH_CLOSURE)
	return _result(
		"backup recovery requires explicit confirmation",
		passed,
		"Backup silently replaced the session or confirmation failed to load it."
	)


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
