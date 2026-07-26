class_name IdeologyVector
extends RefCounted

const BASE_LIMIT: int = 5
const TASK_LIMIT: int = 10

var protect_life: int:
	get:
		return _protect_life
	set(_value):
		assert(false, "IdeologyVector.protect_life is read-only.")
var respect_authority: int:
	get:
		return _respect_authority
	set(_value):
		assert(false, "IdeologyVector.respect_authority is read-only.")
var seek_knowledge: int:
	get:
		return _seek_knowledge
	set(_value):
		assert(false, "IdeologyVector.seek_knowledge is read-only.")
var pursue_profit: int:
	get:
		return _pursue_profit
	set(_value):
		assert(false, "IdeologyVector.pursue_profit is read-only.")
var taboo_tolerance: int:
	get:
		return _taboo_tolerance
	set(_value):
		assert(false, "IdeologyVector.taboo_tolerance is read-only.")

var _protect_life: int
var _respect_authority: int
var _seek_knowledge: int
var _pursue_profit: int
var _taboo_tolerance: int
var _validation_limit: int


static func create_base(
	p_protect_life: int,
	p_respect_authority: int,
	p_seek_knowledge: int,
	p_pursue_profit: int,
	p_taboo_tolerance: int
) -> IdeologyVector:
	return _create_with_limit(
		p_protect_life,
		p_respect_authority,
		p_seek_knowledge,
		p_pursue_profit,
		p_taboo_tolerance,
		BASE_LIMIT
	)


static func create_task_accumulation(
	p_protect_life: int,
	p_respect_authority: int,
	p_seek_knowledge: int,
	p_pursue_profit: int,
	p_taboo_tolerance: int
) -> IdeologyVector:
	return _create_with_limit(
		p_protect_life,
		p_respect_authority,
		p_seek_knowledge,
		p_pursue_profit,
		p_taboo_tolerance,
		TASK_LIMIT
	)


static func validate_base_values(
	p_protect_life: int,
	p_respect_authority: int,
	p_seek_knowledge: int,
	p_pursue_profit: int,
	p_taboo_tolerance: int
) -> PackedStringArray:
	return _validate_with_limit(
		p_protect_life,
		p_respect_authority,
		p_seek_knowledge,
		p_pursue_profit,
		p_taboo_tolerance,
		BASE_LIMIT
	)


static func validate_task_values(
	p_protect_life: int,
	p_respect_authority: int,
	p_seek_knowledge: int,
	p_pursue_profit: int,
	p_taboo_tolerance: int
) -> PackedStringArray:
	return _validate_with_limit(
		p_protect_life,
		p_respect_authority,
		p_seek_knowledge,
		p_pursue_profit,
		p_taboo_tolerance,
		TASK_LIMIT
	)


func _init(
	p_protect_life: int,
	p_respect_authority: int,
	p_seek_knowledge: int,
	p_pursue_profit: int,
	p_taboo_tolerance: int,
	p_validation_limit: int
) -> void:
	assert(_validate_with_limit(
		p_protect_life,
		p_respect_authority,
		p_seek_knowledge,
		p_pursue_profit,
		p_taboo_tolerance,
		p_validation_limit
	).is_empty())
	_protect_life = p_protect_life
	_respect_authority = p_respect_authority
	_seek_knowledge = p_seek_knowledge
	_pursue_profit = p_pursue_profit
	_taboo_tolerance = p_taboo_tolerance
	_validation_limit = p_validation_limit


func duplicate_value() -> IdeologyVector:
	return IdeologyVector.new(
		_protect_life,
		_respect_authority,
		_seek_knowledge,
		_pursue_profit,
		_taboo_tolerance,
		_validation_limit
	)


func is_equal_to(other: IdeologyVector) -> bool:
	return other != null \
		and _protect_life == other.protect_life \
		and _respect_authority == other.respect_authority \
		and _seek_knowledge == other.seek_knowledge \
		and _pursue_profit == other.pursue_profit \
		and _taboo_tolerance == other.taboo_tolerance


func is_valid_as_base() -> bool:
	return validate_base_values(
		_protect_life,
		_respect_authority,
		_seek_knowledge,
		_pursue_profit,
		_taboo_tolerance
	).is_empty()


func is_valid_as_task_accumulation() -> bool:
	return validate_task_values(
		_protect_life,
		_respect_authority,
		_seek_knowledge,
		_pursue_profit,
		_taboo_tolerance
	).is_empty()


func added_and_clamped_for_task(other: IdeologyVector) -> IdeologyVector:
	assert(other != null)
	return IdeologyVector.new(
		clampi(_protect_life + other.protect_life, -TASK_LIMIT, TASK_LIMIT),
		clampi(_respect_authority + other.respect_authority, -TASK_LIMIT, TASK_LIMIT),
		clampi(_seek_knowledge + other.seek_knowledge, -TASK_LIMIT, TASK_LIMIT),
		clampi(_pursue_profit + other.pursue_profit, -TASK_LIMIT, TASK_LIMIT),
		clampi(_taboo_tolerance + other.taboo_tolerance, -TASK_LIMIT, TASK_LIMIT),
		TASK_LIMIT
	)


func clamped_for_task(minimum: int = -TASK_LIMIT, maximum: int = TASK_LIMIT) -> IdeologyVector:
	assert(minimum >= -TASK_LIMIT and maximum <= TASK_LIMIT and minimum <= maximum)
	return IdeologyVector.new(
		clampi(_protect_life, minimum, maximum),
		clampi(_respect_authority, minimum, maximum),
		clampi(_seek_knowledge, minimum, maximum),
		clampi(_pursue_profit, minimum, maximum),
		clampi(_taboo_tolerance, minimum, maximum),
		TASK_LIMIT
	)


func dot(other: IdeologyVector) -> int:
	assert(other != null)
	return _protect_life * other.protect_life \
		+ _respect_authority * other.respect_authority \
		+ _seek_knowledge * other.seek_knowledge \
		+ _pursue_profit * other.pursue_profit \
		+ _taboo_tolerance * other.taboo_tolerance


static func _create_with_limit(
	p_protect_life: int,
	p_respect_authority: int,
	p_seek_knowledge: int,
	p_pursue_profit: int,
	p_taboo_tolerance: int,
	p_limit: int
) -> IdeologyVector:
	if not _validate_with_limit(
		p_protect_life,
		p_respect_authority,
		p_seek_knowledge,
		p_pursue_profit,
		p_taboo_tolerance,
		p_limit
	).is_empty():
		return null
	return IdeologyVector.new(
		p_protect_life,
		p_respect_authority,
		p_seek_knowledge,
		p_pursue_profit,
		p_taboo_tolerance,
		p_limit
	)


static func _validate_with_limit(
	p_protect_life: int,
	p_respect_authority: int,
	p_seek_knowledge: int,
	p_pursue_profit: int,
	p_taboo_tolerance: int,
	p_limit: int
) -> PackedStringArray:
	var errors := PackedStringArray()
	_append_range_error(errors, &"protect_life", p_protect_life, p_limit)
	_append_range_error(errors, &"respect_authority", p_respect_authority, p_limit)
	_append_range_error(errors, &"seek_knowledge", p_seek_knowledge, p_limit)
	_append_range_error(errors, &"pursue_profit", p_pursue_profit, p_limit)
	_append_range_error(errors, &"taboo_tolerance", p_taboo_tolerance, p_limit)
	return errors


static func _append_range_error(
	errors: PackedStringArray,
	field_name: StringName,
	value: int,
	limit: int
) -> void:
	if value < -limit or value > limit:
		errors.append("%s must be between %d and %d." % [field_name, -limit, limit])
