extends RefCounted

const CatalogValidator = preload("res://game/data/catalogs/catalog_validator.gd")
const ContentManifest = preload("res://game/data/catalogs/content_manifest.gd")
const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)

const MANIFEST_PATH := "res://game/data/catalogs/v0_1_content_manifest.tres"
const CLOCK_SHORT := {
	&"villagers_evacuated": "E",
	&"settlement_destruction": "D",
	&"dragon_exhaustion": "X",
	&"capture_preparation": "P",
	&"necrotic_corruption": "C",
}
const CALIBRATION := {
	&"contract_hold_stone_bridge": ["E+12,D+4,X+10", "E+2,D+22,C+3"],
	&"contract_escort_field_healers": ["E+8,D+2,C-4", "E+2,D+14,C+8"],
	&"contract_rescue_mining_village": ["E+14,D+4,C-2", "E+3,D+20,C+12"],
	&"contract_scout_eastern_road": ["E+5,D+1", "D+10,C+2"],
	&"contract_locate_dragon_lair": ["D+1,X+4,P+12", "D+12,X-2"],
	&"contract_investigate_necrotic_source": ["D+2,C+8", "D+8,C+18"],
	&"contract_collect_dragon_scales": ["D+3,X+12,P+18", "D+18,X-4,P+2"],
	&"contract_disrupt_necrotic_ritual": ["D+3,C-18", "D+10,C+22"],
	&"contract_prepare_dragon_bait": ["D+10,X+14,C+10", "D+22,X+2,C+18"],
}
const ACTION_AUDIT := {
	&"action_free_alliance_evacuate_north_road": [16,30,2,8,&"event_free_alliance_evacuated_north_road","E+10,D+8"],
	&"action_free_alliance_reinforce_stone_bridge": [15,30,2,6,&"event_stone_bridge_secured","E+6,D+4,X+4"],
	&"action_free_alliance_stabilize_field_camp": [14,30,2,5,&"event_field_camp_stabilized","E+4,D+2,C-3"],
	&"action_free_alliance_search_mining_village": [15,35,2,7,&"event_mining_survivors_recovered","E+6,D+5"],
	&"action_free_alliance_patrol_refugee_route": [8,20,1,4,&"event_eastern_route_secured","E+3,D+2,X+2"],
	&"action_arcane_guild_locate_dragon_lair": [16,25,2,6,&"event_dragon_lair_located","D+1,X+2,P+8"],
	&"action_arcane_guild_collect_dragon_scales": [16,30,2,8,&"event_low_quality_scales_collected","D+3,X+6,P+10"],
	&"action_arcane_guild_deploy_binding_towers": [18,35,2,10,&"event_binding_towers_partially_operational","D+4,P+8"],
	&"action_arcane_guild_ward_necrotic_spread": [17,35,1,6,&"event_necrotic_spread_warded","D+1,P+2,C-8"],
	&"action_arcane_guild_analyze_flight_pattern": [8,20,1,4,&"event_dragon_flight_pattern_analyzed","D+1,X+2,P+4"],
	&"action_necrotic_collective_recover_corpses": [16,30,1,6,&"event_corpses_recovered_by_collective","C+12"],
	&"action_necrotic_collective_prepare_dragon_bait": [17,35,2,8,&"event_dragon_diverted","D+10,X+10,C+6"],
	&"action_necrotic_collective_secure_source": [18,35,2,7,&"event_necrotic_source_secured","D+2,C+8"],
	&"action_necrotic_collective_seed_resonance": [16,35,1,5,&"event_necrotic_resonance_seeded","D+3,C+8"],
}
const PROBLEM_AUDIT := {
	&"problem_eastern_road_blocked": [55,8,24,3,&"event_eastern_road_lost"],
	&"problem_evacuating_civilians": [45,6,18,4,&"event_evacuation_line_collapsed"],
	&"problem_field_medical_collapse": [50,8,24,3,&"event_field_medical_system_failed"],
	&"problem_mining_village_isolated": [55,10,20,3,&"event_mining_village_destroyed"],
	&"problem_dragon_location_unknown": [35,5,15,4,&"event_dragon_relocated"],
	&"problem_dragon_capture_window": [50,8,24,4,&"event_capture_window_closed"],
	&"problem_necrotic_spread": [60,10,20,3,&"event_necrotic_spread_surged"],
	&"problem_battlefield_corpses": [50,12,24,2,&"event_battlefield_dead_rose"],
	&"problem_dragon_assault_pressure": [60,8,24,3,&"event_village_burned"],
}


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_publication_closes_exact_content(),
		_contract_calibration_matches_accepted_table(),
		_check_tables_are_fully_explicit(),
		_actions_and_owners_match_accepted_catalog(),
		_problems_match_accepted_catalog(),
		_endings_and_last_defense_are_published(),
		_publication_validator_rejects_incomplete_content(),
	]


