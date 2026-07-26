## Deterministic external-playtest driver using only GameSession public commands.
class_name FullCampaignDriver
extends RefCounted

const GameSessionScript = preload("res://game/app/game_session.gd")
const PlanContractCommand = preload(
	"res://game/domain/contracts/plan_contract_command.gd"
)
const CampaignStateCodec = preload(
	"res://game/persistence/campaign_state_codec.gd"
)
const CampaignBootstrapFixtures = preload(
	"res://tests/fixtures/campaign_bootstrap_fixtures.gd"
)

const PATH_PRIORITIES: Dictionary = {
	"evacuation": [
		&"contract_scout_eastern_road",
		&"contract_north_road_evacuation",
		&"contract_rescue_mining_village",
		&"contract_escort_field_healers",
		&"contract_hold_stone_bridge",
	],
	"arcane": [
		&"contract_locate_dragon_lair",
		&"contract_collect_dragon_scales",
		&"contract_deploy_binding_towers",
		&"contract_hold_stone_bridge",
		&"contract_prepare_dragon_bait",
		&"contract_disrupt_necrotic_ritual",
	],
	"necrotic": [
		&"contract_recover_intact_corpses",
		&"contract_investigate_necrotic_source",
		&"contract_prepare_dragon_bait",
	],
}


class RunResult extends RefCounted:
	var policy: StringName
	var seed: int
	var report: Dictionary
	var signature: String
	var issues: PackedStringArray

	func is_success() -> bool:
		return issues.is_empty() \
			and not report.get("ending_id", "").is_empty()


static func run_campaign(
	policy: StringName,
	seed: int,
	checkpoint_suffix: String
) -> RunResult:
	var result := RunResult.new()
	result.policy = policy
	result.seed = seed
	var catalog = CampaignBootstrapFixtures.create_catalog()
	var session: Node = GameSessionScript.new()
	session.call("set_catalog_for_testing", catalog)
	if not session.call(
		"start_new_campaign",
		CampaignBootstrapFixtures.SETUP_ID,
		seed
	):
		result.issues.append(session.call("get_last_error"))
		session.free()
		catalog.free()
		return result

	var checkpoint_path := "user://task017_%s.json" % checkpoint_suffix
	_delete_checkpoint(checkpoint_path)
	var checkpoint_count := 0
	var guard := 0
	while session.call("get_phase") != &"ended" and guard < 40:
		guard += 1
		var phase: StringName = session.call("get_phase")
		if phase == &"resolution_review":
			if not session.call("acknowledge_resolution"):
				result.issues.append(session.call("get_last_error"))
				break
			continue
		if phase != &"planning":
			result.issues.append("Unexpected GameSession phase: %s." % phase)
			break
		var state = session.call("get_campaign_snapshot")
		if state.week_index > 15:
			result.issues.append("Campaign exceeded the accepted week window.")
			break
		if checkpoint_count == 0 and state.week_index >= 2:
			var before := CampaignStateCodec.canonical_state_json(state)
			if not session.call("save_game", checkpoint_path) \
					or not session.call("load_game", checkpoint_path):
				result.issues.append("Planning save/load checkpoint failed.")
				break
			var after := CampaignStateCodec.canonical_state_json(
				session.call("get_campaign_snapshot")
			)
			if before != after:
				result.issues.append("Save/load checkpoint changed canonical state.")
				break
			checkpoint_count += 1
			state = session.call("get_campaign_snapshot")

		if policy == &"skip_all":
			if not session.call("resolve_current_week", true):
				result.issues.append(session.call("get_last_error"))
				break
			continue
		if policy == &"decline_rotation" \
				and state.declined_offer_week != state.week_index:
			var decline_offer = _first_pending_offer(state)
			if decline_offer != null:
				var DeclineCommand = load(
					"res://game/domain/contracts/decline_contract_offer_command.gd"
				)
				session.call(
					"decline_offer",
					DeclineCommand.new(decline_offer.instance_id)
				)
				state = session.call("get_campaign_snapshot")

		var command = _choose_command(session, catalog, state, policy)
		if command == null:
			if not session.call("resolve_current_week", true):
				result.issues.append(session.call("get_last_error"))
				break
		elif not session.call("accept_plan", command) \
				or not session.call("resolve_current_week", false):
			result.issues.append(session.call("get_last_error"))
			break

	var final_state = session.call("get_campaign_snapshot")
	if guard >= 40:
		result.issues.append("Campaign loop guard was reached.")
	if session.call("get_phase") != &"ended":
		result.issues.append("Campaign did not reach the ended phase.")
	result.signature = (
		CampaignStateCodec.canonical_state_json(final_state)
		if final_state != null else ""
	)
	result.report = _build_report(
		final_state,
		policy,
		seed,
		checkpoint_count
	)
	_delete_checkpoint(checkpoint_path)
	session.free()
	catalog.free()
	return result


static func _choose_command(session, catalog, state, policy: StringName):
	var offers := _offer_candidates(state, catalog, policy)
	var member_ids: Array[StringName] = []
	member_ids.assign(state.adventurers.keys())
	member_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		var left_state = state.adventurers[left]
		var right_state = state.adventurers[right]
		if left_state.get_fatigue() != right_state.get_fatigue():
			return left_state.get_fatigue() < right_state.get_fatigue()
		return String(left) < String(right)
	)
	var supply_options := _supply_options(catalog, policy)
	var approach := _approach_for(policy)
	for offer in offers:
		for a: int in range(member_ids.size() - 3):
			for b: int in range(a + 1, member_ids.size() - 2):
				for c: int in range(b + 1, member_ids.size() - 1):
					for d: int in range(c + 1, member_ids.size()):
						var team: Array[StringName] = [
							member_ids[a],
							member_ids[b],
							member_ids[c],
							member_ids[d],
						]
						for supply_ids: Array[StringName] in supply_options:
							var command := PlanContractCommand.create(
								offer.instance_id,
								team,
								supply_ids,
								approach
							)
							if session.call("validate_plan", command).is_empty():
								return command
	return null


