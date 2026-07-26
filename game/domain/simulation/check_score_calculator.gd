class_name CheckScoreCalculator
extends RefCounted

const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const ContractCheckDefinition = preload("res://game/domain/contracts/contract_check_definition.gd")
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const MissionModifier = preload("res://game/domain/contracts/mission_modifier.gd")
const TeamCapabilityCalculator = preload("res://game/domain/simulation/team_capability_calculator.gd")
const StableSeed = preload("res://game/core/random/stable_seed.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")


class ScoreResult extends RefCounted:
	var raw_score: float
	var score: int
	var check_seed: int
	var variance: int
	var capability_match: float
	var cohesion_modifier: int
	var fatigue_penalty: int
	var injury_penalty: int
	var context_modifier: int
	var reason_entries: Array[ReasonEntry]


class CohesionResult extends RefCounted:
	var score: int
	var modifier: int
	var average_pair_relationship: int
	var discipline_support: int
	var active_conflict_count: int


static func validate_relationships(
	members: Array[AdventurerSnapshot]
) -> PackedStringArray:
	var errors := PackedStringArray()
	for member: AdventurerSnapshot in members:
		if member == null:
			continue
		for target_id: StringName in member.relationship_values:
			var value: int = member.relationship_values[target_id]
			if value < -100 or value > 100:
				errors.append(
					"Relationship %s -> %s must be between -100 and 100."
					% [member.id, target_id]
				)
	return errors


static func calculate_cohesion(
	members: Array[AdventurerSnapshot],
	guild_base_cohesion: int
) -> CohesionResult:
	assert(members.size() == 4)
	assert(guild_base_cohesion >= 0 and guild_base_cohesion <= 100)
	assert(validate_relationships(members).is_empty())
	var sorted_members: Array[AdventurerSnapshot] = _sorted_members(members)
	var pair_total: float = 0.0
	var active_conflict_count: int = 0
	for first_index: int in range(sorted_members.size() - 1):
		for second_index: int in range(first_index + 1, sorted_members.size()):
			var first: AdventurerSnapshot = sorted_members[first_index]
			var second: AdventurerSnapshot = sorted_members[second_index]
			var first_relationships: Dictionary[StringName, int] = first.relationship_values
			var second_relationships: Dictionary[StringName, int] = second.relationship_values
			var first_has: bool = first_relationships.has(second.id)
			var second_has: bool = second_relationships.has(first.id)
			if first_has and second_has:
				pair_total += (first_relationships[second.id] + second_relationships[first.id]) / 2.0
			elif first_has:
				pair_total += first_relationships[second.id]
			elif second_has:
				pair_total += second_relationships[first.id]
			if (first_has and first_relationships[second.id] <= -50) \
				or (second_has and second_relationships[first.id] <= -50):
				active_conflict_count += 1

	var discipline_total: int = 0
	for member: AdventurerSnapshot in sorted_members:
		discipline_total += member.capabilities.discipline
	var result := CohesionResult.new()
	result.average_pair_relationship = roundi((pair_total / 6.0) / 5.0)
	var average_discipline: float = discipline_total / 4.0
	result.discipline_support = roundi((average_discipline - 50.0) / 10.0)
	result.active_conflict_count = active_conflict_count
	result.score = clampi(
		guild_base_cohesion
			+ result.average_pair_relationship
			+ result.discipline_support
			- active_conflict_count * 5,
		0,
		100
	)
	result.modifier = clampi(roundi((result.score - 50.0) / 5.0), -10, 10)
	return result


static func fatigue_penalty_for(fatigue: int) -> int:
	if fatigue >= 80:
		return 5
	if fatigue >= 60:
		return 3
	if fatigue >= 30:
		return 1
	return 0


static func injury_penalty_for(injury_severity: int) -> int:
	return 0 if injury_severity == 0 else int((injury_severity + 19) / 20)


