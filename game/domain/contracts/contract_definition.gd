## Static contract template compiled from Inspector authoring data.
class_name ContractDefinition
extends RefCounted

const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const ContractStageDefinition = preload("res://game/domain/contracts/contract_stage_definition.gd")
const ContractOutcomeTable = preload("res://game/domain/contracts/contract_outcome_table.gd")
const WorldRule = preload("res://game/domain/situations/world_rule.gd")


## Structured, non-executable predicate used only while instantiating an offer.
class OfferBindingCondition extends RefCounted:
	var type: StringName
	var target_id: StringName
	var int_value: int
	var tag_value: StringName

	func _init(
		p_type: StringName,
		p_target_id: StringName,
		p_int_value: int,
		p_tag_value: StringName
	) -> void:
		type = p_type
		target_id = p_target_id
		int_value = p_int_value
		tag_value = p_tag_value

	func duplicate_value() -> OfferBindingCondition:
		return OfferBindingCondition.new(type, target_id, int_value, tag_value)


## Bounded overlay applied to a check difficulty or initial MissionContext key.
class OfferInstantiationEffect extends RefCounted:
	var type: StringName
	var target_id: StringName
	var amount: int

	func _init(p_type: StringName, p_target_id: StringName, p_amount: int) -> void:
		type = p_type
		target_id = p_target_id
		amount = p_amount

	func duplicate_value() -> OfferInstantiationEffect:
		return OfferInstantiationEffect.new(type, target_id, amount)


## One deterministic offer-instantiation rule.
class OfferInstantiationRule extends RefCounted:
	var id: StringName
	var all_conditions: Array[OfferBindingCondition]
	var effects: Array[OfferInstantiationEffect]
	var reason_code: StringName

	func _init(
		p_id: StringName,
		p_all_conditions: Array[OfferBindingCondition],
		p_effects: Array[OfferInstantiationEffect],
		p_reason_code: StringName
	) -> void:
		id = p_id
		for condition: OfferBindingCondition in p_all_conditions:
			all_conditions.append(condition.duplicate_value())
		for effect: OfferInstantiationEffect in p_effects:
			effects.append(effect.duplicate_value())
		reason_code = p_reason_code

	func duplicate_value() -> OfferInstantiationRule:
		return OfferInstantiationRule.new(id, all_conditions, effects, reason_code)


var id: StringName
var title_key: StringName
var description_key: StringName
var sponsor_faction_id: StringName
var related_problem_id: StringName
var target_lock_key: StringName
var target_problem_tags: Array[StringName]
var agenda_tags: Array[StringName]
var allow_agenda_origin: bool
var starts_unlocked: bool
var repeat_policy: StringName
var min_reputation: int
var prerequisite_contract_ids: Array[StringName]
var exclusive_contract_ids: Array[StringName]
var proposal_base_priority: int
var urgency_weight: int
var recent_repeat_cooldown: int
var base_reward: int
var base_fatigue: int
var risk_level: int
var offer_duration_weeks: int
var intent_ideology_vector: IdeologyVector
var expected_method_tags: Array[StringName]
var stages: Array[ContractStageDefinition]
var clause_ids: Array[StringName]
var allowed_supply_tags: Array[StringName]
var final_outcome_table: ContractOutcomeTable
var availability_rules: Array[WorldRule]
var instantiation_rules: Array[OfferInstantiationRule]
var unhandled_policy: StringName
var npc_completion_action_id: StringName


static func create(
	p_id: StringName,
	p_title_key: StringName,
	p_description_key: StringName,
	p_sponsor_faction_id: StringName,
	p_related_problem_id: StringName,
	p_target_lock_key: StringName,
	p_target_problem_tags: Array[StringName],
	p_agenda_tags: Array[StringName],
	p_allow_agenda_origin: bool,
	p_starts_unlocked: bool,
	p_repeat_policy: StringName,
	p_min_reputation: int,
	p_prerequisite_contract_ids: Array[StringName],
	p_exclusive_contract_ids: Array[StringName],
	p_proposal_base_priority: int,
	p_urgency_weight: int,
	p_recent_repeat_cooldown: int,
	p_base_reward: int,
	p_base_fatigue: int,
	p_risk_level: int,
	p_offer_duration_weeks: int,
	p_intent_ideology_vector: IdeologyVector,
	p_expected_method_tags: Array[StringName],
	p_stages: Array[ContractStageDefinition],
	p_clause_ids: Array[StringName],
	p_allowed_supply_tags: Array[StringName],
	p_final_outcome_table: ContractOutcomeTable,
	p_availability_rules: Array[WorldRule],
	p_instantiation_rules: Array[OfferInstantiationRule],
	p_unhandled_policy: StringName,
	p_npc_completion_action_id: StringName
) -> ContractDefinition:
	return ContractDefinition.new(
		p_id, p_title_key, p_description_key, p_sponsor_faction_id,
		p_related_problem_id, p_target_lock_key, p_target_problem_tags, p_agenda_tags,
		p_allow_agenda_origin, p_starts_unlocked, p_repeat_policy, p_min_reputation,
		p_prerequisite_contract_ids, p_exclusive_contract_ids, p_proposal_base_priority,
		p_urgency_weight, p_recent_repeat_cooldown, p_base_reward, p_base_fatigue,
		p_risk_level, p_offer_duration_weeks, p_intent_ideology_vector,
		p_expected_method_tags, p_stages, p_clause_ids, p_allowed_supply_tags,
		p_final_outcome_table, p_availability_rules, p_instantiation_rules,
		p_unhandled_policy, p_npc_completion_action_id
	)


