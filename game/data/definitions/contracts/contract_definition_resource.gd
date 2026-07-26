## Inspector authoring Resource for one complete contract template.
class_name ContractDefinitionResource
extends Resource

const ContractDefinition = preload("res://game/domain/contracts/contract_definition.gd")
const IdeologyVectorResource = preload(
	"res://game/data/definitions/adventurers/ideology_vector_resource.gd"
)
const ContractStageDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_stage_definition_resource.gd"
)
const ContractOutcomeTableResource = preload(
	"res://game/data/definitions/contracts/contract_outcome_table_resource.gd"
)
const WorldRuleResource = preload(
	"res://game/data/definitions/situations/world_rule_resource.gd"
)
const OfferInstantiationRuleResource = preload(
	"res://game/data/definitions/contracts/offer_instantiation_rule_resource.gd"
)
const ContractStageDefinition = preload(
	"res://game/domain/contracts/contract_stage_definition.gd"
)
const WorldRule = preload("res://game/domain/situations/world_rule.gd")

@export var id: StringName
@export var title_key: StringName
@export var description_key: StringName
@export var sponsor_faction_id: StringName
@export var related_problem_id: StringName
@export var target_lock_key: StringName
@export var target_problem_tags: Array[StringName] = []
@export var agenda_tags: Array[StringName] = []
@export var allow_agenda_origin: bool = false
@export var starts_unlocked: bool = true
@export var repeat_policy: StringName = &"repeatable"
@export var min_reputation: int = 0
@export var prerequisite_contract_ids: Array[StringName] = []
@export var exclusive_contract_ids: Array[StringName] = []
@export var proposal_base_priority: int = 0
@export var urgency_weight: int = 0
@export var recent_repeat_cooldown: int = 0
@export var base_reward: int = 0
@export var base_fatigue: int = 0
@export_range(1, 5) var risk_level: int = 1
@export var offer_duration_weeks: int = 1
@export var intent_ideology_vector: IdeologyVectorResource
@export var expected_method_tags: Array[StringName] = []
@export var stages: Array[ContractStageDefinitionResource] = []
@export var clause_ids: Array[StringName] = []
@export var allowed_supply_tags: Array[StringName] = []
@export var final_outcome_table: ContractOutcomeTableResource
@export var availability_rules: Array[WorldRuleResource] = []
@export var instantiation_rules: Array[OfferInstantiationRuleResource] = []
@export var unhandled_policy: StringName = &"expire"
@export var npc_completion_action_id: StringName


## Deep-compiles the full contract graph after catalog validation.
func compile() -> ContractDefinition:
	if intent_ideology_vector == null or final_outcome_table == null:
		return null
	var compiled_stages: Array[ContractStageDefinition] = []
	var compiled_availability: Array[WorldRule] = []
	var compiled_instantiation: Array[ContractDefinition.OfferInstantiationRule] = []
	for stage: ContractStageDefinitionResource in stages:
		if stage == null:
			return null
		compiled_stages.append(stage.compile())
	for rule: WorldRuleResource in availability_rules:
		if rule == null:
			return null
		compiled_availability.append(rule.compile())
	for rule: OfferInstantiationRuleResource in instantiation_rules:
		if rule == null:
			return null
		compiled_instantiation.append(rule.compile())
	return ContractDefinition.create(
		id, title_key, description_key, sponsor_faction_id, related_problem_id,
		target_lock_key, target_problem_tags, agenda_tags, allow_agenda_origin,
		starts_unlocked, repeat_policy, min_reputation, prerequisite_contract_ids,
		exclusive_contract_ids, proposal_base_priority, urgency_weight,
		recent_repeat_cooldown, base_reward, base_fatigue, risk_level,
		offer_duration_weeks, intent_ideology_vector.compile(), expected_method_tags,
		compiled_stages, clause_ids, allowed_supply_tags, final_outcome_table.compile(),
		compiled_availability, compiled_instantiation, unhandled_policy,
		npc_completion_action_id
	)
