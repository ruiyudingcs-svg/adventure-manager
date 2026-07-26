class_name CapabilityBlock
extends RefCounted

const MIN_VALUE: int = 0
const MAX_VALUE: int = 100

var frontline: int:
	get:
		return _frontline
	set(_value):
		assert(false, "CapabilityBlock.frontline is read-only.")
var offense: int:
	get:
		return _offense
	set(_value):
		assert(false, "CapabilityBlock.offense is read-only.")
var scouting: int:
	get:
		return _scouting
	set(_value):
		assert(false, "CapabilityBlock.scouting is read-only.")
var support: int:
	get:
		return _support
	set(_value):
		assert(false, "CapabilityBlock.support is read-only.")
var arcana: int:
	get:
		return _arcana
	set(_value):
		assert(false, "CapabilityBlock.arcana is read-only.")
var discipline: int:
	get:
		return _discipline
	set(_value):
		assert(false, "CapabilityBlock.discipline is read-only.")

var _frontline: int
var _offense: int
var _scouting: int
var _support: int
var _arcana: int
var _discipline: int


static func create(
	p_frontline: int,
	p_offense: int,
	p_scouting: int,
	p_support: int,
	p_arcana: int,
	p_discipline: int
) -> CapabilityBlock:
	if not validate_values(
		p_frontline,
		p_offense,
		p_scouting,
		p_support,
		p_arcana,
		p_discipline
	).is_empty():
		return null
	return CapabilityBlock.new(
		p_frontline,
		p_offense,
		p_scouting,
		p_support,
		p_arcana,
		p_discipline
	)


static func validate_values(
	p_frontline: int,
	p_offense: int,
	p_scouting: int,
	p_support: int,
	p_arcana: int,
	p_discipline: int
) -> PackedStringArray:
	var errors := PackedStringArray()
	_append_range_error(errors, &"frontline", p_frontline)
	_append_range_error(errors, &"offense", p_offense)
	_append_range_error(errors, &"scouting", p_scouting)
	_append_range_error(errors, &"support", p_support)
	_append_range_error(errors, &"arcana", p_arcana)
	_append_range_error(errors, &"discipline", p_discipline)
	return errors


func _init(
	p_frontline: int,
	p_offense: int,
	p_scouting: int,
	p_support: int,
	p_arcana: int,
	p_discipline: int
) -> void:
	assert(validate_values(
		p_frontline,
		p_offense,
		p_scouting,
		p_support,
		p_arcana,
		p_discipline
	).is_empty())
	_frontline = p_frontline
	_offense = p_offense
	_scouting = p_scouting
	_support = p_support
	_arcana = p_arcana
	_discipline = p_discipline


func duplicate_value() -> CapabilityBlock:
	return CapabilityBlock.new(
		_frontline,
		_offense,
		_scouting,
		_support,
		_arcana,
		_discipline
	)


func is_equal_to(other: CapabilityBlock) -> bool:
	return other != null \
		and _frontline == other.frontline \
		and _offense == other.offense \
		and _scouting == other.scouting \
		and _support == other.support \
		and _arcana == other.arcana \
		and _discipline == other.discipline


static func _append_range_error(errors: PackedStringArray, field_name: StringName, value: int) -> void:
	if value < MIN_VALUE or value > MAX_VALUE:
		errors.append("%s must be between %d and %d." % [field_name, MIN_VALUE, MAX_VALUE])