func _publication_closes_exact_content() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var passed: bool = catalog.get_all_adventurers().size() == 8 \
		and catalog.get_all_contracts().size() == 12 \
		and catalog.get_all_factions().size() == 3 \
		and catalog.get_all_clocks().size() == 5 \
		and catalog.get_all_problems().size() == 9 \
		and catalog.get_all_faction_actions().size() == 14 \
		and catalog.get_all_endings().size() == 4 \
		and catalog.get_all_situations().size() == 1
	return _result(
		"published manifest closes the exact 8/12/3/5/9/14/4/1 set",
		passed,
		"One or more Task013 publication counts differ."
	)


func _contract_calibration_matches_accepted_table() -> Dictionary:
	var manifest := ResourceLoader.load(MANIFEST_PATH) as ContentManifest
	var failures := PackedStringArray()
	for contract_id: StringName in CALIBRATION:
		var contract = _resource_by_id(manifest.contract_definitions, contract_id)
		var actual_success := _clock_signature(contract, &"success")
		var actual_failure := _clock_signature(contract, &"failure")
		var expected: Array = CALIBRATION[contract_id]
		if actual_success != expected[0] or actual_failure != expected[1]:
			failures.append("%s success=%s failure=%s" % [
				contract_id, actual_success, actual_failure,
			])
	return _result(
		"nine Gate E contracts preserve documented Success/Failure net deltas",
		failures.is_empty(),
		"; ".join(failures)
	)


func _check_tables_are_fully_explicit() -> Dictionary:
	var manifest := ResourceLoader.load(MANIFEST_PATH) as ContentManifest
	var passed := true
	for contract_id: StringName in CALIBRATION:
		var contract = _resource_by_id(manifest.contract_definitions, contract_id)
		passed = passed and contract.stages.size() == 4 \
			and contract.instantiation_rules.is_empty()
		for stage in contract.stages:
			passed = passed and stage.check.outcome_table.exceptional != null \
				and stage.check.outcome_table.success != null \
				and stage.check.outcome_table.partial != null \
				and stage.check.outcome_table.failure != null \
				and stage.check.outcome_table.severe != null
			for tier: StringName in [
				&"exceptional", &"success", &"partial", &"failure", &"severe",
			]:
				var outcome = stage.check.outcome_table.get(tier)
				passed = passed and outcome.outcome_tags.has(
					StringName("%s_%s" % [stage.check.id, tier])
				)
		for tier: StringName in [
			&"exceptional", &"success", &"partial", &"failure", &"severe",
		]:
			for effect in contract.final_outcome_table.get(tier).campaign_effects:
				passed = passed and effect.type != &"modify_clock"
	return _result(
		"all new contracts author five tiers explicitly without final clock duplication",
		passed,
		"Missing explicit tier/tag or a final outcome duplicated clock deltas."
	)


func _actions_and_owners_match_accepted_catalog() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var expected_counts := {
		&"faction_free_adventurers": 5,
		&"faction_arcane_guild": 5,
		&"faction_necrotic_collective": 4,
	}
	var owned: Dictionary[StringName, int] = {}
	var passed := true
	for faction_id: StringName in expected_counts:
		var faction = catalog.get_faction(faction_id)
		owned[faction_id] = faction.weekly_action_ids.size()
		passed = passed and owned[faction_id] == expected_counts[faction_id]
		for action_id: StringName in faction.weekly_action_ids:
			var action = catalog.get_faction_action(action_id)
			var expected: Array = ACTION_AUDIT[action_id]
			passed = passed and action != null \
				and action.base_intent_priority == expected[0] \
				and action.urgency_weight == expected[1] \
				and action.recent_repeat_cooldown == expected[2] \
				and action.influence_cost == expected[3] \
				and action.event_key == expected[4] \
				and _effect_signature(action.effects) == expected[5]
	return _result(
		"fourteen actions have exact 5/5/4 ownership and auditable events",
		passed,
		"Action ownership or required event/cost was incomplete: %s." % owned
	)