static func calculate(
	check: ContractCheckDefinition,
	phase: StringName,
	members: Array[AdventurerSnapshot],
	context: MissionContext,
	previous_check_tier: StringName,
	supply_tags: Array[StringName],
	approach: StringName,
	guild_base_cohesion: int,
	contract_seed: int
) -> ScoreResult:
	var result := ScoreResult.new()
	result.capability_match = TeamCapabilityCalculator.calculate_match(
		members,
		check.capability_weights
	)
	var cohesion: CohesionResult = calculate_cohesion(members, guild_base_cohesion)
	result.cohesion_modifier = cohesion.modifier
	var reasons: Array[ReasonEntry] = []
	_append_reason(
		reasons,
		&"capability_match",
		check.id,
		&"",
		result.capability_match,
		phase
	)
	_append_reason(
		reasons,
		&"cohesion_modifier",
		check.id,
		&"",
		result.cohesion_modifier,
		phase
	)

	var context_reasons: Array[ReasonEntry] = []
	result.context_modifier = _calculate_context_modifier(
		check,
		phase,
		context,
		previous_check_tier,
		supply_tags,
		approach,
		context_reasons
	)
	reasons.append_array(context_reasons)

	for member: AdventurerSnapshot in _sorted_members(members):
		var fatigue_penalty: int = fatigue_penalty_for(member.fatigue)
		result.fatigue_penalty += fatigue_penalty
		_append_reason(
			reasons,
			&"fatigue_penalty",
			check.id,
			member.id,
			-float(fatigue_penalty),
			phase
		)
	for member: AdventurerSnapshot in _sorted_members(members):
		var injury_penalty: int = injury_penalty_for(member.injury_severity)
		result.injury_penalty += injury_penalty
		_append_reason(
			reasons,
			&"injury_penalty",
			check.id,
			member.id,
			-float(injury_penalty),
			phase
		)

	_append_reason(
		reasons,
		&"check_difficulty",
		check.id,
		&"",
		-float(check.difficulty),
		phase
	)
	var fragments: Array[StringName] = [phase, check.id]
	result.check_seed = StableSeed.derive(contract_seed, fragments)
	var random: RandomNumberGenerator = StableSeed.create_rng(contract_seed, fragments)
	result.variance = random.randi_range(-10, 10)
	_append_reason(
		reasons,
		&"seeded_variance",
		check.id,
		&"",
		float(result.variance),
		phase
	)

	result.raw_score = result.capability_match \
		+ result.cohesion_modifier \
		+ result.context_modifier \
		- result.fatigue_penalty \
		- result.injury_penalty \
		- check.difficulty \
		+ result.variance
	result.score = roundi(result.raw_score)
	var rounding_amount: float = result.score - result.raw_score
	if not is_zero_approx(rounding_amount):
		var rounding_reason: ReasonEntry = ReasonEntry.create(
			&"score_rounding",
			&"check_score",
			check.id,
			&"",
			rounding_amount,
			&"reason.score_rounding",
			{},
			phase,
			ReasonEntry.VISIBILITY_DEBUG
		)
		reasons.append(rounding_reason)
	result.reason_entries = reasons
	return result


static func _calculate_context_modifier(
	check: ContractCheckDefinition,
	phase: StringName,
	context: MissionContext,
	previous_check_tier: StringName,
	supply_tags: Array[StringName],
	approach: StringName,
	reasons: Array[ReasonEntry]
) -> int:
	var total: int = 0
	for modifier: MissionModifier in check.context_modifiers:
		var contribution: int = _evaluate_modifier(
			modifier,
			context,
			previous_check_tier,
			supply_tags,
			approach
		)
		total += contribution
		if contribution != 0:
			var parameters: Dictionary = {
				"source_check_id": check.id,
				"context_key": modifier.operand,
				"condition_type": modifier.condition_type,
			}
			reasons.append(ReasonEntry.create(
				&"context_modifier",
				&"check_score",
				check.id,
				modifier.operand,
				float(contribution),
				&"reason.context_modifier",
				parameters,
				phase,
				ReasonEntry.VISIBILITY_PLAYER
			))
	return total


static func _evaluate_modifier(
	modifier: MissionModifier,
	context: MissionContext,
	previous_check_tier: StringName,
	supply_tags: Array[StringName],
	approach: StringName
) -> int:
	var matched: bool = false
	var context_value: int = 0
	match modifier.condition_type:
		&"context_gte":
			context_value = context.get_value(modifier.operand)
			matched = context_value >= modifier.threshold
		&"context_lte":
			context_value = context.get_value(modifier.operand)
			matched = context_value <= modifier.threshold
		&"previous_check_tier_gte":
			matched = not previous_check_tier.is_empty() \
				and _tier_rank(previous_check_tier) >= _tier_rank(modifier.operand)
		&"previous_check_tier_lte":
			matched = not previous_check_tier.is_empty() \
				and _tier_rank(previous_check_tier) <= _tier_rank(modifier.operand)
		&"outcome_tag_present":
			matched = context.outcome_tags.has(modifier.operand)
		&"supply_tag_present":
			matched = supply_tags.has(modifier.operand)
		&"approach_is":
			matched = approach == modifier.operand
	if not matched:
		return 0
	var contribution: int = modifier.amount
	if modifier.per_context_point:
		contribution *= context_value
	if modifier.maximum_absolute_amount > 0:
		contribution = clampi(
			contribution,
			-modifier.maximum_absolute_amount,
			modifier.maximum_absolute_amount
		)
	return contribution


static func _tier_rank(tier: StringName) -> int:
	match tier:
		&"exceptional":
			return 4
		&"success":
			return 3
		&"partial":
			return 2
		&"failure":
			return 1
		&"severe":
			return 0
	return -1


static func _append_reason(
	reasons: Array[ReasonEntry],
	code: StringName,
	source_id: StringName,
	target_id: StringName,
	amount: float,
	phase: StringName
) -> void:
	if is_zero_approx(amount):
		return
	reasons.append(ReasonEntry.create(
		code,
		&"check_score",
		source_id,
		target_id,
		amount,
		StringName("reason.%s" % code),
		{},
		phase,
		ReasonEntry.VISIBILITY_PLAYER
	))


static func _sorted_members(
	members: Array[AdventurerSnapshot]
) -> Array[AdventurerSnapshot]:
	var by_id: Dictionary[StringName, AdventurerSnapshot] = {}
	var ids: Array[StringName] = []
	for member: AdventurerSnapshot in members:
		by_id[member.id] = member
		ids.append(member.id)
	ids.sort_custom(_stable_id_less_than)
	var result: Array[AdventurerSnapshot] = []
	for member_id: StringName in ids:
		result.append(by_id[member_id])
	return result


static func _stable_id_less_than(first: StringName, second: StringName) -> bool:
	return String(first) < String(second)