func _init(
	p_id: StringName,
	p_title_key: StringName,
	p_description_key: StringName,
	p_sponsor_faction_id: StringName,
	p_related_problem_id: StringName,
	p_target_lock_key: StringName,
	p_target_problem_tags: Array[StringName],
	p_agenda_tags: Array[StringName],
	p_allow_agenda_origin: bool,
	p_starts_unlocked: bool,
	p_repeat_policy: StringName,
	p_min_reputation: int,
	p_prerequisite_contract_ids: Array[StringName],
	p_exclusive_contract_ids: Array[StringName],
	p_proposal_base_priority: int,
	p_urgency_weight: int,
	p_recent_repeat_cooldown: int,
	p_base_reward: int,
	p_base_fatigue: int,
	p_risk_level: int,
	p_offer_duration_weeks: int,
	p_intent_ideology_vector: IdeologyVector,
	p_expected_method_tags: Array[StringName],
	p_stages: Array[ContractStageDefinition],
	p_clause_ids: Array[StringName],
	p_allowed_supply_tags: Array[StringName],
	p_final_outcome_table: ContractOutcomeTable,
	p_availability_rules: Array[WorldRule],
	p_instantiation_rules: Array[OfferInstantiationRule],
	p_unhandled_policy: StringName,
	p_npc_completion_action_id: StringName
) -> void:
	id = p_id
	title_key = p_title_key
	description_key = p_description_key
	sponsor_faction_id = p_sponsor_faction_id
	related_problem_id = p_related_problem_id
	target_lock_key = p_target_lock_key
	target_problem_tags.append_array(p_target_problem_tags)
	agenda_tags.append_array(p_agenda_tags)
	allow_agenda_origin = p_allow_agenda_origin
	starts_unlocked = p_starts_unlocked
	repeat_policy = p_repeat_policy
	min_reputation = p_min_reputation
	prerequisite_contract_ids.append_array(p_prerequisite_contract_ids)
	exclusive_contract_ids.append_array(p_exclusive_contract_ids)
	proposal_base_priority = p_proposal_base_priority
	urgency_weight = p_urgency_weight
	recent_repeat_cooldown = p_recent_repeat_cooldown
	base_reward = p_base_reward
	base_fatigue = p_base_fatigue
	risk_level = p_risk_level
	offer_duration_weeks = p_offer_duration_weeks
	intent_ideology_vector = (
		p_intent_ideology_vector.duplicate_value()
		if p_intent_ideology_vector != null else null
	)
	expected_method_tags.append_array(p_expected_method_tags)
	for stage: ContractStageDefinition in p_stages:
		stages.append(stage.duplicate_value() if stage != null else null)
	clause_ids.append_array(p_clause_ids)
	allowed_supply_tags.append_array(p_allowed_supply_tags)
	final_outcome_table = (
		p_final_outcome_table.duplicate_value()
		if p_final_outcome_table != null else null
	)
	for rule: WorldRule in p_availability_rules:
		availability_rules.append(rule.duplicate_value() if rule != null else null)
	for rule: OfferInstantiationRule in p_instantiation_rules:
		instantiation_rules.append(rule.duplicate_value() if rule != null else null)
	unhandled_policy = p_unhandled_policy
	npc_completion_action_id = p_npc_completion_action_id


func duplicate_value() -> ContractDefinition:
	return ContractDefinition.new(
		id, title_key, description_key, sponsor_faction_id, related_problem_id,
		target_lock_key, target_problem_tags, agenda_tags, allow_agenda_origin,
		starts_unlocked, repeat_policy, min_reputation, prerequisite_contract_ids,
		exclusive_contract_ids, proposal_base_priority, urgency_weight,
		recent_repeat_cooldown, base_reward, base_fatigue, risk_level,
		offer_duration_weeks, intent_ideology_vector, expected_method_tags, stages,
		clause_ids, allowed_supply_tags, final_outcome_table, availability_rules,
		instantiation_rules, unhandled_policy, npc_completion_action_id
	)
