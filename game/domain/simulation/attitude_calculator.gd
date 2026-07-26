class_name AttitudeCalculator
extends RefCounted

const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const MethodTagDefinition = preload("res://game/domain/contracts/method_tag_definition.gd")
const ContractClauseDefinition = preload("res://game/domain/contracts/contract_clause_definition.gd")
const TraceCondition = preload("res://game/domain/contracts/trace_condition.gd")
const AttitudeResult = preload("res://game/domain/contracts/attitude_result.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")

const TRAITS: Array[StringName] = [
	&"cautious",
	&"ambitious",
	&"compassionate",
	&"ruthless",
	&"loyal",
	&"independent",
	&"scholarly",
	&"devout",
]


static func planning_tags(contract: EffectiveContract) -> Array[StringName]:
	var tags: Array[StringName] = []
	for tag: StringName in contract.expected_method_tags:
		_append_unique(tags, tag)
	for clause: ContractClauseDefinition in contract.clauses:
		if clause == null:
			continue
		for condition: TraceCondition in clause.all_conditions:
			if condition != null and condition.type == &"method_tag_used":
				_append_unique(tags, condition.tag_value)
	return tags


static func expected_ideology(contract: EffectiveContract) -> IdeologyVector:
	var vectors: Array[IdeologyVector] = []
	vectors.append(contract.intent_ideology_vector)
	for clause: ContractClauseDefinition in contract.clauses:
		if clause != null:
			vectors.append(clause.success_ideology_impact)
	var dimensions: Array = [
		[],
		[],
		[],
		[],
		[],
	]
	for vector: IdeologyVector in vectors:
		dimensions[0].append(vector.protect_life)
		dimensions[1].append(vector.respect_authority)
		dimensions[2].append(vector.seek_knowledge)
		dimensions[3].append(vector.pursue_profit)
		dimensions[4].append(vector.taboo_tolerance)
	var values: Array[int] = []
	for dimension: Array in dimensions:
		var strongest_positive: int = 0
		var strongest_negative: int = 0
		for raw_value: Variant in dimension:
			var value: int = int(raw_value)
			strongest_positive = maxi(strongest_positive, value)
			strongest_negative = mini(strongest_negative, value)
		values.append(clampi(strongest_positive + strongest_negative, -10, 10))
	return IdeologyVector.create_task_accumulation(
		values[0],
		values[1],
		values[2],
		values[3],
		values[4]
	)


static func calculate_planning(
	contract: EffectiveContract,
	member: AdventurerSnapshot
) -> AttitudeResult:
	return _calculate(contract, member, planning_tags(contract), null)


static func calculate_for_check(
	contract: EffectiveContract,
	member: AdventurerSnapshot,
	actual_method_tags: Array[StringName],
	locked_planning: AttitudeResult
) -> AttitudeResult:
	return _calculate(contract, member, actual_method_tags, locked_planning)


static func check_modifier(attitudes: Array[AttitudeResult]) -> float:
	var total: int = 0
	for attitude: AttitudeResult in attitudes:
		match attitude.status:
			&"enthusiastic":
				total += 2
			&"reluctant":
				total -= 3
			&"opposed":
				total -= 6
	return total / 4.0


static func validate_content(contract: EffectiveContract) -> PackedStringArray:
	var errors := PackedStringArray()
	var definitions := _definition_map(contract.method_tag_definitions)
	var referenced_tags: Array[StringName] = planning_tags(contract)
	for stage in contract.stages:
		if stage != null and stage.check != null:
			for tag: StringName in stage.check.method_tags:
				_append_unique(referenced_tags, tag)
	for clause: ContractClauseDefinition in contract.clauses:
		if clause == null:
			continue
		for condition: TraceCondition in clause.all_conditions:
			if condition != null \
				and (condition.type == &"method_tag_used" \
				or condition.type == &"method_tag_not_used"):
				_append_unique(referenced_tags, condition.tag_value)
	for tag: StringName in referenced_tags:
		if tag.is_empty():
			errors.append("Method tag cannot be empty.")
		elif not definitions.has(tag):
			errors.append("Missing MethodTagDefinition for %s." % tag)
	for definition: MethodTagDefinition in contract.method_tag_definitions:
		if definition == null:
			errors.append("MethodTagDefinition cannot be null.")
			continue
		var expected_intensity: int = taboo_intensity_for(definition.id)
		if definition.taboo_intensity != expected_intensity:
			errors.append(
				"MethodTagDefinition %s taboo_intensity must be %d."
				% [definition.id, expected_intensity]
			)
	return errors


