class_name CampaignBootstrapFixtures
extends RefCounted

const DataCatalog = preload("res://game/data/catalogs/data_catalog.gd")
const CampaignBootstrapper = preload(
	"res://game/domain/simulation/campaign_bootstrapper.gd"
)

const SETUP_ID: StringName = &"campaign_setup_dragon_invasion_v0_1"


static func create_catalog():
	var catalog := DataCatalog.new()
	var result = catalog.load_manifest(DataCatalog.DEFAULT_MANIFEST_PATH)
	assert(result.is_success())
	return catalog


static func create_request(catalog, seed: int = 140014):
	var setup = catalog.get_campaign_setup(SETUP_ID)
	return CampaignBootstrapper.BootstrapRequest.create(
		setup,
		seed,
		catalog.get_all_adventurers(),
		catalog.get_all_factions(),
		catalog.get_all_contracts(),
		catalog.get_all_faction_actions(),
		catalog.get_all_problems(),
		catalog.get_situation(setup.situation_definition_id)
	)


static func bootstrap(catalog = null, seed: int = 140014):
	var source = catalog if catalog != null else create_catalog()
	return CampaignBootstrapper.bootstrap(create_request(source, seed))
