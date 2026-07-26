## Immutable-at-catalog-boundary trait policy metadata.
class_name TraitDefinition
extends RefCounted

const ConditionalModifier = preload("res://game/domain/contracts/conditional_modifier.gd")

var id: StringName
var display_name_key: StringName
var description_key: StringName
var rule_tags: Array[StringName]
var modifiers: Array[ConditionalModifier]


static func create(
	p_id: StringName,
	p_display_name_key: StringName,
	p_description_key: StringName,
	p_rule_tags: Array[StringName],
	p_modifiers: Array[ConditionalModifier]
) -> TraitDefinition:
	return TraitDefinition.new(
		p_id,
		p_display_name_key,
		p_description_key,
		p_rule_tags,
		p_modifiers
	)


func _init(
	p_id: StringName,
	p_display_name_key: StringName,
	p_description_key: StringName,
	p_rule_tags: Array[StringName],
	p_modifiers: Array[ConditionalModifier]
) -> void:
	id = p_id
	display_name_key = p_display_name_key
	description_key = p_description_key
	rule_tags.append_array(p_rule_tags)
	for modifier: ConditionalModifier in p_modifiers:
		modifiers.append(modifier.duplicate_value() if modifier != null else null)


func duplicate_value() -> TraitDefinition:
	return TraitDefinition.new(id, display_name_key, description_key, rule_tags, modifiers)
