class_name ContractOfferFixtures
extends RefCounted

const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)
const ContractOfferState = preload(
	"res://game/domain/contracts/contract_offer_state.gd"
)
const ContractPlanningDefinitions = preload(
	"res://game/domain/contracts/contract_planning_definitions.gd"
)
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const SupplyDefinition = preload(
	"res://game/domain/contracts/supply_definition.gd"
)
const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const MethodTagDefinition = preload(
	"res://game/domain/contracts/method_tag_definition.gd"
)
const CreateContractOfferRequest = preload(
	"res://game/domain/contracts/create_contract_offer_request.gd"
)
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)

const CONTRACT_ID: StringName = &"contract_north_road_evacuation"


static func create_request(
	state: CampaignState,
	relation: int = 0,
	rules: Array[ContractDefinition.OfferInstantiationRule] = [],
	existing_offers: Array[ContractOfferState] = []
) -> CreateContractOfferRequest:
	var catalog = CatalogContentFixtures.create_catalog()
	var definition: ContractDefinition = catalog.get_contract(CONTRACT_ID)
	definition.instantiation_rules.clear()
	for rule: ContractDefinition.OfferInstantiationRule in rules:
		definition.instantiation_rules.append(rule.duplicate_value())
	var reasons: Array[ReasonEntry] = [
		ReasonEntry.create(
			&"agenda_contract_selected",
			&"contract_offer",
			definition.sponsor_faction_id,
			definition.id,
			0.0,
			&"reason.agenda_contract_selected",
			{},
			&"planning",
			ReasonEntry.VISIBILITY_PLAYER
		),
	]
	return CreateContractOfferRequest.create(
		definition,
		state.week_index,
		ContractOfferState.ORIGIN_AGENDA,
		&"",
		relation,
		state.campaign_seed,
		state.situation,
		state.world_events,
		null,
		reasons,
		existing_offers
	)


static func create_planning_definitions() -> ContractPlanningDefinitions:
	var catalog = CatalogContentFixtures.create_catalog()
	var definition: ContractDefinition = catalog.get_contract(CONTRACT_ID)
	var contract_definitions: Dictionary[StringName, ContractDefinition] = {
		definition.id: definition,
	}
	var adventurers: Dictionary[StringName, AdventurerDefinition] = {}
	for item in catalog.get_all_adventurers():
		adventurers[item.id] = item
	# CampaignStateFixtures intentionally uses the Task004 deterministic resolver
	# team, so provide matching detached definitions in addition to catalog heroes.
	for snapshot in CatalogContentFixtures.create_baseline_team():
		adventurers[snapshot.id] = AdventurerDefinition.create(
			snapshot.id,
			String(snapshot.id),
			snapshot.class_id,
			snapshot.capabilities,
			snapshot.values,
			snapshot.traits,
			[],
			snapshot.wage
		)
	var supplies: Dictionary[StringName, SupplyDefinition] = {}
	for item in catalog.get_all_supplies():
		supplies[item.id] = item
	var clauses: Array[ContractClauseDefinition] = []
	for clause_id: StringName in definition.clause_ids:
		clauses.append(catalog.get_contract_clause(clause_id))
	var method_tags: Array[MethodTagDefinition] = catalog.get_all_method_tags()
	return ContractPlanningDefinitions.create(
		contract_definitions,
		adventurers,
		supplies,
		clauses,
		method_tags
	)


static func rule(
	id: StringName,
	check_id: StringName,
	difficulty_delta: int,
	context_key: StringName,
	context_delta: int
) -> ContractDefinition.OfferInstantiationRule:
	var conditions: Array[ContractDefinition.OfferBindingCondition] = [
		ContractDefinition.OfferBindingCondition.new(
			&"origin_type_is",
			&"",
			0,
			ContractOfferState.ORIGIN_AGENDA
		),
	]
	var effects: Array[ContractDefinition.OfferInstantiationEffect] = []
	if difficulty_delta != 0:
		effects.append(ContractDefinition.OfferInstantiationEffect.new(
			&"add_check_difficulty",
			check_id,
			difficulty_delta
		))
	if context_delta != 0:
		effects.append(ContractDefinition.OfferInstantiationEffect.new(
			&"add_initial_context",
			context_key,
			context_delta
		))
	return ContractDefinition.OfferInstantiationRule.new(
		id,
		conditions,
		effects,
		id
	)
