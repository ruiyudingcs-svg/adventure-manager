class_name AdventurerSnapshot
extends RefCounted

const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const RelationshipDefinition = preload("res://game/domain/adventurers/relationship_definition.gd")
const AdventurerDefinition = preload("res://game/domain/adventurers/adventurer_definition.gd")
const AdventurerState = preload("res://game/domain/adventurers/adventurer_state.gd")

var id: StringName:
	get:
		return _id
	set(_value):
		assert(false, "AdventurerSnapshot.id is read-only.")
var class_id: StringName:
	get:
		return _class_id
	set(_value):
		assert(false, "AdventurerSnapshot.class_id is read-only.")
var wage: int:
	get:
		return _wage
	set(_value):
		assert(false, "AdventurerSnapshot.wage is read-only.")
var capabilities: CapabilityBlock:
	get:
		return _capabilities.duplicate_value()
	set(_value):
		assert(false, "AdventurerSnapshot.capabilities is read-only.")
var values: IdeologyVector:
	get:
		return _values.duplicate_value()
	set(_value):
		assert(false, "AdventurerSnapshot.values is read-only.")
var traits: Array[StringName]:
	get:
		return _copy_string_names(_traits)
	set(_value):
		assert(false, "AdventurerSnapshot.traits is read-only.")
var fatigue: int:
	get:
		return _fatigue
	set(_value):
		assert(false, "AdventurerSnapshot.fatigue is read-only.")
var morale: int:
	get:
		return _morale
	set(_value):
		assert(false, "AdventurerSnapshot.morale is read-only.")
var injury_severity: int:
	get:
		return _injury_severity
	set(_value):
		assert(false, "AdventurerSnapshot.injury_severity is read-only.")
var recovery_weeks_remaining: int:
	get:
		return _recovery_weeks_remaining
	set(_value):
		assert(false, "AdventurerSnapshot.recovery_weeks_remaining is read-only.")
var growth_xp: int:
	get:
		return _growth_xp
	set(_value):
		assert(false, "AdventurerSnapshot.growth_xp is read-only.")
var is_available: bool:
	get:
		return _is_available
	set(_value):
		assert(false, "AdventurerSnapshot.is_available is read-only.")
var relationship_values: Dictionary[StringName, int]:
	get:
		return _copy_relationships(_relationship_values)
	set(_value):
		assert(false, "AdventurerSnapshot.relationship_values is read-only.")
var recent_assignment_count: int:
	get:
		return _recent_assignment_count
	set(_value):
		assert(false, "AdventurerSnapshot.recent_assignment_count is read-only.")
var recent_neglect_count: int:
	get:
		return _recent_neglect_count
	set(_value):
		assert(false, "AdventurerSnapshot.recent_neglect_count is read-only.")

var _id: StringName
var _class_id: StringName
var _wage: int
var _capabilities: CapabilityBlock
var _values: IdeologyVector
var _traits: Array[StringName] = []
var _fatigue: int
var _morale: int
var _injury_severity: int
var _recovery_weeks_remaining: int
var _growth_xp: int
var _is_available: bool
var _relationship_values: Dictionary[StringName, int] = {}
var _recent_assignment_count: int
var _recent_neglect_count: int


static func create(
	definition: AdventurerDefinition,
	state: AdventurerState
) -> AdventurerSnapshot:
	if definition == null or state == null or definition.id != state.definition_id:
		return null

	var snapshot := AdventurerSnapshot.new()
	snapshot._id = definition.id
	snapshot._class_id = definition.class_id
	snapshot._wage = definition.wage
	snapshot._capabilities = definition.base_capabilities
	snapshot._values = definition.values
	snapshot._traits = _copy_string_names(definition.traits)
	snapshot._fatigue = state.get_fatigue()
	snapshot._morale = state.get_morale()
	snapshot._injury_severity = state.get_injury_severity()
	snapshot._recovery_weeks_remaining = state.get_recovery_weeks_remaining()
	snapshot._growth_xp = state.get_growth_xp()
	snapshot._is_available = state.get_is_available()
	snapshot._relationship_values = _merge_relationships(
		definition.starting_relationships,
		state.get_relationship_deltas()
	)
	snapshot._recent_assignment_count = state.get_recent_assignment_count()
	snapshot._recent_neglect_count = state.get_recent_neglect_count()
	return snapshot


func duplicate_value() -> AdventurerSnapshot:
	var copied := AdventurerSnapshot.new()
	copied._id = _id
	copied._class_id = _class_id
	copied._wage = _wage
	copied._capabilities = _capabilities.duplicate_value()
	copied._values = _values.duplicate_value()
	copied._traits = _copy_string_names(_traits)
	copied._fatigue = _fatigue
	copied._morale = _morale
	copied._injury_severity = _injury_severity
	copied._recovery_weeks_remaining = _recovery_weeks_remaining
	copied._growth_xp = _growth_xp
	copied._is_available = _is_available
	copied._relationship_values = _copy_relationships(_relationship_values)
	copied._recent_assignment_count = _recent_assignment_count
	copied._recent_neglect_count = _recent_neglect_count
	return copied


static func _merge_relationships(
	starting_relationships: Array[RelationshipDefinition],
	deltas: Dictionary[StringName, int]
) -> Dictionary[StringName, int]:
	var merged: Dictionary[StringName, int] = {}
	for relationship: RelationshipDefinition in starting_relationships:
		merged[relationship.target_id] = relationship.base_value
	for target_id: StringName in deltas:
		merged[target_id] = merged.get(target_id, 0) + deltas[target_id]
	return merged


static func _copy_string_names(source: Array[StringName]) -> Array[StringName]:
	var copied: Array[StringName] = []
	for value: StringName in source:
		copied.append(value)
	return copied


static func _copy_relationships(
	source: Dictionary[StringName, int]
) -> Dictionary[StringName, int]:
	var copied: Dictionary[StringName, int] = {}
	for target_id: StringName in source:
		copied[target_id] = source[target_id]
	return copied
