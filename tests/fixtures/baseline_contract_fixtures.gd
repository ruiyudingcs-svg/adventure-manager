class_name BaselineContractFixtures
extends RefCounted

const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)
const ContractResolverFixtures = preload(
	"res://tests/fixtures/contract_resolver_fixtures.gd"
)


static func create_north_request() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	return _request(
		CatalogContentFixtures.project_locked_offer(
			catalog,
			&"contract_north_road_evacuation",
			{
				&"evac_find_safe_route": 20,
				&"evac_secure_column": 21,
				&"evac_recover_stragglers": 31,
				&"evac_move_column_out": 19,
			}
		),
		CatalogContentFixtures.create_plan(
			catalog,
			[&"supply_medical", &"supply_protection"]
		)
	)


static func create_binding_request() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	return _request(
		CatalogContentFixtures.project_locked_offer(
			catalog,
			&"contract_deploy_binding_towers",
			{
				&"binding_survey_leyline": -1,
				&"binding_secure_sites": 11,
				&"binding_raise_towers": 9,
				&"binding_withdraw_team": 23,
			}
		),
		CatalogContentFixtures.create_plan(
			catalog,
			[&"supply_arcane_binding"]
		)
	)


static func create_corpse_request() -> Dictionary:
	var catalog = CatalogContentFixtures.create_catalog()
	return _request(
		CatalogContentFixtures.project_locked_offer(
			catalog,
			&"contract_recover_intact_corpses",
			{
				&"corpse_avoid_patrols": 5,
				&"corpse_secure_battlefield": 17,
				&"corpse_preserve_remains": -10,
				&"corpse_smuggle_cargo": 29,
			}
		),
		CatalogContentFixtures.create_plan(catalog, [])
	)


static func _request(contract, plan) -> Dictionary:
	return {
		"contract": contract,
		"plan": plan,
		"seed": ContractResolverFixtures.BASELINE_SEED,
		"guild_base_cohesion": ContractResolverFixtures.BASELINE_GUILD_COHESION,
	}