func _problems_match_accepted_catalog() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var passed := true
	for problem_id: StringName in PROBLEM_AUDIT:
		var problem = catalog.get_problem(problem_id)
		var expected: Array = PROBLEM_AUDIT[problem_id]
		var event_count := 0
		for effect in problem.escalation_effects:
			if effect.type == &"create_world_event" \
					and effect.target_id == expected[4]:
				event_count += 1
		passed = passed and problem.base_urgency == expected[0] \
			and problem.age_urgency_per_week == expected[1] \
			and problem.age_urgency_cap == expected[2] \
			and problem.response_window_weeks == expected[3] \
			and event_count == 1 \
			and not problem.contract_definition_ids.is_empty() \
			and not problem.resolution_rules.is_empty()
	return _result(
		"nine problems preserve urgency, deadline, escalation, and resolution anchors",
		passed,
		"A problem differs from the accepted docs/18 publication table."
	)


func _endings_and_last_defense_are_published() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var situation = catalog.get_situation(&"situation_dragon_invasion_v0_1")
	var priorities := {}
	for ending in catalog.get_all_endings():
		priorities[ending.id] = ending.priority
	var has_last_defense := false
	for rule in situation.trigger_rules:
		if rule.id == &"trigger_last_defense_kills_dragon":
			has_last_defense = true
			var event_count := 0
			for effect in rule.effects:
				if effect.type == &"create_world_event" \
						and effect.target_id == &"event_dragon_killed":
					event_count += 1
			has_last_defense = event_count == 1
	return _result(
		"four ending priorities and week-15 dragon death fallback are published",
		priorities == {
			&"ending_necrotic_catastrophe": 400,
			&"ending_dragon_slain_at_cost": 300,
			&"ending_arcane_capture": 200,
			&"ending_mass_evacuation": 100,
		} and has_last_defense,
		"Ending priorities or trigger_last_defense_kills_dragon differed."
	)


func _publication_validator_rejects_incomplete_content() -> Dictionary:
	var manifest := ResourceLoader.load(MANIFEST_PATH) as ContentManifest
	var duplicate := manifest.duplicate(true) as ContentManifest
	duplicate.faction_action_definitions.pop_back()
	var issues = CatalogValidator.new().validate(
		duplicate,
		"memory://task013_incomplete_publication"
	)
	var found := false
	for issue in issues:
		if issue.code == &"invalid_publication_count" \
				and issue.field_path == "faction_action_definitions":
			found = true
	return _result(
		"publication validator rejects an incomplete canonical catalog",
		found,
		"Expected invalid_publication_count for a missing faction action."
	)


func _clock_signature(contract, tier: StringName) -> String:
	var totals := {
		&"villagers_evacuated": 0,
		&"settlement_destruction": 0,
		&"dragon_exhaustion": 0,
		&"capture_preparation": 0,
		&"necrotic_corruption": 0,
	}
	for stage in contract.stages:
		var outcome = stage.check.outcome_table.get(tier)
		for effect in outcome.campaign_effects:
			if effect.type == &"modify_clock":
				totals[effect.target_id] += effect.amount
	var parts := PackedStringArray()
	for clock_id: StringName in [
		&"villagers_evacuated",
		&"settlement_destruction",
		&"dragon_exhaustion",
		&"capture_preparation",
		&"necrotic_corruption",
	]:
		var amount: int = totals[clock_id]
		if amount != 0:
			parts.append("%s%+d" % [CLOCK_SHORT[clock_id], amount])
	return ",".join(parts)


func _effect_signature(effects: Array) -> String:
	var totals := {
		&"villagers_evacuated": 0,
		&"settlement_destruction": 0,
		&"dragon_exhaustion": 0,
		&"capture_preparation": 0,
		&"necrotic_corruption": 0,
	}
	for effect in effects:
		if effect.type == &"modify_clock":
			totals[effect.target_id] += effect.amount
	var parts := PackedStringArray()
	for clock_id: StringName in [
		&"villagers_evacuated",
		&"settlement_destruction",
		&"dragon_exhaustion",
		&"capture_preparation",
		&"necrotic_corruption",
	]:
		var amount: int = totals[clock_id]
		if amount != 0:
			parts.append("%s%+d" % [CLOCK_SHORT[clock_id], amount])
	return ",".join(parts)


func _resource_by_id(resources: Array, id: StringName):
	for resource in resources:
		if resource.id == id:
			return resource
	return null


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else message}
