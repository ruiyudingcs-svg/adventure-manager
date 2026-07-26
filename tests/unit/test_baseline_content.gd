extends RefCounted

const ContentManifest = preload("res://game/data/catalogs/content_manifest.gd")
const DataCatalogScript = preload("res://game/data/catalogs/data_catalog.gd")
const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)
const BaselineContractFixtures = preload(
	"res://tests/fixtures/baseline_contract_fixtures.gd"
)
const ContractResolver = preload(
	"res://game/domain/simulation/contract_resolver.gd"
)

const MANIFEST_PATH := "res://game/data/catalogs/v0_1_content_manifest.tres"
const REWARD_VARIANT_PATH := \
	"res://game/data/definitions/v0_1/contracts/testing/" + \
	"contract_north_road_reward_variant.tres"


func run(scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_default_manifest_loads(),
		_failed_load_retains_issues_and_blocks_new_game(),
		_content_counts_and_ids(),
		_contracts_are_external_resources(),
		_contract_templates_match_documented_numbers(),
		_reward_variant_changes_resolution(),
		_definition_reads_are_isolated(),
		_shared_projection_path(),
		_autoload_loaded_default_manifest(scene_tree),
	]


func _default_manifest_loads() -> Dictionary:
	var catalog := DataCatalogScript.new()
	var load_result = catalog.load_manifest(MANIFEST_PATH)
	return _result(
		"default manifest validates and loads",
		load_result.is_success() and catalog.is_loaded() \
			and catalog.can_start_new_game() \
			and catalog.get_last_load_issues().is_empty(),
		_issues(load_result.issues)
	)


func _failed_load_retains_issues_and_blocks_new_game() -> Dictionary:
	var catalog := DataCatalogScript.new()
	var valid_result = catalog.load_manifest(MANIFEST_PATH)
	var invalid_manifest := ContentManifest.new()
	invalid_manifest.adventurer_definitions.append(null)
	var invalid_result = catalog.load_content(
		invalid_manifest,
		"memory://task006_invalid_manifest"
	)
	var passed: bool = valid_result.is_success() \
		and not invalid_result.is_success() \
		and catalog.is_loaded() \
		and not catalog.can_start_new_game() \
		and not catalog.get_last_load_issues().is_empty()
	return _result(
		"failed load retains issues and blocks new game",
		passed,
		"An invalid latest load did not retain diagnostics or block start."
	)


func _content_counts_and_ids() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var passed: bool = catalog.get_all_adventurers().size() == 8 \
		and catalog.get_all_traits().size() == 8 \
		and catalog.get_all_method_tags().size() == 19 \
		and catalog.get_all_supplies().size() == 5 \
		and catalog.get_all_factions().size() == 3 \
		and catalog.get_all_faction_actions().size() == 14 \
		and catalog.get_all_contracts().size() == 12 \
		and catalog.get_all_contract_clauses().size() == 37 \
		and catalog.get_all_clocks().size() == 5 \
		and catalog.get_all_phases().size() == 4 \
		and catalog.get_all_problems().size() == 9 \
		and catalog.get_all_endings().size() == 4 \
		and catalog.get_all_situations().size() == 1 \
		and catalog.get_adventurer(&"mara_shield") != null \
		and catalog.get_adventurer(&"nera_hedgewitch") != null \
		and catalog.get_contract(&"contract_north_road_evacuation") != null \
		and catalog.get_contract(&"contract_deploy_binding_towers") != null \
		and catalog.get_contract(&"contract_recover_intact_corpses") != null
	return _result(
		"baseline content counts and stable IDs",
		passed,
		"Counts or required stable IDs differ from Task006."
	)


func _contracts_are_external_resources() -> Dictionary:
	var manifest: ContentManifest = ResourceLoader.load(MANIFEST_PATH) as ContentManifest
	var paths: Array[String] = []
	if manifest != null:
		for contract in manifest.contract_definitions:
			paths.append(contract.resource_path)
	var passed: bool = paths.size() == 12
	for path: String in paths:
		passed = passed and path.ends_with(".tres") \
			and path.begins_with("res://game/data/definitions/v0_1/contracts/")
	return _result(
		"contracts load from explicit .tres resources",
		passed,
		"Contract resource paths were %s." % [paths]
	)


func _contract_templates_match_documented_numbers() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var north = catalog.get_contract(&"contract_north_road_evacuation")
	var binding = catalog.get_contract(&"contract_deploy_binding_towers")
	var corpse = catalog.get_contract(&"contract_recover_intact_corpses")
	var passed: bool = _difficulties(north) == [22, 30, 26, 28] \
		and _weights(north) == [0.15, 0.30, 0.25, 0.30] \
		and north.base_reward == 220 \
		and _difficulties(binding) == [26, 32, 36, 30] \
		and _weights(binding) == [0.15, 0.25, 0.40, 0.20] \
		and binding.base_reward == 300 \
		and _world_event_targets(
			binding.stages[2].check.outcome_table.get_outcome(&"success")
		) == [&"event_binding_towers_operational"] \
		and _world_event_targets(
			binding.stages[2].check.outcome_table.get_outcome(&"severe")
		) == [&"event_dragon_killed"] \
		and _difficulties(corpse) == [28, 32, 34, 33] \
		and _weights(corpse) == [0.15, 0.25, 0.40, 0.20] \
		and corpse.base_reward == 360 \
		and corpse.stages[3].check.failure_result_cap == &"failure" \
		and _world_event_targets(
			corpse.stages[3].check.outcome_table.get_outcome(&"partial")
		) == [&"event_corpses_delivered"]
	return _result(
		"contract templates preserve documented stages",
		passed,
		"Base difficulties, weights, rewards, or extraction cap changed."
	)


