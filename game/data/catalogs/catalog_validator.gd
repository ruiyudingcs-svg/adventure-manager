## Deterministic Gate C validator for the currently loaded authoring graph.
class_name CatalogValidator
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const ValidationIssue = preload("res://game/data/catalogs/validation_issue.gd")
const ContentManifest = preload("res://game/data/catalogs/content_manifest.gd")
const ContractStageDefinition = preload(
	"res://game/domain/contracts/contract_stage_definition.gd"
)
const ContractCheckDefinition = preload(
	"res://game/domain/contracts/contract_check_definition.gd"
)
const CheckOutcomeTable = preload("res://game/domain/contracts/check_outcome_table.gd")
const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const TraceCondition = preload("res://game/domain/contracts/trace_condition.gd")
const ContractEffect = preload("res://game/domain/contracts/contract_effect.gd")
const MissionModifier = preload("res://game/domain/contracts/mission_modifier.gd")
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const ContractPlanValidator = preload(
	"res://game/domain/simulation/contract_plan_validator.gd"
)

const TRAIT_IDS: Array[StringName] = [
	&"cautious",
	&"ambitious",
	&"compassionate",
	&"ruthless",
	&"loyal",
	&"independent",
	&"scholarly",
	&"devout",
]
const SUPPLY_TAGS: Array[StringName] = [
	&"scouting",
	&"medical",
	&"protection",
	&"arcane_binding",
	&"rations",
]
const REPEAT_POLICIES: Array[StringName] = [&"repeatable", &"once_per_campaign"]
const UNHANDLED_POLICIES: Array[StringName] = [
	&"expire",
	&"npc_or_expire",
	&"npc_or_escalate",
	&"escalate",
]
const WORLD_CONDITION_TYPES: Array[StringName] = [
	&"clock_gte",
	&"clock_lte",
	&"phase_is",
	&"week_gte",
	&"contract_completed",
	&"problem_is_active",
	&"problem_is_resolved",
	&"world_event_occurred",
	&"world_event_not_occurred",
]
const WORLD_EFFECT_TYPES: Array[StringName] = [
	&"change_phase",
	&"modify_clock",
	&"unlock_contract",
	&"add_message",
	&"set_ending",
	&"create_problem",
	&"resolve_problem",
	&"create_world_event",
]
const FACTION_ACTION_EFFECT_TYPES: Array[StringName] = [
	&"change_phase",
	&"modify_clock",
	&"unlock_contract",
	&"set_ending",
]
const OFFER_CONDITION_TYPES: Array[StringName] = [
	&"clock_gte",
	&"clock_lte",
	&"phase_is",
	&"problem_urgency_gte",
	&"problem_urgency_lte",
	&"problem_age_gte",
	&"problem_remaining_turns_lte",
	&"problem_is_active",
	&"world_event_occurred",
	&"origin_type_is",
]
const OFFER_ORIGIN_TYPES: Array[StringName] = [&"problem", &"followup", &"agenda"]
const MEMBER_EFFECT_TYPES: Array[StringName] = [&"injury_risk", &"fatigue"]
const VISIBILITIES: Array[StringName] = [&"player", &"debug"]
const WEIGHT_EPSILON: float = 0.0001
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
const V0_1_PUBLICATION_COUNTS := {
	"adventurer_definitions": 8,
	"trait_definitions": 8,
	"method_tag_definitions": 19,
	"supply_definitions": 5,
	"contract_clause_definitions": 37,
	"faction_definitions": 3,
	"faction_action_definitions": 14,
	"contract_definitions": 12,
	"situation_definitions": 1,
	"clock_definitions": 5,
	"phase_definitions": 4,
	"problem_definitions": 9,
	"ending_definitions": 4,
	"campaign_setup_definitions": 1,
}
const V0_1_CONTRACT_IDS: Array[StringName] = [
	&"contract_north_road_evacuation",
	&"contract_hold_stone_bridge",
	&"contract_escort_field_healers",
	&"contract_rescue_mining_village",
	&"contract_scout_eastern_road",
	&"contract_locate_dragon_lair",
	&"contract_investigate_necrotic_source",
	&"contract_collect_dragon_scales",
	&"contract_deploy_binding_towers",
	&"contract_disrupt_necrotic_ritual",
	&"contract_recover_intact_corpses",
	&"contract_prepare_dragon_bait",
]
const V0_1_PROBLEM_CONTRACTS := {
	&"problem_eastern_road_blocked": [&"contract_scout_eastern_road"],
	&"problem_evacuating_civilians": [
		&"contract_north_road_evacuation",
		&"contract_hold_stone_bridge",
	],
	&"problem_field_medical_collapse": [&"contract_escort_field_healers"],
	&"problem_mining_village_isolated": [&"contract_rescue_mining_village"],
	&"problem_dragon_location_unknown": [&"contract_locate_dragon_lair"],
	&"problem_dragon_capture_window": [
		&"contract_collect_dragon_scales",
		&"contract_deploy_binding_towers",
	],
	&"problem_necrotic_spread": [
		&"contract_investigate_necrotic_source",
		&"contract_disrupt_necrotic_ritual",
	],
	&"problem_battlefield_corpses": [&"contract_recover_intact_corpses"],
	&"problem_dragon_assault_pressure": [&"contract_prepare_dragon_bait"],
}
const V0_1_ACTION_OWNERS := {
	&"faction_free_adventurers": [
		&"action_free_alliance_evacuate_north_road",
		&"action_free_alliance_reinforce_stone_bridge",
		&"action_free_alliance_stabilize_field_camp",
		&"action_free_alliance_search_mining_village",
		&"action_free_alliance_patrol_refugee_route",
	],
	&"faction_arcane_guild": [
		&"action_arcane_guild_locate_dragon_lair",
		&"action_arcane_guild_collect_dragon_scales",
		&"action_arcane_guild_deploy_binding_towers",
		&"action_arcane_guild_ward_necrotic_spread",
		&"action_arcane_guild_analyze_flight_pattern",
	],
	&"faction_necrotic_collective": [
		&"action_necrotic_collective_recover_corpses",
		&"action_necrotic_collective_prepare_dragon_bait",
		&"action_necrotic_collective_secure_source",
		&"action_necrotic_collective_seed_resonance",
	],
}


## Validates one explicit manifest without mutating or compiling its source graph.
func validate(
	manifest: ContentManifest,
	manifest_path: String = "memory://content_manifest"
) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	if manifest == null:
		_add(
			issues,
			&"missing_manifest",
			manifest_path,
			"",
			"ContentManifest is required."
		)
		return issues

	var indexes: Dictionary = _build_indexes(manifest, manifest_path, issues)
	_validate_adventurers(manifest, manifest_path, indexes, issues)
	_validate_traits(manifest, manifest_path, issues)
	_validate_method_tags(manifest, manifest_path, issues)
	_validate_supplies(manifest, manifest_path, issues)
	_validate_clauses(manifest, manifest_path, indexes, issues)
	_validate_factions(manifest, manifest_path, issues)
	_validate_faction_actions(manifest, manifest_path, indexes, issues)
	_validate_contracts(manifest, manifest_path, indexes, issues)
	_validate_contract_cycles(manifest, manifest_path, indexes, issues)
	_validate_clocks(manifest, manifest_path, issues)
	_validate_phases(manifest, manifest_path, issues)
	_validate_problems(manifest, manifest_path, indexes, issues)
	_validate_endings(manifest, manifest_path, indexes, issues)
	_validate_situations(manifest, manifest_path, indexes, issues)
	_validate_campaign_setups(manifest, manifest_path, indexes, issues)
	if indexes["situation_definitions"].has(&"situation_dragon_invasion_v0_1"):
		_validate_v0_1_publication(manifest, manifest_path, indexes, issues)
	if issues.is_empty():
		_validate_compilation(manifest, manifest_path, issues)
	return issues


