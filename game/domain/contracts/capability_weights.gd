class_name CapabilityWeights
extends RefCounted

const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")

const SUM_EPSILON: float = 0.0001

var frontline: float:
	get:
		return _frontline
	set(_value):
		assert(false, "CapabilityWeights.frontline is read-only.")
var offense: float:
	get:
		return _offense
	set(_value):
		assert(false, "CapabilityWeights.offense is read-only.")
var scouting: float:
	get:
		return _scouting
	set(_value):
		assert(false, "CapabilityWeights.scouting is read-only.")
var support: float:
	get:
		return _support
	set(_value):
		assert(false, "CapabilityWeights.support is read-only.")
var arcana: float:
	get:
		return _arcana
	set(_value):
		assert(false, "CapabilityWeights.arcana is read-only.")
var discipline: float:
	get:
		return _discipline
	set(_value):
		assert(false, "CapabilityWeights.discipline is read-only.")

var _frontline: float
var _offense: float
var _scouting: float
var _support: float
var _arcana: float
var _discipline: float


static func create(
	p_frontline: float,
	p_offense: float,
	p_scouting: float,
	p_support: float,
	p_arcana: float,
	p_discipline: float
) -> CapabilityWeights:
	if not validate_values(
		p_frontline,
		p_offense,
		p_scouting,
		p_support,
		p_arcana,
		p_discipline
	).is_empty():
		return null
	return CapabilityWeights.new(
		p_frontline,
		p_offense,
		p_scouting,
		p_support,
		p_arcana,
		p_discipline
	)


static func validate_values(
	p_frontline: float,
	p_offense: float,
	p_scouting: float,
	p_support: float,
	p_arcana: float,
	p_discipline: float
) -> PackedStringArray:
	var errors := PackedStringArray()
	var values: Array[float] = [
		p_frontline,
		p_offense,
		p_scouting,
		p_support,
		p_arcana,
		p_discipline,
	]
	for value: float in values:
		if value < 0.0:
			errors.append("Capability weights must be non-negative.")
			break
	var total: float = p_frontline + p_offense + p_scouting + p_support + p_arcana + p_discipline
	if absf(total - 1.0) > SUM_EPSILON:
		errors.append("Capability weights must sum to 1.0 within epsilon %f." % SUM_EPSILON)
	return errors


func _init(
	p_frontline: float,
	p_offense: float,
	p_scouting: float,
	p_support: float,
	p_arcana: float,
	p_discipline: float
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


func weighted_dot(capabilities: CapabilityBlock) -> float:
	assert(capabilities != null)
	return capabilities.frontline * _frontline \
		+ capabilities.offense * _offense \
		+ capabilities.scouting * _scouting \
		+ capabilities.support * _support \
		+ capabilities.arcana * _arcana \
		+ capabilities.discipline * _discipline


func duplicate_value() -> CapabilityWeights:
	return CapabilityWeights.new(
		_frontline,
		_offense,
		_scouting,
		_support,
		_arcana,
		_discipline
	)


func is_equal_to(other: CapabilityWeights) -> bool:
	return other != null \
		and is_equal_approx(_frontline, other.frontline) \
		and is_equal_approx(_offense, other.offense) \
		and is_equal_approx(_scouting, other.scouting) \
		and is_equal_approx(_support, other.support) \
		and is_equal_approx(_arcana, other.arcana) \
		and is_equal_approx(_discipline, other.discipline)
