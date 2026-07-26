extends RefCounted

const ContentManifest = preload("res://game/data/catalogs/content_manifest.gd")
const CatalogValidator = preload("res://game/data/catalogs/catalog_validator.gd")
const DataCatalog = preload("res://game/data/catalogs/data_catalog.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_published_setup(),
		_test_detached_setup(),
		_test_invalid_setup_rejected(),
	]


func _test_published_setup() -> Dictionary:
	var catalog := DataCatalog.new()
	var load_result = catalog.load_manifest(DataCatalog.DEFAULT_MANIFEST_PATH)
	var setups = catalog.get_all_campaign_setups()
	var setup = setups[0] if setups.size() == 1 else null
	var passed: bool = load_result.is_success() \
		and setup != null \
		and setup.id == &"campaign_setup_dragon_invasion_v0_1" \
		and setup.adventurer_ids.size() == 8 \
		and setup.faction_setups.size() == 3 \
		and setup.initial_active_problem_ids == [
			&"problem_eastern_road_blocked",
			&"problem_dragon_location_unknown",
			&"problem_dragon_assault_pressure",
		] \
		and setup.initial_gold == 250 \
		and setup.initial_reputation == 20 \
		and setup.initial_base_cohesion == 50 \
		and setup.weekly_maintenance == 25
	return _result(
		"formal manifest publishes the exact Gate F setup",
		passed,
		"Setup publication or one accepted baseline value was missing."
	)


func _test_detached_setup() -> Dictionary:
	var catalog := DataCatalog.new()
	catalog.load_manifest(DataCatalog.DEFAULT_MANIFEST_PATH)
	var first = catalog.get_campaign_setup(
		&"campaign_setup_dragon_invasion_v0_1"
	)
	first.adventurer_ids.clear()
	first.faction_setups[0].initial_influence = 1
	var second = catalog.get_campaign_setup(
		&"campaign_setup_dragon_invasion_v0_1"
	)
	return _result(
		"campaign setup getters return detached values",
		second.adventurer_ids.size() == 8 \
			and second.faction_setups[0].initial_influence == 60,
		"Mutating a caller copy changed the published setup."
	)


func _test_invalid_setup_rejected() -> Dictionary:
	var loaded: Resource = ResourceLoader.load(
		DataCatalog.DEFAULT_MANIFEST_PATH
	)
	var manifest: ContentManifest = loaded.duplicate(true)
	var setup = manifest.campaign_setup_definitions[0]
	setup.adventurer_ids.append(setup.adventurer_ids[0])
	setup.initial_gold = -1
	setup.faction_setups[0].faction_id = &"missing_faction"
	var issues = CatalogValidator.new().validate(
		manifest,
		"memory://invalid_setup"
	)
	var codes: Array[StringName] = []
	for issue in issues:
		codes.append(issue.code)
	return _result(
		"missing references duplicate members and illegal values block setup",
		codes.has(&"duplicate_value") \
			and codes.has(&"missing_reference") \
			and codes.has(&"out_of_range"),
		"One or more invalid setup mutations passed CatalogValidator."
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