static func validate_member_traits(member: AdventurerSnapshot) -> PackedStringArray:
	var errors := PackedStringArray()
	for trait_id: StringName in member.traits:
		if not TRAITS.has(trait_id):
			errors.append("Unknown adventurer trait: %s." % trait_id)
	return errors


static func taboo_intensity_for(tag: StringName) -> int:
	if tag == &"necromancy" or tag == &"sacrifice":
		return 2
	if tag == &"coercion" \
		or tag == &"corpse_handling" \
		or tag == &"preservation" \
		or tag == &"smuggling":
		return 1
	return 0


static func status_for(score: int) -> StringName:
	if score >= 40:
		return &"enthusiastic"
	if score >= 10:
		return &"supportive"
	if score >= -9:
		return &"neutral"
	if score >= -39:
		return &"reluctant"
	return &"opposed"


static func _calculate(
	contract: EffectiveContract,
	member: AdventurerSnapshot,
	method_tags: Array[StringName],
	locked_planning: AttitudeResult
) -> AttitudeResult:
	var reasons: Array[ReasonEntry] = []
	var ideology_fit: int = (
		locked_planning.ideology_fit
		if locked_planning != null
		else clampi(roundi(member.values.dot(expected_ideology(contract)) / 5.0), -40, 40)
	)
	var personal_fit: int = (
		locked_planning.personal_fit
		if locked_planning != null
		else _personal_fit(contract, member, reasons)
	)
	if locked_planning == null and ideology_fit != 0:
		reasons.append(_reason(
			&"attitude_ideology_fit",
			&"ideology",
			contract.definition_id,
			member.id,
			ideology_fit
		))
	var method_fit: int = _method_fit(
		member,
		method_tags,
		_definition_map(contract.method_tag_definitions),
		reasons
	)
	var score: int = ideology_fit + method_fit + personal_fit
	var status: StringName = status_for(score)
	var forced: bool = status == &"opposed" and member.morale > 20
	if forced:
		reasons.append(_reason(
			&"forced_opposed_assignment",
			&"attitude",
			contract.definition_id,
			member.id,
			0
		))
	return AttitudeResult.create(
		member.id,
		ideology_fit,
		method_fit,
		personal_fit,
		score,
		status,
		forced,
		reasons
	)


static func _method_fit(
	member: AdventurerSnapshot,
	method_tags: Array[StringName],
	definitions: Dictionary,
	reasons: Array[ReasonEntry]
) -> int:
	var unique_tags: Array[StringName] = []
	for tag: StringName in method_tags:
		_append_unique(unique_tags, tag)
	var total: int = 0
	for trait_id: StringName in member.traits:
		for tag: StringName in unique_tags:
			var amount: int = _trait_tag_amount(trait_id, tag)
			total += amount
			if amount != 0:
				reasons.append(_reason(
					&"attitude_trait_method",
					&"method",
					trait_id,
					member.id,
					amount,
					{"method_tag": tag}
				))
	for tag: StringName in unique_tags:
		var definition: MethodTagDefinition = definitions.get(tag)
		if definition == null:
			continue
		var taboo_amount: int = member.values.taboo_tolerance * definition.taboo_intensity
		total += taboo_amount
		if taboo_amount != 0:
			reasons.append(_reason(
				&"attitude_taboo_method",
				&"method",
				tag,
				member.id,
				taboo_amount
			))
	return clampi(total, -30, 20)


