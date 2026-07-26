extends RefCounted

const DataCatalog = preload("res://game/data/catalogs/data_catalog.gd")
const ContentManifest = preload("res://game/data/catalogs/content_manifest.gd")
const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const ContractResolver = preload("res://game/domain/simulation/contract_resolver.gd")
const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const MethodTagDefinition = preload(
	"res://game/domain/contracts/method_tag_definition.gd"
)
const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")
const CatalogFixtures = preload("res://tests/fixtures/catalog_fixtures.gd")
const ContractResolverFixtures = preload(
	"res://tests/fixtures/contract_resolver_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var empty_catalog := DataCatalog.new()
	var first_invalid: ContentManifest = CatalogFixtures.create_valid_manifest()
	first_invalid.adventurer_definitions[0] = null
	results.append(_result(
		"first failed load remains unloaded",
		not empty_catalog.load_content(first_invalid).is_success() \
			and not empty_catalog.is_loaded(),
		"A failed initial load published a partial catalog."
	))
	empty_catalog.free()

	var catalog := DataCatalog.new()
	var source: ContentManifest = CatalogFixtures.create_valid_manifest()
	var load_result = catalog.load_content(source)
	results.append(_result(
		"valid in-memory manifest compiles and queries by ID",
		load_result.is_success() \
			and catalog.is_loaded() \
			and catalog.get_adventurer(&"hero_alpha") != null \
			and catalog.get_contract(&"contract_test") != null \
			and catalog.get_faction_action(&"action_test") != null,
		"Expected a valid explicit manifest to publish."
	))
	var actions = catalog.get_all_faction_actions()
	actions[0].effects[0].amount = 999
	results.append(_result(
		"faction action getters are detached and stable",
		actions.size() == 1 \
			and actions[0].id == &"action_test" \
			and catalog.get_faction_action(&"action_test").effects[0].amount == 3,
		"Expected the explicit action category to compile and query."
	))

	var adventurers = catalog.get_all_adventurers()
	results.append(_result(
		"getters return stable ID order",
		adventurers.size() == 2 \
			and adventurers[0].id == &"hero_alpha" \
			and adventurers[1].id == &"hero_zeta",
		"get_all_adventurers did not sort by stable ID."
	))

	var first_supply = catalog.get_supply(&"supply_scouting")
	first_supply.tags.append(&"mutated")
	var first_contract = catalog.get_contract(&"contract_test")
	first_contract.stages[0].check.difficulty = 999
	var direct_compiled = source.contract_definitions[0].compile()
	direct_compiled.stages[0].check.difficulty = 777
	results.append(_result(
		"compiled and getter copies cannot mutate catalog or authoring source",
		catalog.get_supply(&"supply_scouting").tags == [&"scouting"] \
			and catalog.get_contract(&"contract_test").stages[0].check.difficulty == 20 \
			and source.supply_definitions[0].tags == [&"scouting"] \
			and source.contract_definitions[0].stages[0].check.difficulty == 20,
		"A caller mutation escaped a defensive runtime copy."
	))

	var invalid: ContentManifest = CatalogFixtures.create_valid_manifest()
	invalid.trait_definitions[0].id = &"hero_alpha"
	var failed = catalog.load_content(invalid, "memory://invalid")
	results.append(_result(
		"failed second load preserves the prior catalog",
		not failed.is_success() \
			and catalog.is_loaded() \
			and catalog.get_adventurer(&"hero_alpha") != null \
			and catalog.get_trait(&"cautious") != null,
		"Atomic publication replaced or cleared a valid catalog after failure."
	))

	var contract_definition = catalog.get_contract(&"contract_test")
	var clauses: Array[ContractClauseDefinition] = [
		catalog.get_contract_clause(&"clause_test")
	]
	var method_tags: Array[MethodTagDefinition] = [
		catalog.get_method_tag(&"scouting")
	]
	var effective = EffectiveContract.create_complete(
		&"offer_catalog_test",
		contract_definition.id,
		contract_definition.base_reward,
		contract_definition.base_fatigue,
		contract_definition.risk_level,
		0,
		contract_definition.intent_ideology_vector,
		contract_definition.expected_method_tags,
		contract_definition.allowed_supply_tags,
		contract_definition.stages,
		clauses,
		[],
		contract_definition.final_outcome_table,
		method_tags
	)
	var no_supplies: Array[SupplyDefinition] = []
	var plan := ContractPlan.create(
		ContractResolverFixtures.create_team(),
		no_supplies,
		&"balanced"
	)
	var resolution_result = ContractResolver.resolve(effective, plan, 9001, 50)
	results.append(_result(
		"compiled contract enters the existing resolver",
		resolution_result.is_success() and resolution_result.resolution != null,
		"Catalog runtime definitions were incompatible with ContractResolver: %s"
			% [resolution_result.errors]
	))
	catalog.free()
	return results


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else message}
