extends RefCounted

const CatalogValidator = preload("res://game/data/catalogs/catalog_validator.gd")
const ContentManifest = preload("res://game/data/catalogs/content_manifest.gd")
const ContractEffectResource = preload(
	"res://game/data/definitions/contracts/contract_effect_resource.gd"
)
const OfferBindingConditionResource = preload(
	"res://game/data/definitions/contracts/offer_binding_condition_resource.gd"
)
const OfferInstantiationRuleResource = preload(
	"res://game/data/definitions/contracts/offer_instantiation_rule_resource.gd"
)
const CatalogFixtures = preload("res://tests/fixtures/catalog_fixtures.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var validator := CatalogValidator.new()
	var valid: ContentManifest = CatalogFixtures.create_valid_manifest()
	results.append(_result(
		"valid catalog has no issues",
		validator.validate(valid).is_empty(),
		"Fixture intended to exercise every manifest category was invalid."
	))

	var duplicate: ContentManifest = CatalogFixtures.create_valid_manifest()
	duplicate.trait_definitions[0].id = duplicate.adventurer_definitions[0].id
	var duplicate_issues = validator.validate(duplicate, "memory://duplicate")
	results.append(_result(
		"global duplicate IDs fail across types with an exact field",
		_has_issue(
			duplicate_issues,
			&"duplicate_id",
			"trait_definitions[0].id"
		),
		"Expected a cross-type duplicate_id issue at the trait ID field."
	))

	var broken: ContentManifest = CatalogFixtures.create_valid_manifest()
	broken.adventurer_definitions[0].id = &"Bad-ID"
	broken.contract_definitions[0].stages[1].check = null
	broken.contract_definitions[0].sponsor_faction_id = &"missing_faction"
	var broken_issues = validator.validate(broken, "memory://broken")
	results.append(_result(
		"invalid ID, null child, and missing reference report exact paths",
		_has_issue(broken_issues, &"invalid_stable_id",
			"adventurer_definitions[0].id") \
			and _has_issue(broken_issues, &"null_subresource",
				"contract_definitions[0].stages[1].check") \
			and _has_issue(broken_issues, &"missing_reference",
				"contract_definitions[0].sponsor_faction_id"),
		"One or more structured path diagnostics were missing."
	))

	var boundaries: ContentManifest = CatalogFixtures.create_valid_manifest()
	boundaries.supply_definitions[0].modifiers[0].amount = 4
	boundaries.contract_definitions[0].stages[0].phase = &"main_action"
	boundaries.contract_definitions[0].final_outcome_table.exceptional.injury_risk_modifier = -9
	boundaries.contract_clause_definitions[0].importance = &"bonus"
	var failure_effect := ContractEffectResource.new()
	failure_effect.type = &"modify_reward_percent"
	failure_effect.amount = -10
	boundaries.contract_clause_definitions[0].failure_effects.append(failure_effect)
	var boundary_issues = validator.validate(boundaries, "memory://boundaries")
	results.append(_result(
		"Gate B supply, phase, five-tier, and bonus boundaries reject",
		_has_code(boundary_issues, &"invalid_value") \
			and _has_code(boundary_issues, &"invalid_stage_order") \
			and _has_code(boundary_issues, &"invalid_gate_b_value") \
			and _has_code(boundary_issues, &"invalid_bonus_clause"),
		"Expected fixed Gate B validation issues."
	))

	var first = validator.validate(boundaries, "memory://deterministic")
	var second = validator.validate(boundaries, "memory://deterministic")
	results.append(_result(
		"repeated validation preserves exact issue order",
		_issue_keys(first) == _issue_keys(second),
		"Catalog issue order changed for identical input."
	))
	results.append(_offer_rule_validation_test(validator))
	results.append(_faction_action_validation_test(validator))
	return results


func _offer_rule_validation_test(validator: CatalogValidator) -> Dictionary:
	var manifest: ContentManifest = CatalogFixtures.create_valid_manifest()
	var contract = manifest.contract_definitions[0]
	var invalid_origin := _offer_rule(
		&"offer_rule_duplicate",
		&"origin_type_is",
		&"",
		0,
		&"cancelled"
	)
	var invalid_event := _offer_rule(
		&"offer_rule_duplicate",
		&"world_event_occurred",
		&"Bad-Event",
		0,
		&""
	)
	var invalid_urgency := _offer_rule(
		&"offer_rule_urgency",
		&"problem_urgency_gte",
		&"",
		101,
		&""
	)
	contract.instantiation_rules.append(invalid_origin)
	contract.instantiation_rules.append(invalid_event)
	contract.instantiation_rules.append(invalid_urgency)
	var issues = validator.validate(manifest, "memory://offer_rules")
	var passed: bool = _has_issue(
		issues,
		&"invalid_enum",
		"contract_definitions[0].instantiation_rules[0].all_conditions[0].tag_value"
	) and _has_issue(
		issues,
		&"duplicate_id",
		"contract_definitions[0].instantiation_rules[1].id"
	) and _has_issue(
		issues,
		&"invalid_stable_id",
		"contract_definitions[0].instantiation_rules[1].all_conditions[0].target_id"
	) and _has_issue(
		issues,
		&"out_of_range",
		"contract_definitions[0].instantiation_rules[2].all_conditions[0].int_value"
	)
	return _result(
		"offer rules validate origin event urgency and duplicate IDs",
		passed,
		"Expected structured Task009 instantiation-rule validation issues."
	)


func _faction_action_validation_test(validator: CatalogValidator) -> Dictionary:
	var manifest: ContentManifest = CatalogFixtures.create_valid_manifest()
	manifest.faction_action_definitions[0].event_key = &""
	manifest.faction_action_definitions[0].effects[0].type = &"create_world_event"
	manifest.faction_definitions[0].weekly_action_ids.append(&"action_missing")
	var issues = validator.validate(manifest, "memory://faction_actions")
	return _result(
		"faction actions validate owner event effects and references",
		_has_issue(
			issues,
			&"invalid_stable_id",
			"faction_action_definitions[0].event_key"
		) and _has_issue(
			issues,
			&"invalid_action_effect",
			"faction_action_definitions[0].effects[0].type"
		) and _has_issue(
			issues,
			&"missing_reference",
			"faction_definitions[0].weekly_action_ids[1]"
		),
		"Expected structured action ownership, event, and effect issues."
	)


func _offer_rule(
	id: StringName,
	condition_type: StringName,
	target_id: StringName,
	int_value: int,
	tag_value: StringName
) -> OfferInstantiationRuleResource:
	var condition := OfferBindingConditionResource.new()
	condition.type = condition_type
	condition.target_id = target_id
	condition.int_value = int_value
	condition.tag_value = tag_value
	var rule := OfferInstantiationRuleResource.new()
	rule.id = id
	rule.reason_code = id
	rule.all_conditions.append(condition)
	return rule


func _has_issue(issues: Array, code: StringName, field_path: String) -> bool:
	for issue in issues:
		if issue.code == code and issue.field_path == field_path:
			return true
	return false


func _has_code(issues: Array, code: StringName) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false


func _issue_keys(issues: Array) -> PackedStringArray:
	var keys := PackedStringArray()
	for issue in issues:
		keys.append("%s|%s|%s|%s" % [
			issue.code,
			issue.resource_path,
			issue.field_path,
			issue.message,
		])
	return keys


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": "" if passed else message}
