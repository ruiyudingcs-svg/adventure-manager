class_name AdventurerDefinition
extends Resource

const StableId = preload("res://game/core/ids/stable_id.gd")
const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const RelationshipDefinition = preload("res://game/domain/adventurers/relationship_definition.gd")

var id: StringName:
	get:
		return _id
	set(_value):
		assert(false, "AdventurerDefinition.id is read-only at runtime.")
var display_name: String:
	get:
		return _display_name
	set(_value):
		assert(false, "AdventurerDefinition.display_name is read-only at runtime.")
var class_id: StringName:
	get:
		return _class_id
	set(_value):
		assert(false, "AdventurerDefinition.class_id is read-only at runtime.")
var portrait: Texture2D:
	get:
		return _portrait
	set(_value):
		assert(false, "AdventurerDefinition.portrait is read-only at runtime.")
var base_capabilities: CapabilityBlock:
	get:
		return _base_capabilities.duplicate_value()
	set(_value):
		assert(false, "AdventurerDefinition.base_capabilities is read-only at runtime.")
var traits: Array[StringName]:
	get:
		return _copy_string_names(_traits)
	set(_value):
		assert(false, "AdventurerDefinition.traits is read-only at runtime.")
var values: IdeologyVector:
	get:
		return _values.duplicate_value()
	set(_value):
		assert(false, "AdventurerDefinition.values is read-only at runtime.")
var starting_relationships: Array[RelationshipDefinition]:
	get:
		return _copy_relationships(_starting_relationships)
	set(_value):
		assert(false, "AdventurerDefinition.starting_relationships is read-only at runtime.")
var wage: int:
	get:
		return _wage
	set(_value):
		assert(false, "AdventurerDefinition.wage is read-only at runtime.")
var bio_key: StringName:
	get:
		return _bio_key
	set(_value):
		assert(false, "AdventurerDefinition.bio_key is read-only at runtime.")

var _id: StringName
var _display_name: String
var _class_id: StringName
var _portrait: Texture2D
var _base_capabilities: CapabilityBlock
var _traits: Array[StringName] = []
var _values: IdeologyVector
var _starting_relationships: Array[RelationshipDefinition] = []
var _wage: int
var _bio_key: StringName
var _is_configured: bool = false


static func create(
	p_id: StringName,
	p_display_name: String,
	p_class_id: StringName,
	p_base_capabilities: CapabilityBlock,
	p_values: IdeologyVector,
	p_traits: Array[StringName] = [],
	p_starting_relationships: Array[RelationshipDefinition] = [],
	p_wage: int = 1,
	p_bio_key: StringName = &"",
	p_portrait: Texture2D = null
) -> AdventurerDefinition:
	if not validate_values(
		p_id,
		p_class_id,
		p_base_capabilities,
		p_values,
		p_traits,
		p_starting_relationships,
		p_wage
	).is_empty():
		return null

	var definition := AdventurerDefinition.new()
	definition._configure(
		p_id,
		p_display_name,
		p_class_id,
		p_base_capabilities,
		p_values,
		p_traits,
		p_starting_relationships,
		p_wage,
		p_bio_key,
		p_portrait
	)
	return definition


static func validate_values(
	p_id: StringName,
	p_class_id: StringName,
	p_base_capabilities: CapabilityBlock,
	p_values: IdeologyVector,
	p_traits: Array[StringName],
	p_starting_relationships: Array[RelationshipDefinition],
	p_wage: int
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(p_id):
		errors.append(StableId.validation_error(p_id, "AdventurerDefinition.id"))
	if not StableId.is_valid(p_class_id):
		errors.append(StableId.validation_error(p_class_id, "AdventurerDefinition.class_id"))
	if p_base_capabilities == null:
		errors.append("AdventurerDefinition.base_capabilities is required.")
	if p_values == null:
		errors.append("AdventurerDefinition.values is required.")
	elif not p_values.is_valid_as_base():
		errors.append("AdventurerDefinition.values must use the hero base range -5..5.")
	if p_wage <= 0:
		errors.append("AdventurerDefinition.wage must be greater than zero.")
	for trait_id: StringName in p_traits:
		if not StableId.is_valid(trait_id):
			errors.append(StableId.validation_error(trait_id, "AdventurerDefinition.traits"))
	var relationship_targets: Dictionary[StringName, bool] = {}
	for relationship: RelationshipDefinition in p_starting_relationships:
		if relationship == null:
			errors.append("AdventurerDefinition.starting_relationships cannot contain null.")
			continue
		if relationship_targets.has(relationship.target_id):
			errors.append("Starting relationship target IDs must be unique.")
		relationship_targets[relationship.target_id] = true
	return errors


func _configure(
	p_id: StringName,
	p_display_name: String,
	p_class_id: StringName,
	p_base_capabilities: CapabilityBlock,
	p_values: IdeologyVector,
	p_traits: Array[StringName],
	p_starting_relationships: Array[RelationshipDefinition],
	p_wage: int,
	p_bio_key: StringName,
	p_portrait: Texture2D
) -> void:
	assert(not _is_configured, "AdventurerDefinition can only be configured once.")
	assert(validate_values(
		p_id,
		p_class_id,
		p_base_capabilities,
		p_values,
		p_traits,
		p_starting_relationships,
		p_wage
	).is_empty())
	_id = p_id
	_display_name = p_display_name
	_class_id = p_class_id
	_portrait = p_portrait
	_base_capabilities = p_base_capabilities.duplicate_value()
	_traits = _copy_string_names(p_traits)
	_values = p_values.duplicate_value()
	_starting_relationships = _copy_relationships(p_starting_relationships)
	_wage = p_wage
	_bio_key = p_bio_key
	_is_configured = true


static func _copy_string_names(source: Array[StringName]) -> Array[StringName]:
	var copied: Array[StringName] = []
	for value: StringName in source:
		copied.append(value)
	return copied


static func _copy_relationships(
	source: Array[RelationshipDefinition]
) -> Array[RelationshipDefinition]:
	var copied: Array[RelationshipDefinition] = []
	for relationship: RelationshipDefinition in source:
		copied.append(relationship.duplicate_value())
	return copied


## Returns a complete detached runtime copy for catalog caller isolation.
func duplicate_value() -> AdventurerDefinition:
	return AdventurerDefinition.create(
		_id,
		_display_name,
		_class_id,
		_base_capabilities,
		_values,
		_traits,
		_starting_relationships,
		_wage,
		_bio_key,
		_portrait
	)