func _reward_variant_changes_resolution() -> Dictionary:
	var variant = ResourceLoader.load(REWARD_VARIANT_PATH)
	if variant == null:
		return _result("test .tres changes reward", false, "Variant did not load.")
	var catalog = CatalogContentFixtures.create_catalog()
	var request: Dictionary = BaselineContractFixtures.create_north_request()
	var baseline = ContractResolver.resolve(
		request["contract"], request["plan"], request["seed"],
		request["guild_base_cohesion"]
	)
	var changed_contract = CatalogContentFixtures.project_locked_offer(
		catalog,
		&"contract_north_road_evacuation",
		{
			&"evac_find_safe_route": 20,
			&"evac_secure_column": 21,
			&"evac_recover_stragglers": 31,
			&"evac_move_column_out": 19,
		},
		variant.base_reward
	)
	var changed = ContractResolver.resolve(
		changed_contract, request["plan"], request["seed"],
		request["guild_base_cohesion"]
	)
	var passed: bool = baseline.is_success() and changed.is_success() \
		and variant.base_reward == 230 \
		and changed.resolution.reward == 253 \
		and baseline.resolution.reward == 242 \
		and _scores(changed.resolution) == _scores(baseline.resolution)
	return _result(
		"test .tres changes reward without resolver changes",
		passed,
		"Expected reward 242 -> 253 with identical check scores."
	)


func _definition_reads_are_isolated() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	var first = catalog.get_contract(&"contract_deploy_binding_towers")
	var source_path := ""
	var manifest := ResourceLoader.load(MANIFEST_PATH) as ContentManifest
	for definition in manifest.contract_definitions:
		if definition.id == &"contract_deploy_binding_towers":
			source_path = definition.resource_path
			break
	first.stages[0].check.difficulty = 999
	first.expected_method_tags.append(&"mutated_test_tag")
	var second = catalog.get_contract(&"contract_deploy_binding_towers")
	var source = ResourceLoader.load(source_path)
	var passed: bool = second.stages[0].check.difficulty == 26 \
		and not second.expected_method_tags.has(&"mutated_test_tag") \
		and source.stages[0].check.difficulty == 26 \
		and not source.expected_method_tags.has(&"mutated_test_tag")
	return _result(
		"definition reads cannot mutate catalog or source .tres",
		passed,
		"Detached read mutation leaked into another read or source resource."
	)


func _shared_projection_path() -> Dictionary:
	var requests: Array[Dictionary] = [
		BaselineContractFixtures.create_north_request(),
		BaselineContractFixtures.create_binding_request(),
		BaselineContractFixtures.create_corpse_request(),
	]
	var ids: Array[StringName] = []
	for request: Dictionary in requests:
		ids.append(request["contract"].definition_id)
	var passed: bool = ids == [
		&"contract_north_road_evacuation",
		&"contract_deploy_binding_towers",
		&"contract_recover_intact_corpses",
	]
	return _result(
		"all goldens share catalog projection path",
		passed,
		"Projected definition IDs were %s." % [ids]
	)


func _autoload_loaded_default_manifest(scene_tree: SceneTree) -> Dictionary:
	var autoload: Node = scene_tree.root.get_node_or_null("DataCatalog")
	var setting: String = str(ProjectSettings.get_setting("autoload/DataCatalog", ""))
	var created_for_runner: bool = false
	# A custom SceneTree passed with --script does not instantiate project
	# Autoloads, so exercise the registered script through the real tree lifecycle.
	if autoload == null and setting == "*res://game/data/catalogs/data_catalog.gd":
		autoload = DataCatalogScript.new()
		autoload.name = "DataCatalog"
		scene_tree.root.add_child(autoload)
		created_for_runner = true
	if autoload != null and not autoload.is_loaded():
		autoload.call("load_manifest", DataCatalogScript.DEFAULT_MANIFEST_PATH)
	var passed: bool = autoload != null \
		and autoload.is_loaded() \
		and autoload.can_start_new_game() \
		and autoload.get_last_load_issues().is_empty() \
		and setting == "*res://game/data/catalogs/data_catalog.gd"
	if created_for_runner:
		autoload.queue_free()
	return _result(
		"DataCatalog Autoload loads default manifest headlessly",
		passed,
		"setting=%s node=%s loaded=%s can_start=%s issues=%s" % [
			setting,
			autoload != null,
			autoload != null and autoload.is_loaded(),
			autoload != null and autoload.can_start_new_game(),
			[] if autoload == null else autoload.get_last_load_issues(),
		]
	)


func _difficulties(contract) -> Array[int]:
	var result: Array[int] = []
	for stage in contract.stages:
		result.append(stage.check.difficulty)
	return result


func _weights(contract) -> Array[float]:
	var result: Array[float] = []
	for stage in contract.stages:
		result.append(stage.check.result_weight)
	return result


func _scores(resolution) -> Array[int]:
	var result: Array[int] = []
	for phase_result in resolution.phase_results:
		result.append(phase_result.check_result.score)
	return result


func _world_event_targets(outcome) -> Array[StringName]:
	var result: Array[StringName] = []
	for effect in outcome.campaign_effects:
		if effect.type == &"create_world_event":
			result.append(effect.target_id)
	return result


func _issues(issues: Array) -> String:
	var values: PackedStringArray = []
	for issue in issues:
		values.append("%s:%s:%s" % [
			issue.code, issue.resource_path, issue.field_path,
		])
	return ", ".join(values)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else message}
