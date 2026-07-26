class_name CatalogContentFixtures
extends RefCounted

const DataCatalog = preload("res://game/data/catalogs/data_catalog.gd")
const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const ContractResolverFixtures = preload(
	"res://tests/fixtures/contract_resolver_fixtures.gd"
)
const CapabilityBlock = preload(
	"res://game/domain/adventurers/capability_block.gd"
)
const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const MethodTagDefinition = preload(
	"res://game/domain/contracts/method_tag_definition.gd"
)
const SupplyDefinition = preload(
	"res://game/domain/contracts/supply_definition.gd"
)


## Loads the same fixed manifest used by the DataCatalog Autoload.
static func create_catalog() -> DataCatalog:
	var catalog := DataCatalog.new()
	var result = catalog.load_manifest(DataCatalog.DEFAULT_MANIFEST_PATH)
	assert(result.is_success(), "Task006 fixture requires a valid default manifest.")
	return catalog


## Projects template data into the temporary locked Offer shape owned by Task009.
## The projection supplies snapshot fields only; stages, clauses and outcomes stay
## sourced from the catalog's detached ContractDefinition graph.
static func project_locked_offer(
	catalog: DataCatalog,
	contract_id: StringName,
	difficulty_deltas: Dictionary,
	offered_reward_override: int = -1
) -> EffectiveContract:
	var definition = catalog.get_contract(contract_id)
	assert(definition != null, "Unknown baseline contract %s." % contract_id)
	for stage in definition.stages:
		stage.check.difficulty += int(difficulty_deltas.get(stage.check.id, 0))

	var clauses: Array[ContractClauseDefinition] = []
	for clause_id: StringName in definition.clause_ids:
		var clause: ContractClauseDefinition = catalog.get_contract_clause(clause_id)
		assert(clause != null, "Missing baseline clause %s." % clause_id)
		clauses.append(clause)

	var method_tags: Array[MethodTagDefinition] = []
	for method_tag: MethodTagDefinition in catalog.get_all_method_tags():
		method_tags.append(method_tag)

	var initial_context_deltas: Array[Dictionary] = []
	var offered_reward: int = (
		definition.base_reward
		if offered_reward_override < 0
		else offered_reward_override
	)
	return EffectiveContract.create_complete(
		StringName("offer_%s_fixture" % contract_id),
		definition.id,
		offered_reward,
		definition.base_fatigue,
		definition.risk_level,
		0,
		definition.intent_ideology_vector,
		definition.expected_method_tags,
		definition.allowed_supply_tags,
		definition.stages,
		clauses,
		initial_context_deltas,
		definition.final_outcome_table,
		method_tags
	)


## Creates the single four-member team shared by all three documented goldens.
static func create_baseline_team() -> Array:
	return ContractResolverFixtures.create_team(
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		{},
		CapabilityBlock.create(100, 100, 100, 100, 100, 100)
	)


static func create_plan(
	catalog: DataCatalog,
	supply_ids: Array[StringName]
) -> ContractPlan:
	var supplies: Array[SupplyDefinition] = []
	for supply_id: StringName in supply_ids:
		var supply: SupplyDefinition = catalog.get_supply(supply_id)
		assert(supply != null, "Missing baseline supply %s." % supply_id)
		supplies.append(supply)
	return ContractPlan.create(create_baseline_team(), supplies, &"balanced")
