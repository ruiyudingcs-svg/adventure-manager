class_name ContractPlanningDefinitions
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")
const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const MethodTagDefinition = preload(
	"res://game/domain/contracts/method_tag_definition.gd"
)
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)

var contract_definitions: Dictionary[StringName, ContractDefinition] = {}
var adventurer_definitions: Dictionary[StringName, AdventurerDefinition] = {}
var supply_definitions: Dictionary[StringName, SupplyDefinition] = {}
var clauses: Array[ContractClauseDefinition]
var method_tag_definitions: Array[MethodTagDefinition]


static func create(
	p_contract_definitions: Dictionary[StringName, ContractDefinition],
	p_adventurer_definitions: Dictionary[StringName, AdventurerDefinition],
	p_supply_definitions: Dictionary[StringName, SupplyDefinition],
	p_clauses: Array[ContractClauseDefinition],
	p_method_tag_definitions: Array[MethodTagDefinition]
) -> ContractPlanningDefinitions:
	var definitions := ContractPlanningDefinitions.new(
		p_contract_definitions,
		p_adventurer_definitions,
		p_supply_definitions,
		p_clauses,
		p_method_tag_definitions
	)
	if not definitions.validate().is_empty():
		return null
	return definitions


func _init(
	p_contract_definitions: Dictionary[StringName, ContractDefinition],
	p_adventurer_definitions: Dictionary[StringName, AdventurerDefinition],
	p_supply_definitions: Dictionary[StringName, SupplyDefinition],
	p_clauses: Array[ContractClauseDefinition],
	p_method_tag_definitions: Array[MethodTagDefinition]
) -> void:
	for definition_id: StringName in p_contract_definitions:
		var definition: ContractDefinition = p_contract_definitions[definition_id]
		contract_definitions[definition_id] = (
			definition.duplicate_value() if definition != null else null
		)
	for definition_id: StringName in p_adventurer_definitions:
		var definition: AdventurerDefinition = p_adventurer_definitions[definition_id]
		adventurer_definitions[definition_id] = (
			definition.duplicate_value() if definition != null else null
		)
	for definition_id: StringName in p_supply_definitions:
		var definition: SupplyDefinition = p_supply_definitions[definition_id]
		supply_definitions[definition_id] = (
			definition.duplicate_value() if definition != null else null
		)
	for clause: ContractClauseDefinition in p_clauses:
		clauses.append(clause.duplicate_value() if clause != null else null)
	for definition: MethodTagDefinition in p_method_tag_definitions:
		method_tag_definitions.append(
			definition.duplicate_value() if definition != null else null
		)


## Validates detached ownership and references that do not require a DataCatalog.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for definition_id: StringName in contract_definitions:
		var definition: ContractDefinition = contract_definitions[definition_id]
		if not StableId.is_valid(definition_id):
			errors.append(StableId.validation_error(
				definition_id,
				"ContractPlanningDefinitions contract key"
			))
		if definition == null:
			errors.append(
				"ContractPlanningDefinitions contract %s is null." % definition_id
			)
			continue
		if definition.id != definition_id:
			errors.append(
				"ContractPlanningDefinitions contract key must equal its definition ID."
			)
	for definition_id: StringName in adventurer_definitions:
		var definition: AdventurerDefinition = adventurer_definitions[definition_id]
		if not StableId.is_valid(definition_id):
			errors.append(StableId.validation_error(
				definition_id,
				"ContractPlanningDefinitions adventurer key"
			))
		if definition == null:
			errors.append(
				"ContractPlanningDefinitions adventurer %s is null." % definition_id
			)
			continue
		if definition.id != definition_id:
			errors.append(
				"ContractPlanningDefinitions adventurer key must equal its definition ID."
			)
		errors.append_array(AdventurerDefinition.validate_values(
			definition.id,
			definition.class_id,
			definition.base_capabilities,
			definition.values,
			definition.traits,
			definition.starting_relationships,
			definition.wage
		))

	for definition_id: StringName in supply_definitions:
		var definition: SupplyDefinition = supply_definitions[definition_id]
		if not StableId.is_valid(definition_id):
			errors.append(StableId.validation_error(
				definition_id,
				"ContractPlanningDefinitions supply key"
			))
		if definition == null:
			errors.append(
				"ContractPlanningDefinitions supply %s is null." % definition_id
			)
			continue
		if definition.id != definition_id:
			errors.append(
				"ContractPlanningDefinitions supply key must equal its definition ID."
			)
		if not StableId.is_valid(definition.id):
			errors.append(StableId.validation_error(
				definition.id,
				"SupplyDefinition.id"
			))

	_append_unique_clause_issues(errors)
	_append_unique_method_tag_issues(errors)
	return errors


func duplicate_value() -> ContractPlanningDefinitions:
	return ContractPlanningDefinitions.new(
		contract_definitions,
		adventurer_definitions,
		supply_definitions,
		clauses,
		method_tag_definitions
	)