static func _personal_fit(
	contract: EffectiveContract,
	member: AdventurerSnapshot,
	reasons: Array[ReasonEntry]
) -> int:
	var reward_ratio: float = (contract.offered_reward / 4.0) / member.wage
	var reward_fit: int = -3 if reward_ratio < 1.0 else (
		0 if reward_ratio < 2.0 else (2 if reward_ratio < 3.0 else 4)
	)
	var maximum_difficulty: int = 0
	for stage in contract.stages:
		if stage != null and stage.check != null:
			maximum_difficulty = maxi(maximum_difficulty, stage.check.difficulty)
	var growth_fit: int = 0 if maximum_difficulty <= 24 else (
		1 if maximum_difficulty <= 29 else (2 if maximum_difficulty <= 34 else 3)
	)
	var relation: int = contract.sponsor_relation_snapshot
	var sponsor_fit: int = -4 if relation <= -50 else (
		-2 if relation <= -10 else (0 if relation <= 24 else (2 if relation <= 59 else 4))
	)
	var neglect: int = member.recent_neglect_count
	var neglect_fit: int = 0 if neglect == 0 else (1 if neglect == 1 else (3 if neglect == 2 else 5))
	var trait_risk: int = 0
	if contract.risk_level >= 3:
		for trait_id: StringName in member.traits:
			if trait_id == &"cautious":
				trait_risk -= 2
			elif trait_id == &"ambitious" or trait_id == &"ruthless":
				trait_risk += 2
	trait_risk = clampi(trait_risk, -2, 2)
	var risk_fit: int = -(contract.risk_level - 1) + trait_risk
	var severity: int = member.injury_severity
	var injury_fit: int = 0 if severity == 0 else (
		-1 if severity <= 20 else (-2 if severity <= 40 else (-4 if severity <= 60 else -6))
	)
	var components: Array[Dictionary] = [
		{"code": &"attitude_reward_fit", "amount": reward_fit},
		{"code": &"attitude_growth_fit", "amount": growth_fit},
		{"code": &"attitude_sponsor_fit", "amount": sponsor_fit},
		{"code": &"attitude_neglect_fit", "amount": neglect_fit},
		{"code": &"attitude_risk_fit", "amount": risk_fit},
		{"code": &"attitude_injury_fit", "amount": injury_fit},
	]
	for component: Dictionary in components:
		var amount: int = component["amount"]
		if amount != 0:
			reasons.append(_reason(
				component["code"],
				&"personal",
				contract.definition_id,
				member.id,
				amount
			))
	return clampi(
		reward_fit + growth_fit + sponsor_fit + neglect_fit + risk_fit + injury_fit,
		-20,
		20
	)


static func _trait_tag_amount(trait_id: StringName, tag: StringName) -> int:
	var preferred: bool = false
	var opposed: bool = false
	match trait_id:
		&"cautious":
			preferred = [&"scouting", &"reconnaissance", &"stealth", &"protection", &"nonlethal", &"extraction"].has(tag)
			opposed = [&"confrontation", &"direct_assault", &"coercion", &"sacrifice"].has(tag)
		&"ambitious":
			preferred = [&"confrontation", &"direct_assault", &"capture", &"research", &"ritual"].has(tag)
		&"compassionate":
			preferred = [&"rescue", &"protection", &"evacuation", &"medical", &"nonlethal"].has(tag)
			opposed = [&"coercion", &"sacrifice", &"necromancy", &"corpse_handling"].has(tag)
		&"ruthless":
			preferred = [&"confrontation", &"direct_assault", &"coercion", &"sacrifice", &"necromancy", &"smuggling"].has(tag)
			opposed = [&"rescue", &"nonlethal"].has(tag)
		&"loyal":
			preferred = [&"protection", &"rescue", &"evacuation"].has(tag)
			opposed = [&"deception", &"smuggling"].has(tag)
		&"independent":
			preferred = [&"scouting", &"stealth", &"deception", &"smuggling", &"salvage"].has(tag)
			opposed = tag == &"coercion"
		&"scholarly":
			preferred = [&"research", &"ritual", &"binding", &"preservation", &"capture"].has(tag)
			opposed = [&"direct_assault", &"sacrifice"].has(tag)
		&"devout":
			preferred = [&"rescue", &"protection", &"ritual", &"nonlethal"].has(tag)
			opposed = [&"necromancy", &"corpse_handling", &"sacrifice", &"deception"].has(tag)
	return 3 if preferred else (-4 if opposed else 0)


static func _definition_map(
	definitions: Array[MethodTagDefinition]
) -> Dictionary:
	var result: Dictionary = {}
	for definition: MethodTagDefinition in definitions:
		if definition != null:
			result[definition.id] = definition
	return result


static func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not values.has(value):
		values.append(value)


static func _reason(
	code: StringName,
	category: StringName,
	source_id: StringName,
	target_id: StringName,
	amount: float,
	parameters: Dictionary = {}
) -> ReasonEntry:
	return ReasonEntry.create(
		code,
		category,
		source_id,
		target_id,
		amount,
		&"",
		parameters,
		&"planning",
		ReasonEntry.VISIBILITY_PLAYER
	)
