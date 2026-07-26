class_name TeamCapabilityCalculator
extends RefCounted

const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")
const CapabilityWeights = preload("res://game/domain/contracts/capability_weights.gd")

const REQUIRED_TEAM_SIZE: int = 4


class TeamCapabilityProfile extends RefCounted:
	var frontline: float
	var offense: float
	var scouting: float
	var support: float
	var arcana: float
	var discipline: float


	func _init(
		p_frontline: float,
		p_offense: float,
		p_scouting: float,
		p_support: float,
		p_arcana: float,
		p_discipline: float
	) -> void:
		frontline = p_frontline
		offense = p_offense
		scouting = p_scouting
		support = p_support
		arcana = p_arcana
		discipline = p_discipline


static func validate_team(members: Array[AdventurerSnapshot]) -> PackedStringArray:
	var errors := PackedStringArray()
	if members.size() != REQUIRED_TEAM_SIZE:
		errors.append("Team must contain exactly %d members." % REQUIRED_TEAM_SIZE)
	var member_ids: Dictionary[StringName, bool] = {}
	for member: AdventurerSnapshot in members:
		if member == null:
			errors.append("Team cannot contain null members.")
			continue
		if member_ids.has(member.id):
			errors.append("Team member IDs must be unique.")
		member_ids[member.id] = true
	return errors


static func aggregate(members: Array[AdventurerSnapshot]) -> TeamCapabilityProfile:
	assert(validate_team(members).is_empty())
	var capability_blocks: Array[CapabilityBlock] = []
	for member: AdventurerSnapshot in members:
		capability_blocks.append(member.capabilities)

	return TeamCapabilityProfile.new(
		_aggregate_values(_frontline_values(capability_blocks)),
		_aggregate_values(_offense_values(capability_blocks)),
		_aggregate_values(_scouting_values(capability_blocks)),
		_aggregate_values(_support_values(capability_blocks)),
		_aggregate_values(_arcana_values(capability_blocks)),
		_aggregate_values(_discipline_values(capability_blocks))
	)


static func calculate_match(
	members: Array[AdventurerSnapshot],
	weights: CapabilityWeights
) -> float:
	assert(weights != null)
	var profile: TeamCapabilityProfile = aggregate(members)
	return profile.frontline * weights.frontline \
		+ profile.offense * weights.offense \
		+ profile.scouting * weights.scouting \
		+ profile.support * weights.support \
		+ profile.arcana * weights.arcana \
		+ profile.discipline * weights.discipline


static func _aggregate_values(values: Array[int]) -> float:
	assert(values.size() == REQUIRED_TEAM_SIZE)
	values.sort()
	values.reverse()
	var remaining_average: float = (values[2] + values[3]) / 2.0
	return values[0] * 0.55 + values[1] * 0.25 + remaining_average * 0.20


static func _frontline_values(blocks: Array[CapabilityBlock]) -> Array[int]:
	var values: Array[int] = []
	for block: CapabilityBlock in blocks:
		values.append(block.frontline)
	return values


static func _offense_values(blocks: Array[CapabilityBlock]) -> Array[int]:
	var values: Array[int] = []
	for block: CapabilityBlock in blocks:
		values.append(block.offense)
	return values


static func _scouting_values(blocks: Array[CapabilityBlock]) -> Array[int]:
	var values: Array[int] = []
	for block: CapabilityBlock in blocks:
		values.append(block.scouting)
	return values


static func _support_values(blocks: Array[CapabilityBlock]) -> Array[int]:
	var values: Array[int] = []
	for block: CapabilityBlock in blocks:
		values.append(block.support)
	return values


static func _arcana_values(blocks: Array[CapabilityBlock]) -> Array[int]:
	var values: Array[int] = []
	for block: CapabilityBlock in blocks:
		values.append(block.arcana)
	return values


static func _discipline_values(blocks: Array[CapabilityBlock]) -> Array[int]:
	var values: Array[int] = []
	for block: CapabilityBlock in blocks:
		values.append(block.discipline)
	return values