func content_signature() -> String:
	var contract_parts := PackedStringArray()
	var contract_ids: Array[StringName] = contract_definitions.keys()
	contract_ids.sort()
	for definition_id: StringName in contract_ids:
		var definition: ContractDefinition = contract_definitions[definition_id]
		contract_parts.append(
			"<null>" if definition == null else "%s:%s:%s:%d" % [
				definition.id,
				definition.sponsor_faction_id,
				definition.target_lock_key,
				definition.base_reward,
			]
		)
	var adventurer_parts := PackedStringArray()
	var adventurer_ids: Array[StringName] = adventurer_definitions.keys()
	adventurer_ids.sort()
	for definition_id: StringName in adventurer_ids:
		adventurer_parts.append(_adventurer_signature(adventurer_definitions[definition_id]))

	var supply_parts := PackedStringArray()
	var supply_ids: Array[StringName] = supply_definitions.keys()
	supply_ids.sort()
	for definition_id: StringName in supply_ids:
		supply_parts.append(_supply_signature(supply_definitions[definition_id]))

	var clause_parts := PackedStringArray()
	for clause: ContractClauseDefinition in clauses:
		clause_parts.append(_clause_signature(clause))

	var method_tag_parts := PackedStringArray()
	for definition: MethodTagDefinition in method_tag_definitions:
		method_tag_parts.append(_method_tag_signature(definition))

	return "contracts=%s|adventurers=%s|supplies=%s|clauses=%s|method_tags=%s" % [
		contract_parts,
		adventurer_parts,
		supply_parts,
		clause_parts,
		method_tag_parts,
	]


func _append_unique_clause_issues(errors: PackedStringArray) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for clause: ContractClauseDefinition in clauses:
		if clause == null:
			errors.append("ContractPlanningDefinitions.clauses cannot contain null.")
			continue
		if not StableId.is_valid(clause.id):
			errors.append(StableId.validation_error(
				clause.id,
				"ContractClauseDefinition.id"
			))
		elif seen.has(clause.id):
			errors.append("ContractPlanningDefinitions contains duplicate clause %s." % clause.id)
		seen[clause.id] = true


func _append_unique_method_tag_issues(errors: PackedStringArray) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for definition: MethodTagDefinition in method_tag_definitions:
		if definition == null:
			errors.append(
				"ContractPlanningDefinitions.method_tag_definitions cannot contain null."
			)
			continue
		if not StableId.is_valid(definition.id):
			errors.append(StableId.validation_error(
				definition.id,
				"MethodTagDefinition.id"
			))
		elif seen.has(definition.id):
			errors.append(
				"ContractPlanningDefinitions contains duplicate method tag %s."
				% definition.id
			)
		seen[definition.id] = true
		if definition.ideology_vector == null:
			errors.append("MethodTagDefinition %s requires an ideology vector." % definition.id)


static func _adventurer_signature(definition: AdventurerDefinition) -> String:
	if definition == null:
		return "<null>"
	var capabilities = definition.base_capabilities
	var values = definition.values
	var relationships := PackedStringArray()
	for relationship in definition.starting_relationships:
		relationships.append("%s:%d" % [
			relationship.target_id,
			relationship.base_value,
		])
	relationships.sort()
	return "%s:%s:%d:%s:%s:%s" % [
		definition.id,
		definition.class_id,
		definition.wage,
		[
			capabilities.frontline,
			capabilities.offense,
			capabilities.scouting,
			capabilities.support,
			capabilities.arcana,
			capabilities.discipline,
		],
		[
			values.protect_life,
			values.respect_authority,
			values.seek_knowledge,
			values.pursue_profit,
			values.taboo_tolerance,
			definition.traits,
		],
		relationships,
	]


static func _supply_signature(definition: SupplyDefinition) -> String:
	if definition == null:
		return "<null>"
	var modifier_parts := PackedStringArray()
	for modifier in definition.modifiers:
		if modifier == null:
			modifier_parts.append("<null>")
		else:
			modifier_parts.append("%s:%s:%d:%s" % [
				modifier.target_type,
				modifier.match_tag,
				modifier.amount,
				modifier.reason_code,
			])
	return "%s:%d:%s:%s:%s" % [
		definition.id,
		definition.cost,
		definition.tags,
		definition.consumed_on_use,
		modifier_parts,
	]


static func _clause_signature(clause: ContractClauseDefinition) -> String:
	if clause == null:
		return "<null>"
	var condition_parts := PackedStringArray()
	for condition in clause.all_conditions:
		if condition == null:
			condition_parts.append("<null>")
		else:
			condition_parts.append("%s:%s:%s:%d:%s" % [
				condition.type,
				condition.source_id,
				condition.key,
				condition.int_value,
				condition.tag_value,
			])
	var success_effect_parts := _effect_signatures(clause.success_effects)
	var failure_effect_parts := _effect_signatures(clause.failure_effects)
	return "%s:%s:%s:%d:%s:%s:%s:%s:%s:%s:%s:%s" % [
		clause.id,
		clause.category,
		clause.importance,
		clause.priority,
		clause.breach_result_cap,
		condition_parts,
		success_effect_parts,
		failure_effect_parts,
		_ideology_signature(clause.success_ideology_impact),
		_ideology_signature(clause.failure_ideology_impact),
		clause.success_tags,
		clause.failure_tags,
	]


static func _effect_signatures(effects: Array) -> PackedStringArray:
	var parts := PackedStringArray()
	for effect in effects:
		if effect == null:
			parts.append("<null>")
		else:
			parts.append("%s:%d:%s:%s" % [
				effect.type,
				effect.amount,
				effect.tag_value,
				effect.reason_code,
			])
	return parts


static func _method_tag_signature(definition: MethodTagDefinition) -> String:
	if definition == null:
		return "<null>"
	var values = definition.ideology_vector
	if values == null:
		return "%s:<null>:%d" % [definition.id, definition.taboo_intensity]
	return "%s:%s:%d" % [
		definition.id,
		_ideology_signature(values),
		definition.taboo_intensity,
	]


static func _ideology_signature(values) -> String:
	if values == null:
		return "<null>"
	return "%s" % [[
		values.protect_life,
		values.respect_authority,
		values.seek_knowledge,
		values.pursue_profit,
		values.taboo_tolerance,
	]]