## Locks the accepted Task013 manifest as one closed, deterministic publication.
func _validate_v0_1_publication(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for category: String in CATEGORY_ORDER:
		var actual: int = manifest.get(category).size()
		var expected: int = V0_1_PUBLICATION_COUNTS[category]
		if actual != expected:
			_add(
				issues,
				&"invalid_publication_count",
				manifest_path,
				category,
				"Dragon Invasion V0.1 requires exactly %d entries; found %d."
					% [expected, actual]
			)

	var contract_ids := _resource_ids(manifest.contract_definitions)
	if contract_ids != V0_1_CONTRACT_IDS:
		_add(
			issues,
			&"invalid_publication_order",
			manifest_path,
			"contract_definitions",
			"Published contracts must use the accepted stable ID order."
		)

	for faction_id: StringName in V0_1_ACTION_OWNERS:
		var faction = indexes["faction_definitions"].get(faction_id)
		if faction == null:
			continue
		var expected_actions: Array = V0_1_ACTION_OWNERS[faction_id]
		if faction.weekly_action_ids != expected_actions:
			_add(
				issues,
				&"invalid_publication_ownership",
				_resource_path(faction, manifest_path, "faction_definitions"),
				"weekly_action_ids",
				"Faction %s must own its complete accepted action list." % faction_id
			)

	for problem_id: StringName in V0_1_PROBLEM_CONTRACTS:
		var problem = indexes["problem_definitions"].get(problem_id)
		if problem == null:
			continue
		var expected_contracts: Array = V0_1_PROBLEM_CONTRACTS[problem_id]
		if problem.contract_definition_ids != expected_contracts:
			_add(
				issues,
				&"invalid_publication_reference",
				_resource_path(problem, manifest_path, "problem_definitions"),
				"contract_definition_ids",
				"Problem %s must publish its accepted contract whitelist."
					% problem_id
			)

	for fallback_id: StringName in [
		&"contract_scout_eastern_road",
		&"contract_locate_dragon_lair",
		&"contract_recover_intact_corpses",
	]:
		var fallback = indexes["contract_definitions"].get(fallback_id)
		if fallback != null and (
			not fallback.starts_unlocked
			or not fallback.allow_agenda_origin
			or fallback.availability_rules.size() != 1
		):
			_add(
				issues,
				&"invalid_publication_fallback",
				_resource_path(fallback, manifest_path, "contract_definitions"),
				"availability_rules",
				"Fallback contracts must start unlocked with one phase rule and Agenda origin."
			)

	var binding = indexes["contract_definitions"].get(
		&"contract_deploy_binding_towers"
	)
	if binding != null:
		var phase_ids: Array[StringName] = []
		if binding.availability_rules.size() == 1:
			for condition in binding.availability_rules[0].any_conditions:
				if condition != null and condition.type == &"phase_is":
					phase_ids.append(condition.target_id)
		if phase_ids != [&"phase_final_window"]:
			_add(
				issues,
				&"invalid_publication_phase",
				_resource_path(binding, manifest_path, "contract_definitions"),
				"availability_rules",
				"Binding towers must be available only in phase_final_window."
			)

	var expected_endings := {
		&"ending_necrotic_catastrophe": 400,
		&"ending_dragon_slain_at_cost": 300,
		&"ending_arcane_capture": 200,
		&"ending_mass_evacuation": 100,
	}
	for ending_id: StringName in expected_endings:
		var ending = indexes["ending_definitions"].get(ending_id)
		if ending != null and ending.priority != expected_endings[ending_id]:
			_add(
				issues,
				&"invalid_publication_priority",
				_resource_path(ending, manifest_path, "ending_definitions"),
				"priority",
				"Ending %s must use priority %d."
					% [ending_id, expected_endings[ending_id]]
			)

	var setup = indexes["campaign_setup_definitions"].get(
		&"campaign_setup_dragon_invasion_v0_1"
	)
	if setup != null:
		var expected_members: Array[StringName] = [
			&"mara_shield",
			&"toren_hammer",
			&"elin_pathfinder",
			&"veska_hunter",
			&"sister_ana",
			&"orrin_arcanist",
			&"pell_quartermaster",
			&"nera_hedgewitch",
		]
		var expected_problems: Array[StringName] = [
			&"problem_eastern_road_blocked",
			&"problem_dragon_location_unknown",
			&"problem_dragon_assault_pressure",
		]
		var faction_ids: Array[StringName] = []
		var valid_faction_values := true
		for faction_setup in setup.faction_setups:
			if faction_setup == null:
				continue
			faction_ids.append(faction_setup.faction_id)
			valid_faction_values = valid_faction_values \
				and faction_setup.initial_relation == 0 \
				and faction_setup.initial_influence == 60
		if (
			setup.situation_definition_id != &"situation_dragon_invasion_v0_1"
			or setup.adventurer_ids != expected_members
			or setup.initial_active_problem_ids != expected_problems
			or faction_ids != [
				&"faction_free_adventurers",
				&"faction_arcane_guild",
				&"faction_necrotic_collective",
			]
			or not valid_faction_values
			or setup.initial_gold != 250
			or setup.initial_reputation != 20
			or setup.initial_base_cohesion != 50
			or setup.weekly_maintenance != 25
		):
			_add(
				issues,
				&"invalid_publication_setup",
				_resource_path(
					setup,
					manifest_path,
					"campaign_setup_definitions"
				),
				"campaign_setup_definitions",
				"Dragon Invasion setup must match the accepted Gate F baseline."
			)


func _resource_ids(resources: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for resource in resources:
		if resource != null:
			result.append(resource.id)
	return result


func _build_indexes(
	manifest: ContentManifest,
	manifest_path: String,
	issues: Array[ValidationIssue]
) -> Dictionary:
	var indexes: Dictionary = {
		"adventurer_definitions": {},
		"trait_definitions": {},
		"method_tag_definitions": {},
		"supply_definitions": {},
		"contract_clause_definitions": {},
		"faction_definitions": {},
		"faction_action_definitions": {},
		"contract_definitions": {},
		"situation_definitions": {},
		"clock_definitions": {},
		"phase_definitions": {},
		"problem_definitions": {},
		"ending_definitions": {},
		"campaign_setup_definitions": {},
	}
	var global_ids: Dictionary[StringName, String] = {}
	for category: String in CATEGORY_ORDER:
		var resources: Array = manifest.get(category)
		var category_index: Dictionary = indexes[category]
		for index: int in range(resources.size()):
			var resource: Resource = resources[index]
			var field_path := "%s[%d]" % [category, index]
			if resource == null:
				_add(
					issues,
					&"null_resource",
					manifest_path,
					field_path,
					"Manifest entries cannot be null."
				)
				continue
			var resource_id: StringName = resource.get("id")
			var path := _resource_path(resource, manifest_path, field_path)
			if not StableId.is_valid(resource_id):
				_add(
					issues,
					&"invalid_stable_id",
					path,
					"%s.id" % field_path,
					StableId.validation_error(resource_id)
				)
				continue
			if global_ids.has(resource_id):
				_add(
					issues,
					&"duplicate_id",
					path,
					"%s.id" % field_path,
					"ID %s is already declared at %s." % [
						resource_id,
						global_ids[resource_id],
					]
				)
				continue
			global_ids[resource_id] = field_path
			category_index[resource_id] = resource
	return indexes


func _validate_adventurers(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	var trait_index: Dictionary = indexes["trait_definitions"]
	var adventurer_index: Dictionary = indexes["adventurer_definitions"]
	for index: int in range(manifest.adventurer_definitions.size()):
		var resource = manifest.adventurer_definitions[index]
		if resource == null:
			continue
		var root := "adventurer_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if not StableId.is_valid(resource.class_id):
			_add(issues, &"invalid_stable_id", path, root + ".class_id",
				"class_id must be a stable ID.")
		if resource.base_capabilities == null:
			_add(issues, &"null_subresource", path, root + ".base_capabilities",
				"base_capabilities is required.")
		else:
			for field: String in [
				"frontline", "offense", "scouting", "support", "arcana", "discipline"
			]:
				_check_range(
					issues, path, root + ".base_capabilities." + field,
					resource.base_capabilities.get(field), 0, 100
				)
		if resource.values == null:
			_add(issues, &"null_subresource", path, root + ".values",
				"values is required.")
		else:
			_validate_ideology(resource.values, path, root + ".values", 5, issues)
		if resource.wage <= 0:
			_add(issues, &"out_of_range", path, root + ".wage",
				"wage must be greater than zero.")
		var seen_traits: Dictionary[StringName, bool] = {}
		for trait_index_value: int in range(resource.traits.size()):
			var trait_id: StringName = resource.traits[trait_index_value]
			var field := "%s.traits[%d]" % [root, trait_index_value]
			if not TRAIT_IDS.has(trait_id):
				_add(issues, &"invalid_enum", path, field,
					"Trait %s is outside the Gate B whitelist." % trait_id)
			elif not trait_index.has(trait_id):
				_add(issues, &"missing_reference", path, field,
					"Trait %s is not declared in the manifest." % trait_id)
			if seen_traits.has(trait_id):
				_add(issues, &"duplicate_value", path, field,
					"Trait IDs must be unique per adventurer.")
			seen_traits[trait_id] = true
		var relationship_ids: Dictionary[StringName, bool] = {}
		for relationship_index: int in range(resource.starting_relationships.size()):
			var relationship = resource.starting_relationships[relationship_index]
			var field := "%s.starting_relationships[%d]" % [root, relationship_index]
			if relationship == null:
				_add(issues, &"null_subresource", path, field,
					"starting_relationships cannot contain null.")
				continue
			if not StableId.is_valid(relationship.target_id):
				_add(issues, &"invalid_stable_id", path, field + ".target_id",
					"Relationship target_id must be a stable ID.")
			elif not adventurer_index.has(relationship.target_id):
				_add(issues, &"missing_reference", path, field + ".target_id",
					"Relationship target %s is not declared." % relationship.target_id)
			if relationship_ids.has(relationship.target_id):
				_add(issues, &"duplicate_value", path, field + ".target_id",
					"Relationship target IDs must be unique.")
			relationship_ids[relationship.target_id] = true
			_check_range(
				issues, path, field + ".base_value", relationship.base_value, -100, 100
			)


func _validate_traits(
	manifest: ContentManifest,
	manifest_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.trait_definitions.size()):
		var resource = manifest.trait_definitions[index]
		if resource == null:
			continue
		var root := "trait_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if not TRAIT_IDS.has(resource.id):
			_add(issues, &"invalid_enum", path, root + ".id",
				"Trait ID must be one of the eight Gate B traits.")
		_validate_modifier_array(resource.modifiers, path, root + ".modifiers", issues)
		if not resource.modifiers.is_empty():
			_add(issues, &"invalid_gate_b_value", path, root + ".modifiers",
				"Gate B trait method modifiers are fixed by trait ID.")


func _validate_method_tags(
	manifest: ContentManifest,
	manifest_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.method_tag_definitions.size()):
		var resource = manifest.method_tag_definitions[index]
		if resource == null:
			continue
		var root := "method_tag_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if resource.ideology_vector == null:
			_add(issues, &"null_subresource", path, root + ".ideology_vector",
				"ideology_vector is required.")
		else:
			_validate_ideology(
				resource.ideology_vector,
				path,
				root + ".ideology_vector",
				5,
				issues
			)
		var expected: int = 0
		if resource.id == &"necromancy" or resource.id == &"sacrifice":
			expected = 2
		elif [
			&"coercion", &"corpse_handling", &"preservation", &"smuggling"
		].has(resource.id):
			expected = 1
		if resource.taboo_intensity != expected:
			_add(issues, &"invalid_value", path, root + ".taboo_intensity",
				"taboo_intensity for %s must be %d." % [resource.id, expected])


func _validate_supplies(
	manifest: ContentManifest,
	manifest_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.supply_definitions.size()):
		var resource = manifest.supply_definitions[index]
		if resource == null:
			continue
		var root := "supply_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if resource.cost < 0:
			_add(issues, &"out_of_range", path, root + ".cost",
				"Supply cost must be non-negative.")
		if resource.tags.size() != 1 or not SUPPLY_TAGS.has(resource.tags[0]):
			_add(issues, &"invalid_supply_tag", path, root + ".tags",
				"Supply must have exactly one fixed V0.1 tag.")
			continue
		var expected: Array[Dictionary] = _expected_supply_modifiers(resource.tags[0])
		if resource.modifiers.size() != expected.size():
			_add(issues, &"invalid_count", path, root + ".modifiers",
				"Supply has the wrong fixed modifier count.")
		for modifier_index: int in range(resource.modifiers.size()):
			var modifier = resource.modifiers[modifier_index]
			var field := "%s.modifiers[%d]" % [root, modifier_index]
			if modifier == null:
				_add(issues, &"null_subresource", path, field,
					"Supply modifiers cannot contain null.")
				continue
			if modifier_index >= expected.size():
				_add(issues, &"invalid_value", path, field,
					"Unexpected supply modifier.")
				continue
			var fixed: Dictionary = expected[modifier_index]
			if modifier.target_type != fixed["target"] \
				or modifier.match_tag != fixed["match"] \
				or modifier.amount != fixed["amount"]:
				_add(issues, &"invalid_value", path, field,
					"Modifier does not match the fixed V0.1 supply rule.")
			if modifier.reason_code.is_empty():
				_add(issues, &"missing_required", path, field + ".reason_code",
					"Non-zero supply modifiers require a reason_code.")


func _validate_clauses(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	var method_index: Dictionary = indexes["method_tag_definitions"]
	for index: int in range(manifest.contract_clause_definitions.size()):
		var resource = manifest.contract_clause_definitions[index]
		if resource == null:
			continue
		var root := "contract_clause_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if not ContractClauseDefinition.CATEGORIES.has(resource.category):
			_add(issues, &"invalid_enum", path, root + ".category",
				"Unknown clause category %s." % resource.category)
		if not ContractClauseDefinition.IMPORTANCES.has(resource.importance):
			_add(issues, &"invalid_enum", path, root + ".importance",
				"Unknown clause importance %s." % resource.importance)
		if resource.success_ideology_impact == null:
			_add(issues, &"null_subresource", path, root + ".success_ideology_impact",
				"success_ideology_impact is required.")
		else:
			_validate_ideology(
				resource.success_ideology_impact,
				path,
				root + ".success_ideology_impact",
				10,
				issues
			)
		if resource.failure_ideology_impact == null:
			_add(issues, &"null_subresource", path, root + ".failure_ideology_impact",
				"failure_ideology_impact is required.")
		else:
			_validate_ideology(
				resource.failure_ideology_impact,
				path,
				root + ".failure_ideology_impact",
				10,
				issues
			)
		for condition_index: int in range(resource.all_conditions.size()):
			var condition = resource.all_conditions[condition_index]
			var field := "%s.all_conditions[%d]" % [root, condition_index]
			if condition == null:
				_add(issues, &"null_subresource", path, field,
					"Clause conditions cannot contain null.")
				continue
			if not TraceCondition.TYPES.has(condition.type):
				_add(issues, &"invalid_enum", path, field + ".type",
					"Unknown TraceCondition type %s." % condition.type)
			if condition.type == &"method_tag_used" \
				or condition.type == &"method_tag_not_used":
				if not method_index.has(condition.tag_value):
					_add(issues, &"missing_reference", path, field + ".tag_value",
						"Method tag %s is not declared." % condition.tag_value)
			elif condition.type == &"context_gte" or condition.type == &"context_lte":
				if not MissionContext.CONTEXT_KEYS.has(condition.key):
					_add(issues, &"invalid_enum", path, field + ".key",
						"Unknown MissionContext key %s." % condition.key)
				_check_range(issues, path, field + ".int_value",
					condition.int_value, 0, 10)
			elif condition.type == &"check_tier_gte" \
				or condition.type == &"check_tier_lte":
				if not CheckOutcomeTable.TIERS.has(condition.tag_value):
					_add(issues, &"invalid_enum", path, field + ".tag_value",
						"Unknown check tier %s." % condition.tag_value)
			elif condition.type == &"approach_is" \
				and not [&"cautious", &"balanced", &"aggressive"].has(
					condition.tag_value
				):
				_add(issues, &"invalid_enum", path, field + ".tag_value",
					"Unknown approach %s." % condition.tag_value)
		_validate_contract_effects(
			resource.success_effects, path, root + ".success_effects", issues
		)
		_validate_contract_effects(
			resource.failure_effects, path, root + ".failure_effects", issues
		)
		if not resource.breach_result_cap.is_empty() \
			and not CheckOutcomeTable.TIERS.has(resource.breach_result_cap):
			_add(issues, &"invalid_enum", path, root + ".breach_result_cap",
				"Unknown result cap %s." % resource.breach_result_cap)
		if resource.importance == &"bonus" \
			and (not resource.failure_effects.is_empty()
				or not resource.breach_result_cap.is_empty()
				or not resource.failure_tags.is_empty()):
			_add(issues, &"invalid_bonus_clause", path, root,
				"Bonus clauses cannot have failure consequences or a result cap.")


func _validate_factions(
	manifest: ContentManifest,
	manifest_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.faction_definitions.size()):
		var resource = manifest.faction_definitions[index]
		if resource == null:
			continue
		var root := "faction_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if resource.preferred_ideology == null:
			_add(issues, &"null_subresource", path, root + ".preferred_ideology",
				"preferred_ideology is required.")
		else:
			_validate_ideology(
				resource.preferred_ideology,
				path,
				root + ".preferred_ideology",
				5,
				issues
			)
		var tags: Dictionary[StringName, bool] = {}
		for weight_index: int in range(resource.agenda_weights.size()):
			var weight = resource.agenda_weights[weight_index]
			var field := "%s.agenda_weights[%d]" % [root, weight_index]
			if weight == null:
				_add(issues, &"null_subresource", path, field,
					"agenda_weights cannot contain null.")
				continue
			if weight.tag.is_empty():
				_add(issues, &"missing_required", path, field + ".tag",
					"Agenda weight tag is required.")
			if tags.has(weight.tag):
				_add(issues, &"duplicate_value", path, field + ".tag",
					"Agenda tags must be unique within a faction.")
			tags[weight.tag] = true
			_check_range(issues, path, field + ".weight", weight.weight, -10, 10)
		var action_ids: Dictionary[StringName, bool] = {}
		for action_index: int in range(resource.weekly_action_ids.size()):
			var action_id: StringName = resource.weekly_action_ids[action_index]
			var field := "%s.weekly_action_ids[%d]" % [root, action_index]
			if action_ids.has(action_id):
				_add(issues, &"duplicate_value", path, field,
					"weekly_action_ids must be unique within a faction.")
			action_ids[action_id] = true


func _validate_faction_actions(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	var owners: Dictionary[StringName, Array] = {}
	for faction_index: int in range(manifest.faction_definitions.size()):
		var faction = manifest.faction_definitions[faction_index]
		if faction == null:
			continue
		var faction_path := _resource_path(
			faction,
			manifest_path,
			"faction_definitions[%d]" % faction_index
		)
		for action_index: int in range(faction.weekly_action_ids.size()):
			var action_id: StringName = faction.weekly_action_ids[action_index]
			if not indexes["faction_action_definitions"].has(action_id):
				_add(issues, &"missing_reference", faction_path,
					"faction_definitions[%d].weekly_action_ids[%d]" % [
						faction_index, action_index
					],
					"Faction action %s is not declared." % action_id)
			if not owners.has(action_id):
				owners[action_id] = []
			owners[action_id].append(faction.id)

	for action_index: int in range(manifest.faction_action_definitions.size()):
		var resource = manifest.faction_action_definitions[action_index]
		if resource == null:
			continue
		var root := "faction_action_definitions[%d]" % action_index
		var path := _resource_path(resource, manifest_path, root)
		var action_owners: Array = owners.get(resource.id, [])
		if action_owners.size() != 1:
			_add(issues, &"invalid_owner_count", path, root + ".id",
				"Faction action %s must be referenced by exactly one faction."
					% resource.id)
		if not _is_valid_target_lock(resource.target_lock_key):
			_add(issues, &"invalid_stable_id", path, root + ".target_lock_key",
				"target_lock_key must contain one or two stable ID segments.")
		_check_range(issues, path, root + ".base_intent_priority",
			resource.base_intent_priority, 0, 20)
		_check_range(issues, path, root + ".urgency_weight",
			resource.urgency_weight, 0, 40)
		_check_range(issues, path, root + ".recent_repeat_cooldown",
			resource.recent_repeat_cooldown, 0, 20)
		_check_range(issues, path, root + ".influence_cost",
			resource.influence_cost, 0, 100)
		if not StableId.is_valid(resource.event_key):
			_add(issues, &"invalid_stable_id", path, root + ".event_key",
				"Faction action event_key must be a stable ID.")
		var agenda_tags: Dictionary[StringName, bool] = {}
		for tag_index: int in range(resource.agenda_tags.size()):
			var tag: StringName = resource.agenda_tags[tag_index]
			if tag.is_empty() or agenda_tags.has(tag):
				_add(issues, &"invalid_value", path,
					"%s.agenda_tags[%d]" % [root, tag_index],
					"Action agenda tags must be non-empty and unique.")
			agenda_tags[tag] = true
		var problem_tags: Dictionary[StringName, bool] = {}
		for tag_index: int in range(resource.target_problem_tags.size()):
			var tag: StringName = resource.target_problem_tags[tag_index]
			if tag.is_empty() or problem_tags.has(tag):
				_add(issues, &"invalid_value", path,
					"%s.target_problem_tags[%d]" % [root, tag_index],
					"Target problem tags must be non-empty and unique.")
			problem_tags[tag] = true
		if resource.target_problem_tags.is_empty():
			_add(issues, &"missing_required", path, root + ".target_problem_tags",
				"Regular faction actions require at least one target problem tag.")
		_validate_world_conditions(
			resource.conditions,
			path,
			root + ".conditions",
			indexes,
			issues
		)
		_validate_world_effects(
			resource.effects,
			path,
			root + ".effects",
			indexes,
			issues
		)
		for effect_index: int in range(resource.effects.size()):
			var effect = resource.effects[effect_index]
			if effect != null and not FACTION_ACTION_EFFECT_TYPES.has(effect.type):
				_add(issues, &"invalid_action_effect", path,
					"%s.effects[%d].type" % [root, effect_index],
					"Faction actions create exactly one event through event_key and cannot write problem terminal state.")


func _validate_contracts(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.contract_definitions.size()):
		var resource = manifest.contract_definitions[index]
		if resource == null:
			continue
		var root := "contract_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if not indexes["faction_definitions"].has(resource.sponsor_faction_id):
			_add(issues, &"missing_reference", path, root + ".sponsor_faction_id",
				"Sponsor faction %s is not declared." % resource.sponsor_faction_id)
		if not resource.related_problem_id.is_empty() \
			and not indexes["problem_definitions"].has(resource.related_problem_id):
			_add(issues, &"missing_reference", path, root + ".related_problem_id",
				"Problem %s is not declared." % resource.related_problem_id)
		elif not resource.related_problem_id.is_empty():
			var anchored_problem = indexes["problem_definitions"][resource.related_problem_id]
			if not anchored_problem.contract_definition_ids.has(resource.id):
				_add(issues, &"inconsistent_reference", path,
					root + ".related_problem_id",
					"Problem %s must list contract %s." % [
						resource.related_problem_id,
						resource.id,
					])
		if not _is_valid_target_lock(resource.target_lock_key):
			_add(issues, &"invalid_stable_id", path, root + ".target_lock_key",
				"target_lock_key must contain two lower snake_case segments separated by one dot.")
		if not REPEAT_POLICIES.has(resource.repeat_policy):
			_add(issues, &"invalid_enum", path, root + ".repeat_policy",
				"Unknown repeat_policy %s." % resource.repeat_policy)
		if resource.min_reputation < 0:
			_add(issues, &"out_of_range", path, root + ".min_reputation",
				"min_reputation must be non-negative.")
		_validate_id_references(
			resource.prerequisite_contract_ids,
			indexes["contract_definitions"],
			path,
			root + ".prerequisite_contract_ids",
			issues
		)
		_validate_id_references(
			resource.exclusive_contract_ids,
			indexes["contract_definitions"],
			path,
			root + ".exclusive_contract_ids",
			issues
		)
		_check_range(issues, path, root + ".urgency_weight",
			resource.urgency_weight, 0, 40)
		if resource.recent_repeat_cooldown < 0:
			_add(issues, &"out_of_range", path, root + ".recent_repeat_cooldown",
				"recent_repeat_cooldown must be non-negative.")
		if resource.base_reward < 0:
			_add(issues, &"out_of_range", path, root + ".base_reward",
				"base_reward must be non-negative.")
		if resource.base_fatigue < 0:
			_add(issues, &"out_of_range", path, root + ".base_fatigue",
				"base_fatigue must be non-negative.")
		_check_range(issues, path, root + ".risk_level", resource.risk_level, 1, 5)
		if resource.offer_duration_weeks < 1:
			_add(issues, &"out_of_range", path, root + ".offer_duration_weeks",
				"offer_duration_weeks must be at least one.")
		if resource.intent_ideology_vector == null:
			_add(issues, &"null_subresource", path, root + ".intent_ideology_vector",
				"intent_ideology_vector is required.")
		else:
			_validate_ideology(
				resource.intent_ideology_vector,
				path,
				root + ".intent_ideology_vector",
				10,
				issues
			)
		_validate_id_references(
			resource.expected_method_tags,
			indexes["method_tag_definitions"],
			path,
			root + ".expected_method_tags",
			issues
		)
		_validate_id_references(
			resource.clause_ids,
			indexes["contract_clause_definitions"],
			path,
			root + ".clause_ids",
			issues
		)
		for tag_index: int in range(resource.allowed_supply_tags.size()):
			if not SUPPLY_TAGS.has(resource.allowed_supply_tags[tag_index]):
				_add(issues, &"invalid_enum", path,
					"%s.allowed_supply_tags[%d]" % [root, tag_index],
					"Unknown allowed supply tag %s." %
						resource.allowed_supply_tags[tag_index])
		_validate_stages(resource, path, root, indexes, issues)
		_validate_expected_method_coverage(resource, path, root, indexes, issues)
		_validate_contract_outcome_table(
			resource.final_outcome_table,
			path,
			root + ".final_outcome_table",
			indexes,
			issues
		)
		if not UNHANDLED_POLICIES.has(resource.unhandled_policy):
			_add(issues, &"invalid_enum", path, root + ".unhandled_policy",
				"Unknown unhandled_policy %s." % resource.unhandled_policy)
		var needs_action: bool = resource.unhandled_policy == &"npc_or_expire" \
			or resource.unhandled_policy == &"npc_or_escalate"
		if needs_action and resource.npc_completion_action_id.is_empty():
			_add(issues, &"missing_required", path,
				root + ".npc_completion_action_id",
				"NPC unhandled policies require an action ID.")
		elif not needs_action and not resource.npc_completion_action_id.is_empty():
			_add(issues, &"invalid_value", path,
				root + ".npc_completion_action_id",
				"Non-NPC policies cannot carry an action ID.")
		if (resource.unhandled_policy == &"npc_or_escalate"
			or resource.unhandled_policy == &"escalate") \
			and resource.related_problem_id.is_empty():
			_add(issues, &"missing_required", path, root + ".related_problem_id",
				"Escalation policies require a problem anchor.")
		# Task013 owns the formal action Resources. Once any action catalog is
		# present, all NPC references become strict and bidirectional.
		if needs_action and not manifest.faction_action_definitions.is_empty():
			if not indexes["faction_action_definitions"].has(
				resource.npc_completion_action_id
			):
				_add(issues, &"missing_reference", path,
					root + ".npc_completion_action_id",
					"NPC completion action %s is not declared."
						% resource.npc_completion_action_id)
			else:
				var owner_count := 0
				for faction in manifest.faction_definitions:
					if faction != null \
						and faction.weekly_action_ids.has(
							resource.npc_completion_action_id
						):
						owner_count += 1
						if faction.id != resource.sponsor_faction_id:
							_add(issues, &"inconsistent_reference", path,
								root + ".npc_completion_action_id",
								"NPC completion action belongs to another faction.")
				var action = indexes["faction_action_definitions"][
					resource.npc_completion_action_id
				]
				if action.target_lock_key != resource.target_lock_key:
					_add(issues, &"inconsistent_reference", path,
						root + ".npc_completion_action_id",
						"NPC completion action must use the contract target lock.")
				if owner_count != 1:
					_add(issues, &"invalid_owner_count", path,
						root + ".npc_completion_action_id",
						"NPC completion action must have exactly one owner.")
		_validate_world_rules(
			resource.availability_rules,
			path,
			root + ".availability_rules",
			indexes,
			issues
		)
		_validate_instantiation_rules(resource, path, root, indexes, issues)


func _validate_stages(
	resource,
	path: String,
	root: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	if resource.stages.size() != 4:
		_add(issues, &"invalid_count", path, root + ".stages",
			"Contracts must contain exactly four stages.")
	var stage_ids: Dictionary[StringName, bool] = {}
	var check_ids: Dictionary[StringName, bool] = {}
	var result_weight_total: float = 0.0
	for stage_index: int in range(resource.stages.size()):
		var stage = resource.stages[stage_index]
		var stage_path := "%s.stages[%d]" % [root, stage_index]
		if stage == null:
			_add(issues, &"null_subresource", path, stage_path,
				"Contract stages cannot contain null.")
			continue
		if not StableId.is_valid(stage.id):
			_add(issues, &"invalid_stable_id", path, stage_path + ".id",
				"Stage ID must be a stable ID.")
		elif stage_ids.has(stage.id):
			_add(issues, &"duplicate_id", path, stage_path + ".id",
				"Stage IDs must be unique within a contract.")
		stage_ids[stage.id] = true
		if stage_index >= ContractStageDefinition.PHASES.size() \
			or stage.phase != ContractStageDefinition.PHASES[stage_index]:
			_add(issues, &"invalid_stage_order", path, stage_path + ".phase",
				"Stages must use the fixed four-phase order.")
		if stage.check == null:
			_add(issues, &"null_subresource", path, stage_path + ".check",
				"Each stage requires exactly one check.")
			continue
		var check = stage.check
		var check_path := stage_path + ".check"
		if not StableId.is_valid(check.id):
			_add(issues, &"invalid_stable_id", path, check_path + ".id",
				"Check ID must be a stable ID.")
		elif check_ids.has(check.id):
			_add(issues, &"duplicate_id", path, check_path + ".id",
				"Check IDs must be unique within a contract.")
		check_ids[check.id] = true
		if not ContractCheckDefinition.CHECK_TYPES.has(check.check_type):
			_add(issues, &"invalid_enum", path, check_path + ".check_type",
				"Unknown check type %s." % check.check_type)
		if not ContractCheckDefinition.APPROACH_PROFILES.has(check.approach_profile):
			_add(issues, &"invalid_enum", path, check_path + ".approach_profile",
				"Unknown approach profile %s." % check.approach_profile)
		if check.difficulty < 0:
			_add(issues, &"out_of_range", path, check_path + ".difficulty",
				"Base check difficulty must be non-negative.")
		if check.result_weight <= 0.0:
			_add(issues, &"out_of_range", path, check_path + ".result_weight",
				"result_weight must be greater than zero.")
		result_weight_total += check.result_weight
		if not check.failure_result_cap.is_empty() \
			and not CheckOutcomeTable.TIERS.has(check.failure_result_cap):
			_add(issues, &"invalid_enum", path, check_path + ".failure_result_cap",
				"Unknown check result cap %s." % check.failure_result_cap)
		if check.capability_weights == null:
			_add(issues, &"null_subresource", path, check_path + ".capability_weights",
				"capability_weights is required.")
		else:
			var total: float = 0.0
			for field: String in [
				"frontline", "offense", "scouting", "support", "arcana", "discipline"
			]:
				var value: float = check.capability_weights.get(field)
				if value < 0.0:
					_add(issues, &"out_of_range", path,
						check_path + ".capability_weights." + field,
						"Capability weights must be non-negative.")
				total += value
			if absf(total - 1.0) > WEIGHT_EPSILON:
				_add(issues, &"invalid_weight_sum", path,
					check_path + ".capability_weights",
					"Capability weights must sum to 1.0.")
		for tag_index: int in range(check.method_tags.size()):
			var method_id: StringName = check.method_tags[tag_index]
			if not indexes["method_tag_definitions"].has(method_id):
				_add(issues, &"missing_reference", path,
					"%s.method_tags[%d]" % [check_path, tag_index],
					"Method tag %s is not declared." % method_id)
		_validate_mission_modifiers(
			check.context_modifiers,
			path,
			check_path + ".context_modifiers",
			issues
		)
		_validate_check_outcome_table(
			check.outcome_table,
			path,
			check_path + ".outcome_table",
			indexes,
			issues
		)
	if absf(result_weight_total - 1.0) > WEIGHT_EPSILON:
		_add(issues, &"invalid_weight_sum", path, root + ".stages",
			"Four check result weights must sum to 1.0.")


func _validate_expected_method_coverage(
	resource,
	path: String,
	root: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	var required_tags: Array[StringName] = []
	for stage in resource.stages:
		if stage == null or stage.check == null:
			continue
		for method_tag: StringName in stage.check.method_tags:
			if not required_tags.has(method_tag):
				required_tags.append(method_tag)
	for clause_id: StringName in resource.clause_ids:
		var clause = indexes["contract_clause_definitions"].get(clause_id)
		if clause == null:
			continue
		for condition in clause.all_conditions:
			if condition != null \
				and condition.type == &"method_tag_used" \
				and not required_tags.has(condition.tag_value):
				required_tags.append(condition.tag_value)
	for method_tag: StringName in required_tags:
		if not resource.expected_method_tags.has(method_tag):
			_add(issues, &"missing_expected_method", path,
				root + ".expected_method_tags",
				"Expected method tags must include %s." % method_tag)


func _validate_contract_cycles(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	var contract_index: Dictionary = indexes["contract_definitions"]
	for index: int in range(manifest.contract_definitions.size()):
		var resource = manifest.contract_definitions[index]
		if resource == null or not contract_index.has(resource.id):
			continue
		var visiting: Dictionary[StringName, bool] = {}
		if _has_prerequisite_cycle(resource.id, resource.id, contract_index, visiting):
			var root := "contract_definitions[%d]" % index
			var path := _resource_path(resource, manifest_path, root)
			_add(issues, &"cyclic_reference", path,
				root + ".prerequisite_contract_ids",
				"Contract prerequisites must not contain a cycle.")


func _has_prerequisite_cycle(
	start_id: StringName,
	current_id: StringName,
	contract_index: Dictionary,
	visiting: Dictionary[StringName, bool]
) -> bool:
	if visiting.has(current_id):
		return current_id == start_id
	visiting[current_id] = true
	var current = contract_index.get(current_id)
	if current != null:
		for prerequisite_id: StringName in current.prerequisite_contract_ids:
			if contract_index.has(prerequisite_id) \
				and _has_prerequisite_cycle(
					start_id,
					prerequisite_id,
					contract_index,
					visiting
				):
				return true
	visiting.erase(current_id)
	return false


func _validate_check_outcome_table(
	table,
	path: String,
	field_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	if table == null:
		_add(issues, &"null_subresource", path, field_path,
			"CheckOutcomeTable is required.")
		return
	for tier: StringName in CheckOutcomeTable.TIERS:
		var outcome = table.get(String(tier))
		var tier_path := "%s.%s" % [field_path, tier]
		if outcome == null:
			_add(issues, &"missing_tier", path, tier_path,
				"All five check outcomes are required.")
			continue
		if outcome.ideology_impact == null:
			_add(issues, &"null_subresource", path, tier_path + ".ideology_impact",
				"ideology_impact is required.")
		else:
			_validate_ideology(
				outcome.ideology_impact,
				path,
				tier_path + ".ideology_impact",
				10,
				issues
			)
		for delta_index: int in range(outcome.context_deltas.size()):
			var delta = outcome.context_deltas[delta_index]
			var delta_path := "%s.context_deltas[%d]" % [tier_path, delta_index]
			if delta == null:
				_add(issues, &"null_subresource", path, delta_path,
					"context_deltas cannot contain null.")
			elif not MissionContext.CONTEXT_KEYS.has(delta.key):
				_add(issues, &"invalid_enum", path, delta_path + ".key",
					"Unknown MissionContext key %s." % delta.key)
		for effect_index: int in range(outcome.member_effects.size()):
			var effect = outcome.member_effects[effect_index]
			var effect_path := "%s.member_effects[%d]" % [tier_path, effect_index]
			if effect == null:
				_add(issues, &"null_subresource", path, effect_path,
					"member_effects cannot contain null.")
			elif not MEMBER_EFFECT_TYPES.has(effect.type):
				_add(issues, &"invalid_enum", path, effect_path + ".type",
					"Unknown member effect type %s." % effect.type)
			elif effect.reason_code.is_empty():
				_add(issues, &"missing_required", path,
					effect_path + ".reason_code",
					"Member effects require a reason_code.")
		_validate_world_effects(
			outcome.campaign_effects,
			path,
			tier_path + ".campaign_effects",
			indexes,
			issues
		)


func _validate_contract_outcome_table(
	table,
	path: String,
	field_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	if table == null:
		_add(issues, &"null_subresource", path, field_path,
			"ContractOutcomeTable is required.")
		return
	var expected_injury: Dictionary[StringName, int] = {
		&"exceptional": -10,
		&"success": -5,
		&"partial": 0,
		&"failure": 10,
		&"severe": 20,
	}
	for tier: StringName in CheckOutcomeTable.TIERS:
		var outcome = table.get(String(tier))
		var tier_path := "%s.%s" % [field_path, tier]
		if outcome == null:
			_add(issues, &"missing_tier", path, tier_path,
				"All five contract outcomes are required.")
			continue
		if outcome.reward_multiplier < 0.0:
			_add(issues, &"out_of_range", path, tier_path + ".reward_multiplier",
				"reward_multiplier must be non-negative.")
		if outcome.fatigue_multiplier < 0.0:
			_add(issues, &"out_of_range", path, tier_path + ".fatigue_multiplier",
				"fatigue_multiplier must be non-negative.")
		if outcome.injury_risk_modifier != expected_injury[tier]:
			_add(issues, &"invalid_gate_b_value", path,
				tier_path + ".injury_risk_modifier",
				"Gate B fixes %s injury_risk_modifier at %d." % [
					tier,
					expected_injury[tier],
				])
		_check_range(
			issues, path, tier_path + ".sponsor_relation_delta",
			outcome.sponsor_relation_delta, -20, 20
		)
		_validate_world_effects(
			outcome.campaign_effects,
			path,
			tier_path + ".campaign_effects",
			indexes,
			issues
		)


func _validate_clocks(
	manifest: ContentManifest,
	manifest_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.clock_definitions.size()):
		var resource = manifest.clock_definitions[index]
		if resource == null:
			continue
		var root := "clock_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if resource.min_value >= resource.max_value:
			_add(issues, &"invalid_range", path, root + ".min_value",
				"Clock min_value must be less than max_value.")
		if resource.initial_value < resource.min_value \
			or resource.initial_value > resource.max_value:
			_add(issues, &"out_of_range", path, root + ".initial_value",
				"Clock initial_value must be within its bounds.")
		if not VISIBILITIES.has(resource.visibility):
			_add(issues, &"invalid_enum", path, root + ".visibility",
				"Clock visibility must be player or debug.")


func _validate_phases(
	manifest: ContentManifest,
	manifest_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.phase_definitions.size()):
		var resource = manifest.phase_definitions[index]
		if resource == null:
			continue
		var root := "phase_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if resource.sort_order < 0:
			_add(issues, &"out_of_range", path, root + ".sort_order",
				"Phase sort_order must be non-negative.")


func _validate_problems(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.problem_definitions.size()):
		var resource = manifest.problem_definitions[index]
		if resource == null:
			continue
		var root := "problem_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		_check_range(issues, path, root + ".base_urgency",
			resource.base_urgency, 0, 100)
		if resource.age_urgency_per_week < 0:
			_add(issues, &"out_of_range", path, root + ".age_urgency_per_week",
				"age_urgency_per_week must be non-negative.")
		if resource.age_urgency_cap < 0:
			_add(issues, &"out_of_range", path, root + ".age_urgency_cap",
				"age_urgency_cap must be non-negative.")
		if resource.response_window_weeks != -1 \
			and resource.response_window_weeks < 1:
			_add(issues, &"out_of_range", path, root + ".response_window_weeks",
				"response_window_weeks must be -1 or at least one.")
		_validate_id_references(
			resource.related_clock_ids,
			indexes["clock_definitions"],
			path,
			root + ".related_clock_ids",
			issues
		)
		_validate_id_references(
			resource.contract_definition_ids,
			indexes["contract_definitions"],
			path,
			root + ".contract_definition_ids",
			issues
		)
		for contract_index: int in range(resource.contract_definition_ids.size()):
			var contract_id: StringName = resource.contract_definition_ids[contract_index]
			if indexes["contract_definitions"].has(contract_id):
				var contract = indexes["contract_definitions"][contract_id]
				if contract.related_problem_id != resource.id:
					_add(issues, &"inconsistent_reference", path,
						"%s.contract_definition_ids[%d]" % [root, contract_index],
						"Contract %s must point back to problem %s." % [
							contract_id,
							resource.id,
						])
		for rule_index: int in range(resource.urgency_rules.size()):
			var rule = resource.urgency_rules[rule_index]
			var rule_path := "%s.urgency_rules[%d]" % [root, rule_index]
			if rule == null:
				_add(issues, &"null_subresource", path, rule_path,
					"urgency_rules cannot contain null.")
				continue
			if not StableId.is_valid(rule.id):
				_add(issues, &"invalid_stable_id", path, rule_path + ".id",
					"Urgency rule ID must be stable.")
			if rule.urgency_delta != 0 and rule.reason_code.is_empty():
				_add(issues, &"missing_required", path, rule_path + ".reason_code",
					"Non-zero urgency rules require a reason_code.")
			if not VISIBILITIES.has(rule.visibility):
				_add(issues, &"invalid_enum", path, rule_path + ".visibility",
					"Urgency rule visibility must be player or debug.")
			for condition_index: int in range(rule.all_conditions.size()):
				var condition = rule.all_conditions[condition_index]
				var field := "%s.all_conditions[%d]" % [rule_path, condition_index]
				if condition == null:
					_add(issues, &"null_subresource", path, field,
						"Urgency conditions cannot contain null.")
				elif not [&"clock_gte", &"clock_lte", &"phase_is"].has(condition.type):
					_add(issues, &"invalid_enum", path, field + ".type",
						"Urgency rules only support clock and phase predicates.")
				else:
					_validate_world_condition_reference(
						condition, path, field, indexes, issues
					)
		_validate_urgency_rule_intervals(resource, path, root, issues)
		_validate_world_rules(
			resource.activation_rules,
			path,
			root + ".activation_rules",
			indexes,
			issues
		)
		_validate_world_rules(
			resource.resolution_rules,
			path,
			root + ".resolution_rules",
			indexes,
			issues
		)
		_validate_world_effects(
			resource.escalation_effects,
			path,
			root + ".escalation_effects",
			indexes,
			issues
		)
		var creates_escalation_event := false
		for effect in resource.escalation_effects:
			if effect != null and effect.type == &"create_world_event":
				creates_escalation_event = true
				break
		if not creates_escalation_event:
			_add(
				issues,
				&"missing_required",
				path,
				root + ".escalation_effects",
				"Problem escalation must create at least one world event."
			)


func _validate_urgency_rule_intervals(
	resource,
	path: String,
	root: String,
	issues: Array[ValidationIssue]
) -> void:
	var intervals_by_clock: Dictionary[StringName, Array] = {}
	for rule_index: int in range(resource.urgency_rules.size()):
		var rule = resource.urgency_rules[rule_index]
		if rule == null:
			continue
		var bounds_by_clock: Dictionary[StringName, Vector2i] = {}
		for condition in rule.all_conditions:
			if condition == null \
				or (
					condition.type != &"clock_gte"
					and condition.type != &"clock_lte"
				):
				continue
			var bounds: Vector2i = bounds_by_clock.get(
				condition.target_id,
				Vector2i(-2147483648, 2147483647)
			)
			if condition.type == &"clock_gte":
				bounds.x = maxi(bounds.x, condition.int_value)
			else:
				bounds.y = mini(bounds.y, condition.int_value)
			bounds_by_clock[condition.target_id] = bounds
		for clock_id: StringName in bounds_by_clock:
			if not intervals_by_clock.has(clock_id):
				intervals_by_clock[clock_id] = []
			intervals_by_clock[clock_id].append({
				"lower": bounds_by_clock[clock_id].x,
				"upper": bounds_by_clock[clock_id].y,
				"rule_index": rule_index,
				"rule_id": rule.id,
			})

	for clock_id: StringName in intervals_by_clock:
		var intervals: Array = intervals_by_clock[clock_id]
		for left_index: int in range(intervals.size()):
			for right_index: int in range(left_index + 1, intervals.size()):
				var left: Dictionary = intervals[left_index]
				var right: Dictionary = intervals[right_index]
				if maxi(left["lower"], right["lower"]) \
					<= mini(left["upper"], right["upper"]):
					_add(
						issues,
						&"overlapping_range",
						path,
						"%s.urgency_rules[%d].all_conditions"
							% [root, right["rule_index"]],
						"Urgency rules %s and %s overlap for clock %s."
							% [left["rule_id"], right["rule_id"], clock_id]
					)


func _validate_endings(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.ending_definitions.size()):
		var resource = manifest.ending_definitions[index]
		if resource == null:
			continue
		var root := "ending_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		_validate_world_conditions(
			resource.all_conditions,
			path,
			root + ".all_conditions",
			indexes,
			issues
		)
		_validate_world_conditions(
			resource.any_conditions,
			path,
			root + ".any_conditions",
			indexes,
			issues
		)


func _validate_situations(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.situation_definitions.size()):
		var resource = manifest.situation_definitions[index]
		if resource == null:
			continue
		var root := "situation_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		if not indexes["phase_definitions"].has(resource.initial_phase):
			_add(issues, &"missing_reference", path, root + ".initial_phase",
				"Initial phase %s is not declared." % resource.initial_phase)
		_validate_resource_references(
			resource.clock_definitions,
			indexes["clock_definitions"],
			path,
			root + ".clock_definitions",
			issues
		)
		_validate_resource_references(
			resource.phase_definitions,
			indexes["phase_definitions"],
			path,
			root + ".phase_definitions",
			issues
		)
		_validate_resource_references(
			resource.problem_definitions,
			indexes["problem_definitions"],
			path,
			root + ".problem_definitions",
			issues
		)
		_validate_resource_references(
			resource.ending_definitions,
			indexes["ending_definitions"],
			path,
			root + ".ending_definitions",
			issues
		)
		var terminal_count: int = 0
		for phase in resource.phase_definitions:
			if phase != null and phase.is_terminal:
				terminal_count += 1
		if terminal_count != 1:
			_add(issues, &"invalid_terminal_count", path,
				root + ".phase_definitions",
				"A situation must reference exactly one terminal phase.")
		_validate_world_rules(
			resource.trigger_rules,
			path,
			root + ".trigger_rules",
			indexes,
			issues
		)
		for effect_index: int in range(resource.passive_weekly_effects.size()):
			var effect = resource.passive_weekly_effects[effect_index]
			var field := "%s.passive_weekly_effects[%d]" % [root, effect_index]
			if effect == null:
				_add(issues, &"null_subresource", path, field,
					"passive_weekly_effects cannot contain null.")
			else:
				if not indexes["clock_definitions"].has(effect.clock_id):
					_add(issues, &"missing_reference", path, field + ".clock_id",
						"Clock %s is not declared." % effect.clock_id)
				if effect.amount != 0 and effect.reason_code.is_empty():
					_add(issues, &"missing_required", path, field + ".reason_code",
						"Non-zero clock deltas require a reason_code.")


func _validate_campaign_setups(
	manifest: ContentManifest,
	manifest_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(manifest.campaign_setup_definitions.size()):
		var resource = manifest.campaign_setup_definitions[index]
		if resource == null:
			continue
		var root := "campaign_setup_definitions[%d]" % index
		var path := _resource_path(resource, manifest_path, root)
		_validate_id_references(
			resource.adventurer_ids,
			indexes["adventurer_definitions"],
			path,
			root + ".adventurer_ids",
			issues
		)
		_validate_id_references(
			resource.initial_active_problem_ids,
			indexes["problem_definitions"],
			path,
			root + ".initial_active_problem_ids",
			issues
		)
		if not indexes["situation_definitions"].has(
			resource.situation_definition_id
		):
			_add(
				issues,
				&"missing_reference",
				path,
				root + ".situation_definition_id",
				"Situation %s is not declared."
					% resource.situation_definition_id
			)
		else:
			var situation = indexes["situation_definitions"][
				resource.situation_definition_id
			]
			var situation_problem_ids := _resource_ids(
				situation.problem_definitions
			)
			for problem_index: int in range(
				resource.initial_active_problem_ids.size()
			):
				var problem_id: StringName = (
					resource.initial_active_problem_ids[problem_index]
				)
				if not situation_problem_ids.has(problem_id):
					_add(
						issues,
						&"invalid_setup_closure",
						path,
						"%s.initial_active_problem_ids[%d]"
							% [root, problem_index],
						"Opening problem %s is outside the setup Situation."
							% problem_id
					)
		var faction_ids: Array[StringName] = []
		for faction_index: int in range(resource.faction_setups.size()):
			var faction_setup = resource.faction_setups[faction_index]
			var field := "%s.faction_setups[%d]" % [root, faction_index]
			if faction_setup == null:
				_add(
					issues,
					&"null_subresource",
					path,
					field,
					"Campaign faction setup cannot be null."
				)
				continue
			if not indexes["faction_definitions"].has(
				faction_setup.faction_id
			):
				_add(
					issues,
					&"missing_reference",
					path,
					field + ".faction_id",
					"Faction %s is not declared." % faction_setup.faction_id
				)
			if faction_ids.has(faction_setup.faction_id):
				_add(
					issues,
					&"duplicate_value",
					path,
					field + ".faction_id",
					"Campaign setup faction IDs must be unique."
				)
			faction_ids.append(faction_setup.faction_id)
			_check_range(
				issues,
				path,
				field + ".initial_relation",
				faction_setup.initial_relation,
				-100,
				100
			)
			_check_range(
				issues,
				path,
				field + ".initial_influence",
				faction_setup.initial_influence,
				0,
				100
			)
		if resource.initial_gold < 0:
			_add(
				issues,
				&"out_of_range",
				path,
				root + ".initial_gold",
				"Initial gold must be non-negative."
			)
		_check_range(
			issues,
			path,
			root + ".initial_reputation",
			resource.initial_reputation,
			0,
			100
		)
		_check_range(
			issues,
			path,
			root + ".initial_base_cohesion",
			resource.initial_base_cohesion,
			0,
			100
		)
		if resource.weekly_maintenance < 0:
			_add(
				issues,
				&"out_of_range",
				path,
				root + ".weekly_maintenance",
				"Weekly maintenance must be non-negative."
			)


func _validate_instantiation_rules(
	resource,
	path: String,
	root: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	var check_ids: Dictionary[StringName, bool] = {}
	var rule_ids: Dictionary[StringName, bool] = {}
	for stage in resource.stages:
		if stage != null and stage.check != null:
			check_ids[stage.check.id] = true
	for rule_index: int in range(resource.instantiation_rules.size()):
		var rule = resource.instantiation_rules[rule_index]
		var rule_path := "%s.instantiation_rules[%d]" % [root, rule_index]
		if rule == null:
			_add(issues, &"null_subresource", path, rule_path,
				"instantiation_rules cannot contain null.")
			continue
		if not StableId.is_valid(rule.id):
			_add(issues, &"invalid_stable_id", path, rule_path + ".id",
				"Instantiation rule ID must be stable.")
		elif rule_ids.has(rule.id):
			_add(issues, &"duplicate_id", path, rule_path + ".id",
				"Instantiation rule ID %s is duplicated." % rule.id)
		rule_ids[rule.id] = true
		if rule.reason_code.is_empty():
			_add(issues, &"missing_required", path, rule_path + ".reason_code",
				"Instantiation rules require a reason_code.")
		for condition_index: int in range(rule.all_conditions.size()):
			var condition = rule.all_conditions[condition_index]
			var field := "%s.all_conditions[%d]" % [rule_path, condition_index]
			if condition == null:
				_add(issues, &"null_subresource", path, field,
					"Instantiation conditions cannot contain null.")
			elif not OFFER_CONDITION_TYPES.has(condition.type):
				_add(issues, &"invalid_enum", path, field + ".type",
					"Unknown offer binding condition %s." % condition.type)
			elif condition.type == &"clock_gte" or condition.type == &"clock_lte":
				if not indexes["clock_definitions"].has(condition.target_id):
					_add(issues, &"missing_reference", path, field + ".target_id",
						"Clock %s is not declared." % condition.target_id)
			elif condition.type == &"phase_is" \
				and not indexes["phase_definitions"].has(condition.target_id):
				_add(issues, &"missing_reference", path, field + ".target_id",
					"Phase %s is not declared." % condition.target_id)
			elif String(condition.type).begins_with("problem_"):
				if not condition.target_id.is_empty():
					_add(issues, &"invalid_value", path, field + ".target_id",
						"Problem offer conditions must read the related runtime problem.")
				if condition.type == &"problem_urgency_gte" \
					or condition.type == &"problem_urgency_lte":
					_check_range(
						issues, path, field + ".int_value",
						condition.int_value, 0, 100
					)
				elif (condition.type == &"problem_age_gte"
					or condition.type == &"problem_remaining_turns_lte") \
					and condition.int_value < 0:
					_add(issues, &"out_of_range", path, field + ".int_value",
						"Problem age and remaining-turn thresholds must be non-negative.")
			elif condition.type == &"world_event_occurred":
				if not StableId.is_valid(condition.target_id):
					_add(issues, &"invalid_stable_id", path, field + ".target_id",
						"world_event_occurred requires a stable event key.")
			elif condition.type == &"origin_type_is" \
				and not OFFER_ORIGIN_TYPES.has(condition.tag_value):
				_add(issues, &"invalid_enum", path, field + ".tag_value",
					"origin_type_is must use problem, followup, or agenda.")
		for effect_index: int in range(rule.effects.size()):
			var effect = rule.effects[effect_index]
			var field := "%s.effects[%d]" % [rule_path, effect_index]
			if effect == null:
				_add(issues, &"null_subresource", path, field,
					"Instantiation effects cannot contain null.")
			elif effect.type == &"add_check_difficulty":
				if not check_ids.has(effect.target_id):
					_add(issues, &"missing_reference", path, field + ".target_id",
						"Check %s is not declared by this contract." % effect.target_id)
				_check_range(issues, path, field + ".amount", effect.amount, -10, 10)
			elif effect.type == &"add_initial_context":
				if not MissionContext.CONTEXT_KEYS.has(effect.target_id):
					_add(issues, &"invalid_enum", path, field + ".target_id",
						"Unknown MissionContext key %s." % effect.target_id)
				_check_range(issues, path, field + ".amount", effect.amount, -3, 3)
			else:
				_add(issues, &"invalid_enum", path, field + ".type",
					"Unknown instantiation effect %s." % effect.type)


func _validate_world_rules(
	rules: Array,
	path: String,
	field_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(rules.size()):
		var rule = rules[index]
		var root := "%s[%d]" % [field_path, index]
		if rule == null:
			_add(issues, &"null_subresource", path, root,
				"World rules cannot contain null.")
			continue
		if not StableId.is_valid(rule.id):
			_add(issues, &"invalid_stable_id", path, root + ".id",
				"World rule ID must be stable.")
		_validate_world_conditions(
			rule.all_conditions, path, root + ".all_conditions", indexes, issues
		)
		_validate_world_conditions(
			rule.any_conditions, path, root + ".any_conditions", indexes, issues
		)
		_validate_world_effects(
			rule.effects, path, root + ".effects", indexes, issues
		)


func _validate_world_conditions(
	conditions: Array,
	path: String,
	field_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(conditions.size()):
		var condition = conditions[index]
		var root := "%s[%d]" % [field_path, index]
		if condition == null:
			_add(issues, &"null_subresource", path, root,
				"World conditions cannot contain null.")
		elif not WORLD_CONDITION_TYPES.has(condition.type):
			_add(issues, &"invalid_enum", path, root + ".type",
				"Unknown world condition %s." % condition.type)
		else:
			_validate_world_condition_reference(condition, path, root, indexes, issues)


func _validate_world_condition_reference(
	condition,
	path: String,
	field_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	var target_index: Dictionary = {}
	match condition.type:
		&"clock_gte", &"clock_lte":
			target_index = indexes["clock_definitions"]
		&"phase_is":
			target_index = indexes["phase_definitions"]
		&"contract_completed":
			target_index = indexes["contract_definitions"]
		&"problem_is_active", &"problem_is_resolved":
			target_index = indexes["problem_definitions"]
	if not target_index.is_empty() and not target_index.has(condition.target_id):
		_add(issues, &"missing_reference", path, field_path + ".target_id",
			"Referenced ID %s is not declared." % condition.target_id)


func _validate_world_effects(
	effects: Array,
	path: String,
	field_path: String,
	indexes: Dictionary,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(effects.size()):
		var effect = effects[index]
		var root := "%s[%d]" % [field_path, index]
		if effect == null:
			_add(issues, &"null_subresource", path, root,
				"World effects cannot contain null.")
			continue
		if not WORLD_EFFECT_TYPES.has(effect.type):
			_add(issues, &"invalid_enum", path, root + ".type",
				"Unknown world effect %s." % effect.type)
		if effect.reason_code.is_empty():
			_add(issues, &"missing_required", path, root + ".reason_code",
				"World effects require a reason_code.")
		var target_index: Dictionary = {}
		match effect.type:
			&"change_phase":
				target_index = indexes.get("phase_definitions", {})
			&"modify_clock":
				target_index = indexes.get("clock_definitions", {})
			&"unlock_contract":
				target_index = indexes.get("contract_definitions", {})
			&"set_ending":
				target_index = indexes.get("ending_definitions", {})
			&"create_problem", &"resolve_problem":
				target_index = indexes.get("problem_definitions", {})
		if not target_index.is_empty() and not target_index.has(effect.target_id):
			_add(issues, &"missing_reference", path, root + ".target_id",
				"World effect target %s is not declared." % effect.target_id)


func _validate_mission_modifiers(
	modifiers: Array,
	path: String,
	field_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(modifiers.size()):
		var modifier = modifiers[index]
		var root := "%s[%d]" % [field_path, index]
		if modifier == null:
			_add(issues, &"null_subresource", path, root,
				"Mission modifiers cannot contain null.")
			continue
		if not MissionModifier.CONDITION_TYPES.has(modifier.condition_type):
			_add(issues, &"invalid_enum", path, root + ".condition_type",
				"Unknown MissionModifier condition %s." % modifier.condition_type)
		elif modifier.condition_type == &"context_gte" \
			or modifier.condition_type == &"context_lte":
			if not MissionContext.CONTEXT_KEYS.has(modifier.operand):
				_add(issues, &"invalid_enum", path, root + ".operand",
					"Unknown MissionContext key %s." % modifier.operand)
			_check_range(issues, path, root + ".threshold", modifier.threshold, 0, 10)
		elif modifier.condition_type == &"previous_check_tier_gte" \
			or modifier.condition_type == &"previous_check_tier_lte":
			if not CheckOutcomeTable.TIERS.has(modifier.operand):
				_add(issues, &"invalid_enum", path, root + ".operand",
					"Unknown check tier %s." % modifier.operand)
		elif modifier.condition_type == &"approach_is" \
			and not [&"cautious", &"balanced", &"aggressive"].has(modifier.operand):
			_add(issues, &"invalid_enum", path, root + ".operand",
				"Unknown approach %s." % modifier.operand)
		if modifier.maximum_absolute_amount < 0:
			_add(issues, &"out_of_range", path,
				root + ".maximum_absolute_amount",
				"maximum_absolute_amount must be non-negative.")


func _validate_contract_effects(
	effects: Array,
	path: String,
	field_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(effects.size()):
		var effect = effects[index]
		var root := "%s[%d]" % [field_path, index]
		if effect == null:
			_add(issues, &"null_subresource", path, root,
				"Contract effects cannot contain null.")
		elif not ContractEffect.TYPES.has(effect.type):
			_add(issues, &"invalid_enum", path, root + ".type",
				"Unknown ContractEffect type %s." % effect.type)
		elif effect.type == &"add_outcome_tag" and effect.tag_value.is_empty():
			_add(issues, &"missing_required", path, root + ".tag_value",
				"add_outcome_tag requires tag_value.")


func _validate_modifier_array(
	modifiers: Array,
	path: String,
	field_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for index: int in range(modifiers.size()):
		if modifiers[index] == null:
			_add(issues, &"null_subresource", path,
				"%s[%d]" % [field_path, index],
				"Modifier arrays cannot contain null.")


func _validate_ideology(
	vector,
	path: String,
	field_path: String,
	limit: int,
	issues: Array[ValidationIssue]
) -> void:
	for field: String in [
		"protect_life",
		"respect_authority",
		"seek_knowledge",
		"pursue_profit",
		"taboo_tolerance",
	]:
		_check_range(
			issues, path, field_path + "." + field, vector.get(field), -limit, limit
		)


func _validate_id_references(
	ids: Array[StringName],
	index: Dictionary,
	path: String,
	field_path: String,
	issues: Array[ValidationIssue]
) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for value_index: int in range(ids.size()):
		var value: StringName = ids[value_index]
		var root := "%s[%d]" % [field_path, value_index]
		if not index.has(value):
			_add(issues, &"missing_reference", path, root,
				"Referenced ID %s is not declared." % value)
		if seen.has(value):
			_add(issues, &"duplicate_value", path, root,
				"Reference arrays cannot contain duplicates.")
		seen[value] = true


func _validate_resource_references(
	resources: Array,
	index: Dictionary,
	path: String,
	field_path: String,
	issues: Array[ValidationIssue]
) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for resource_index: int in range(resources.size()):
		var resource = resources[resource_index]
		var root := "%s[%d]" % [field_path, resource_index]
		if resource == null:
			_add(issues, &"null_subresource", path, root,
				"Definition references cannot contain null.")
			continue
		if not index.has(resource.id):
			_add(issues, &"missing_reference", path, root + ".id",
				"Definition %s is not declared in the manifest." % resource.id)
		if seen.has(resource.id):
			_add(issues, &"duplicate_value", path, root + ".id",
				"Definition references must be unique.")
		seen[resource.id] = true


func _expected_supply_modifiers(supply_tag: StringName) -> Array[Dictionary]:
	match supply_tag:
		&"scouting":
			return [{"target": &"check", "match": &"navigation", "amount": 5}]
		&"medical":
			return [
				{"target": &"check", "match": &"rescue", "amount": 5},
				{"target": &"injury_any", "match": &"", "amount": -5},
				{"target": &"injury_heavy", "match": &"", "amount": -2},
			]
		&"protection":
			return [
				{"target": &"check", "match": &"protection", "amount": 5},
				{"target": &"injury_any", "match": &"", "amount": -3},
				{"target": &"injury_heavy", "match": &"", "amount": -4},
			]
		&"rations":
			return [{"target": &"fatigue", "match": &"", "amount": -4}]
	return []


func _validate_compilation(
	manifest: ContentManifest,
	manifest_path: String,
	issues: Array[ValidationIssue]
) -> void:
	for category: String in CATEGORY_ORDER:
		var resources: Array = manifest.get(category)
		for index: int in range(resources.size()):
			var resource: Resource = resources[index]
			if resource == null:
				continue
			var field_path := "%s[%d]" % [category, index]
			var path := _resource_path(resource, manifest_path, field_path)
			var first: Variant = resource.call("compile")
			var second: Variant = resource.call("compile")
			if first == null or second == null:
				_add(issues, &"compile_failed", path, field_path,
					"Validated authoring Resource did not compile.")
			elif first == second:
				# Two independent compiles must not publish the same mutable object.
				_add(issues, &"shared_compile_result", path, field_path,
					"Compilation returned a shared mutable runtime object.")


func _check_range(
	issues: Array[ValidationIssue],
	path: String,
	field_path: String,
	value: int,
	minimum: int,
	maximum: int
) -> void:
	if value < minimum or value > maximum:
		_add(issues, &"out_of_range", path, field_path,
			"Value must be between %d and %d." % [minimum, maximum])


func _resource_path(
	resource: Resource,
	manifest_path: String,
	field_path: String
) -> String:
	return resource.resource_path if not resource.resource_path.is_empty() \
		else "%s#%s" % [manifest_path, field_path]


static func _is_valid_target_lock(value: StringName) -> bool:
	var parts: PackedStringArray = String(value).split(".", false)
	if parts.size() == 1:
		return StableId.is_valid(value)
	return parts.size() == 2 \
		and StableId.is_valid(StringName(parts[0])) \
		and StableId.is_valid(StringName(parts[1]))


func _add(
	issues: Array[ValidationIssue],
	code: StringName,
	resource_path: String,
	field_path: String,
	message: String
) -> void:
	issues.append(ValidationIssue.create(code, resource_path, field_path, message))
