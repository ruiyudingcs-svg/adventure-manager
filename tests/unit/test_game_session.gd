extends RefCounted

const GameSessionScript = preload("res://game/app/game_session.gd")
const CampaignBootstrapFixtures = preload(
	"res://tests/fixtures/campaign_bootstrap_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_start_and_snapshot_isolation(),
		_test_mark_read_commit_boundary(),
	]


func _test_start_and_snapshot_isolation() -> Dictionary:
	var session: Node = GameSessionScript.new()
	session.call(
		"set_catalog_for_testing",
		CampaignBootstrapFixtures.create_catalog()
	)
	var started: bool = session.call(
		"start_new_campaign",
		CampaignBootstrapFixtures.SETUP_ID,
		140014
	)
	var first = session.call("get_campaign_snapshot")
	first.guild.gold = 0
	first.adventurers.clear()
	var second = session.call("get_campaign_snapshot")
	var passed: bool = started \
		and session.call("get_phase") == &"planning" \
		and second.guild.gold == 250 \
		and second.adventurers.size() == 8
	session.free()
	return _result(
		"GameSession starts planning and snapshots cannot mutate authority",
		passed,
		"Session phase or detached ownership boundary failed."
	)


func _test_mark_read_commit_boundary() -> Dictionary:
	var session: Node = GameSessionScript.new()
	session.call(
		"set_catalog_for_testing",
		CampaignBootstrapFixtures.create_catalog()
	)
	session.call(
		"start_new_campaign",
		CampaignBootstrapFixtures.SETUP_ID,
		140014
	)
	var before = session.call("get_campaign_snapshot")
	var target_id: StringName = before.message_history[0].instance_id
	var marked: bool = session.call("mark_message_read", target_id)
	var after = session.call("get_campaign_snapshot")
	var read_value := false
	for message in after.message_history:
		if message.instance_id == target_id:
			read_value = message.is_read
	var rejected: bool = not session.call(
		"mark_message_read",
		&"missing_message"
	)
	var final_state = session.call("get_campaign_snapshot")
	var still_read := false
	for message in final_state.message_history:
		if message.instance_id == target_id:
			still_read = message.is_read
	var passed: bool = marked and read_value and rejected and still_read
	session.free()
	return _result(
		"mark_read swaps only a successful official projector result",
		passed,
		"Successful read was lost or failed read changed official state."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
