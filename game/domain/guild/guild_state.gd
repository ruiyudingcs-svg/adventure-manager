class_name GuildState
extends RefCounted

const STATUS_MIN: int = 0
const STATUS_MAX: int = 100

var gold: int
var reputation: int
var base_cohesion: int
var weekly_maintenance: int


static func create(
	p_gold: int,
	p_reputation: int,
	p_base_cohesion: int,
	p_weekly_maintenance: int
) -> GuildState:
	if not validate_values(
		p_gold,
		p_reputation,
		p_base_cohesion,
		p_weekly_maintenance
	).is_empty():
		return null
	return GuildState.new(
		p_gold,
		p_reputation,
		p_base_cohesion,
		p_weekly_maintenance
	)


func _init(
	p_gold: int,
	p_reputation: int,
	p_base_cohesion: int,
	p_weekly_maintenance: int
) -> void:
	gold = p_gold
	reputation = p_reputation
	base_cohesion = p_base_cohesion
	weekly_maintenance = p_weekly_maintenance


static func validate_values(
	p_gold: int,
	p_reputation: int,
	p_base_cohesion: int,
	p_weekly_maintenance: int
) -> PackedStringArray:
	var errors := PackedStringArray()
	if p_gold < 0:
		errors.append("GuildState.gold must be non-negative.")
	if p_reputation < STATUS_MIN or p_reputation > STATUS_MAX:
		errors.append("GuildState.reputation must be between 0 and 100.")
	if p_base_cohesion < STATUS_MIN or p_base_cohesion > STATUS_MAX:
		errors.append("GuildState.base_cohesion must be between 0 and 100.")
	if p_weekly_maintenance < 0:
		errors.append("GuildState.weekly_maintenance must be non-negative.")
	return errors


func validate() -> PackedStringArray:
	return validate_values(gold, reputation, base_cohesion, weekly_maintenance)


func duplicate_state() -> GuildState:
	return GuildState.new(gold, reputation, base_cohesion, weekly_maintenance)
