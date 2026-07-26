## Atomically published, read-only-by-copy catalog of runtime definitions.
extends Node

const ContentManifest = preload("res://game/data/catalogs/content_manifest.gd")
const CatalogValidator = preload("res://game/data/catalogs/catalog_validator.gd")
const CatalogLoadResult = preload("res://game/data/catalogs/catalog_load_result.gd")
const ValidationIssue = preload("res://game/data/catalogs/validation_issue.gd")
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const TraitDefinition = preload("res://game/domain/adventurers/trait_definition.gd")
const MethodTagDefinition = preload(
	"res://game/domain/contracts/method_tag_definition.gd"
)
const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")
const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const FactionDefinition = preload("res://game/domain/factions/faction_definition.gd")
const FactionActionDefinition = preload(
	"res://game/domain/factions/faction_action_definition.gd"
)
const ContractDefinition = preload("res://game/domain/contracts/contract_definition.gd")
const SituationDefinition = preload(
	"res://game/domain/situations/situation_definition.gd"
)
const ClockDefinition = preload("res://game/domain/situations/clock_definition.gd")
const SituationPhaseDefinition = preload(
	"res://game/domain/situations/situation_phase_definition.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const EndingDefinition = preload("res://game/domain/situations/ending_definition.gd")
const CampaignSetupDefinition = preload(
	"res://game/domain/campaign/campaign_setup_definition.gd"
)

const CATEGORY_ORDER: Array[String] = [
	"adventurer_definitions",
	"trait_definitions",
	"method_tag_definitions",
	"supply_definitions",
	"contract_clause_definitions",
	"faction_definitions",
	"faction_action_definitions",
	"contract_definitions",
	"situation_definitions",
	"clock_definitions",
	"phase_definitions",
	"problem_definitions",
	"ending_definitions",
	"campaign_setup_definitions",
]
const DEFAULT_MANIFEST_PATH: String = \
	"res://game/data/catalogs/v0_1_content_manifest.tres"

var _loaded: bool = false
var _indexes: Dictionary = {}
var _last_load_issues: Array[ValidationIssue] = []


func _ready() -> void:
	load_manifest(DEFAULT_MANIFEST_PATH)


## Loads an explicitly listed ContentManifest and atomically publishes it on success.
func load_manifest(path: String) -> CatalogLoadResult:
	var loaded_resource: Resource = ResourceLoader.load(path)
	if loaded_resource == null or not loaded_resource is ContentManifest:
		var issues: Array[ValidationIssue] = [ValidationIssue.create(
			&"invalid_manifest",
			path,
			"",
			"Path must load a ContentManifest."
		)]
		return _remember_result(CatalogLoadResult.create(issues))
	return load_content(loaded_resource as ContentManifest, path)


## Validates and loads an in-memory manifest for tests and editor tooling.
func load_content(
	manifest: ContentManifest,
	manifest_path: String = "memory://content_manifest"
) -> CatalogLoadResult:
	var validator := CatalogValidator.new()
	var issues: Array[ValidationIssue] = validator.validate(manifest, manifest_path)
	if not issues.is_empty():
		return _remember_result(CatalogLoadResult.create(issues))

	var temporary_indexes: Dictionary = _empty_indexes()
	for category: String in CATEGORY_ORDER:
		var resources: Array = manifest.get(category)
		var destination: Dictionary = temporary_indexes[category]
		for resource: Resource in resources:
			var compiled: Variant = resource.call("compile")
			if compiled == null:
				issues.append(ValidationIssue.create(
					&"compile_failed",
					resource.resource_path if not resource.resource_path.is_empty()
						else manifest_path,
					category,
					"Validated content failed to compile."
				))
				return _remember_result(CatalogLoadResult.create(issues))
			destination[compiled.id] = compiled

	# Accepted Gate C requires one replacement only after the whole graph succeeds.
	_indexes = temporary_indexes
	_loaded = true
	return _remember_result(CatalogLoadResult.create(issues))


## Reports whether a complete valid catalog has been atomically published.
func is_loaded() -> bool:
	return _loaded


## Blocks new campaigns after the most recent catalog load reported any issue.
func can_start_new_game() -> bool:
	return _loaded and _last_load_issues.is_empty()


## Returns detached diagnostics from the most recent manifest load.
func get_last_load_issues() -> Array[ValidationIssue]:
	var result: Array[ValidationIssue] = []
	for issue: ValidationIssue in _last_load_issues:
		result.append(issue.duplicate_value())
	return result


## Returns a detached adventurer definition, or null for an unknown ID.
func get_adventurer(id: StringName) -> AdventurerDefinition:
	return _duplicate_from(&"adventurer_definitions", id) as AdventurerDefinition


## Returns a detached trait definition, or null for an unknown ID.
func get_trait(id: StringName) -> TraitDefinition:
	return _duplicate_from(&"trait_definitions", id) as TraitDefinition


## Returns a detached method-tag definition, or null for an unknown ID.
func get_method_tag(id: StringName) -> MethodTagDefinition:
	return _duplicate_from(&"method_tag_definitions", id) as MethodTagDefinition


## Returns a detached supply definition, or null for an unknown ID.
func get_supply(id: StringName) -> SupplyDefinition:
	return _duplicate_from(&"supply_definitions", id) as SupplyDefinition


## Returns a detached contract-clause definition, or null for an unknown ID.
func get_contract_clause(id: StringName) -> ContractClauseDefinition:
	return _duplicate_from(&"contract_clause_definitions", id) \
		as ContractClauseDefinition


## Returns a detached faction definition, or null for an unknown ID.
func get_faction(id: StringName) -> FactionDefinition:
	return _duplicate_from(&"faction_definitions", id) as FactionDefinition


## Returns a detached faction action definition, or null for an unknown ID.
func get_faction_action(id: StringName) -> FactionActionDefinition:
	return _duplicate_from(
		&"faction_action_definitions",
		id
	) as FactionActionDefinition


## Returns a detached contract definition, or null for an unknown ID.
func get_contract(id: StringName) -> ContractDefinition:
	return _duplicate_from(&"contract_definitions", id) as ContractDefinition


## Returns a detached situation definition, or null for an unknown ID.
func get_situation(id: StringName) -> SituationDefinition:
	return _duplicate_from(&"situation_definitions", id) as SituationDefinition


## Returns a detached clock definition, or null for an unknown ID.
func get_clock(id: StringName) -> ClockDefinition:
	return _duplicate_from(&"clock_definitions", id) as ClockDefinition


## Returns a detached phase definition, or null for an unknown ID.
func get_phase(id: StringName) -> SituationPhaseDefinition:
	return _duplicate_from(&"phase_definitions", id) as SituationPhaseDefinition


## Returns a detached world-problem definition, or null for an unknown ID.
func get_problem(id: StringName) -> WorldProblemDefinition:
	return _duplicate_from(&"problem_definitions", id) as WorldProblemDefinition


## Returns a detached ending definition, or null for an unknown ID.
func get_ending(id: StringName) -> EndingDefinition:
	return _duplicate_from(&"ending_definitions", id) as EndingDefinition


## Returns a detached campaign setup, or null for an unknown ID.
func get_campaign_setup(id: StringName) -> CampaignSetupDefinition:
	return _duplicate_from(
		&"campaign_setup_definitions",
		id
	) as CampaignSetupDefinition


## Returns detached adventurer definitions in stable ID order.
func get_all_adventurers() -> Array[AdventurerDefinition]:
	var result: Array[AdventurerDefinition] = []
	for value: Variant in _all_from(&"adventurer_definitions"):
		result.append(value as AdventurerDefinition)
	return result


## Returns detached trait definitions in stable ID order.
func get_all_traits() -> Array[TraitDefinition]:
	var result: Array[TraitDefinition] = []
	for value: Variant in _all_from(&"trait_definitions"):
		result.append(value as TraitDefinition)
	return result


## Returns detached method-tag definitions in stable ID order.
func get_all_method_tags() -> Array[MethodTagDefinition]:
	var result: Array[MethodTagDefinition] = []
	for value: Variant in _all_from(&"method_tag_definitions"):
		result.append(value as MethodTagDefinition)
	return result


## Returns detached supply definitions in stable ID order.
func get_all_supplies() -> Array[SupplyDefinition]:
	var result: Array[SupplyDefinition] = []
	for value: Variant in _all_from(&"supply_definitions"):
		result.append(value as SupplyDefinition)
	return result


## Returns detached clause definitions in stable ID order.
func get_all_contract_clauses() -> Array[ContractClauseDefinition]:
	var result: Array[ContractClauseDefinition] = []
	for value: Variant in _all_from(&"contract_clause_definitions"):
		result.append(value as ContractClauseDefinition)
	return result


## Returns detached faction definitions in stable ID order.
func get_all_factions() -> Array[FactionDefinition]:
	var result: Array[FactionDefinition] = []
	for value: Variant in _all_from(&"faction_definitions"):
		result.append(value as FactionDefinition)
	return result


## Returns detached faction action definitions in stable ID order.
func get_all_faction_actions() -> Array[FactionActionDefinition]:
	var result: Array[FactionActionDefinition] = []
	for value: Variant in _all_from(&"faction_action_definitions"):
		result.append(value as FactionActionDefinition)
	return result


## Returns detached contract definitions in stable ID order.
func get_all_contracts() -> Array[ContractDefinition]:
	var result: Array[ContractDefinition] = []
	for value: Variant in _all_from(&"contract_definitions"):
		result.append(value as ContractDefinition)
	return result


## Returns detached situation definitions in stable ID order.
func get_all_situations() -> Array[SituationDefinition]:
	var result: Array[SituationDefinition] = []
	for value: Variant in _all_from(&"situation_definitions"):
		result.append(value as SituationDefinition)
	return result


## Returns detached clock definitions in stable ID order.
func get_all_clocks() -> Array[ClockDefinition]:
	var result: Array[ClockDefinition] = []
	for value: Variant in _all_from(&"clock_definitions"):
		result.append(value as ClockDefinition)
	return result


## Returns detached phase definitions in stable ID order.
func get_all_phases() -> Array[SituationPhaseDefinition]:
	var result: Array[SituationPhaseDefinition] = []
	for value: Variant in _all_from(&"phase_definitions"):
		result.append(value as SituationPhaseDefinition)
	return result


## Returns detached problem definitions in stable ID order.
func get_all_problems() -> Array[WorldProblemDefinition]:
	var result: Array[WorldProblemDefinition] = []
	for value: Variant in _all_from(&"problem_definitions"):
		result.append(value as WorldProblemDefinition)
	return result


## Returns detached ending definitions in stable ID order.
func get_all_endings() -> Array[EndingDefinition]:
	var result: Array[EndingDefinition] = []
	for value: Variant in _all_from(&"ending_definitions"):
		result.append(value as EndingDefinition)
	return result


## Returns detached campaign setups in stable ID order.
func get_all_campaign_setups() -> Array[CampaignSetupDefinition]:
	var result: Array[CampaignSetupDefinition] = []
	for value: Variant in _all_from(&"campaign_setup_definitions"):
		result.append(value as CampaignSetupDefinition)
	return result


func _duplicate_from(category: StringName, id: StringName) -> Variant:
	if not _loaded:
		return null
	var index: Dictionary = _indexes.get(String(category), {})
	var definition: Variant = index.get(id)
	return null if definition == null else definition.duplicate_value()


func _all_from(category: StringName) -> Array:
	var result: Array = []
	if not _loaded:
		return result
	var index: Dictionary = _indexes.get(String(category), {})
	var ids: Array[StringName] = []
	for id: StringName in index:
		ids.append(id)
	# Stable ID order is part of the public catalog contract, never manifest order.
	ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	for id: StringName in ids:
		result.append(index[id].duplicate_value())
	return result


func _empty_indexes() -> Dictionary:
	var result: Dictionary = {}
	for category: String in CATEGORY_ORDER:
		result[category] = {}
	return result


func _remember_result(result: CatalogLoadResult) -> CatalogLoadResult:
	_last_load_issues.clear()
	for issue: ValidationIssue in result.issues:
		_last_load_issues.append(issue.duplicate_value())
	return result