static func _offer_candidates(state, catalog, policy: StringName) -> Array:
	var offers: Array = []
	for offer in state.pending_contracts:
		if offer != null and offer.status == &"pending":
			offers.append(offer)
	offers.sort_custom(func(left, right) -> bool:
		var left_score := _offer_score(left, catalog, policy)
		var right_score := _offer_score(right, catalog, policy)
		if left_score != right_score:
			return left_score > right_score
		return String(left.instance_id) < String(right.instance_id)
	)
	return offers


static func _offer_score(offer, catalog, policy: StringName) -> int:
	if PATH_PRIORITIES.has(String(policy)):
		var priorities: Array = PATH_PRIORITIES[String(policy)]
		var index: int = priorities.find(offer.definition_id)
		return 1000 - index * 100 if index >= 0 else 0
	if policy == &"free_faction" \
			and offer.sponsor_faction_id == &"faction_free_adventurers":
		return 1000
	if policy == &"arcane_faction" \
			and offer.sponsor_faction_id == &"faction_arcane_guild":
		return 1000
	if policy == &"necrotic_faction" \
			and offer.sponsor_faction_id == &"faction_necrotic_collective":
		return 1000
	if policy == &"low_risk":
		var definition = catalog.get_contract(offer.definition_id)
		return 100 - definition.risk_level
	return offer.offered_reward


static func _supply_options(catalog, policy: StringName) -> Array:
	var options: Array = []
	if policy != &"high_supply":
		var empty: Array[StringName] = []
		options.append(empty)
		return options
	var definitions: Array = catalog.get_all_supplies()
	definitions.sort_custom(func(left, right) -> bool:
		if left.cost != right.cost:
			return left.cost > right.cost
		return String(left.id) < String(right.id)
	)
	for left_index: int in range(definitions.size()):
		for right_index: int in range(left_index + 1, definitions.size()):
			var pair: Array[StringName] = [
				definitions[left_index].id,
				definitions[right_index].id,
			]
			pair.sort()
			options.append(pair)
	for definition in definitions:
		var single: Array[StringName] = [definition.id]
		options.append(single)
	var empty: Array[StringName] = []
	options.append(empty)
	return options


static func _approach_for(policy: StringName) -> StringName:
	if policy == &"high_reward" \
			or policy == &"necrotic" \
			or policy == &"necrotic_faction":
		return &"aggressive"
	if policy == &"low_risk" \
			or policy == &"evacuation" \
			or policy == &"fatigue_rotation":
		return &"cautious"
	return &"balanced"


static func _first_pending_offer(state):
	var offers: Array = []
	for offer in state.pending_contracts:
		if offer != null and offer.status == &"pending":
			offers.append(offer)
	offers.sort_custom(func(left, right) -> bool:
		return String(left.instance_id) < String(right.instance_id)
	)
	return offers[0] if not offers.is_empty() else null


static func _build_report(
	state,
	policy: StringName,
	seed: int,
	checkpoint_count: int
) -> Dictionary:
	if state == null:
		return {}
	var tier_counts: Dictionary = {}
	var status_counts: Dictionary = {
		"resolved": 0,
		"skipped": 0,
		"declined": 0,
		"expired": 0,
		"npc_completed": 0,
		"escalated": 0,
	}
	for entry in state.contract_history:
		var status := String(entry.terminal_status)
		status_counts[status] = int(status_counts.get(status, 0)) + 1
		if entry.terminal_status == &"resolved":
			var tier := String(entry.result_tier)
			tier_counts[tier] = int(tier_counts.get(tier, 0)) + 1
	var member_final: Dictionary = {}
	var light_count := 0
	var heavy_count := 0
	var member_ids: Array[StringName] = []
	member_ids.assign(state.adventurers.keys())
	member_ids.sort()
	for member_id: StringName in member_ids:
		var member = state.adventurers[member_id]
		var injury: int = member.get_injury_severity()
		if injury >= 80:
			heavy_count += 1
		elif injury > 0:
			light_count += 1
		member_final[String(member_id)] = {
			"fatigue": member.get_fatigue(),
			"morale": member.get_morale(),
		}
	var relations: Dictionary = {}
	var faction_ids: Array[StringName] = []
	faction_ids.assign(state.factions.keys())
	faction_ids.sort()
	for faction_id: StringName in faction_ids:
		relations[String(faction_id)] = state.factions[faction_id].relation
	var clocks: Dictionary = {}
	var clock_ids: Array[StringName] = []
	clock_ids.assign(state.situation.clock_values.keys())
	clock_ids.sort()
	for clock_id: StringName in clock_ids:
		clocks[String(clock_id)] = state.situation.clock_values[clock_id]
	return {
		"policy": String(policy),
		"seed": seed,
		"ending_id": String(state.situation.ending_id),
		"ending_week": state.week_index,
		"final_gold": state.guild.gold,
		"result_tier_counts": tier_counts,
		"contracts": status_counts,
		"light_injury_count": light_count,
		"heavy_injury_count": heavy_count,
		"member_final_fatigue_morale": member_final,
		"faction_relations": relations,
		"five_clock_values": clocks,
		"save_load_checkpoints": checkpoint_count,
	}


static func _delete_checkpoint(path: String) -> void:
	for candidate: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
