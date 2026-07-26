class_name ContractResolverFixtures
extends RefCounted

const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const AdventurerDefinition = preload("res://game/domain/adventurers/adventurer_definition.gd")
const AdventurerState = preload("res://game/domain/adventurers/adventurer_state.gd")
const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const RelationshipDefinition = preload("res://game/domain/adventurers/relationship_definition.gd")
const CapabilityWeights = preload("res://game/domain/contracts/capability_weights.gd")
const MissionContext = preload("res://game/domain/contracts/mission_context.gd")
const MissionModifier = preload("res://game/domain/contracts/mission_modifier.gd")
const MemberEffect = preload("res://game/domain/contracts/member_effect.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")
const CheckOutcomeDefinition = preload("res://game/domain/contracts/check_outcome_definition.gd")
const CheckOutcomeTable = preload("res://game/domain/contracts/check_outcome_table.gd")
const ContractCheckDefinition = preload("res://game/domain/contracts/contract_check_definition.gd")
const ContractStageDefinition = preload("res://game/domain/contracts/contract_stage_definition.gd")
const EffectiveContract = preload("res://game/domain/contracts/effective_contract.gd")
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const SupplyDefinition = preload("res://game/domain/contracts/supply_definition.gd")
const MethodTagDefinition = preload("res://game/domain/contracts/method_tag_definition.gd")
const ContractClauseDefinition = preload("res://game/domain/contracts/contract_clause_definition.gd")
const TraceCondition = preload("res://game/domain/contracts/trace_condition.gd")
const ContractEffect = preload("res://game/domain/contracts/contract_effect.gd")
const ContractOutcomeDefinition = preload("res://game/domain/contracts/contract_outcome_definition.gd")
const ContractOutcomeTable = preload("res://game/domain/contracts/contract_outcome_table.gd")

const BASELINE_SEED: int = 32772
const BASELINE_GUILD_COHESION: int = 45


static func create_baseline_request() -> Dictionary:
	var members: Array[AdventurerSnapshot] = create_team()
	var supplies: Array[SupplyDefinition] = []
	return {
		"contract": create_north_road_contract(),
		"plan": ContractPlan.create(members, supplies, &"balanced"),
		"seed": BASELINE_SEED,
		"guild_base_cohesion": BASELINE_GUILD_COHESION,
	}


static func create_team(
	fatigues: Array[int] = [0, 0, 0, 0],
	injuries: Array[int] = [0, 0, 0, 0],
	relationships_by_member: Dictionary = {},
	capabilities: CapabilityBlock = null
) -> Array[AdventurerSnapshot]:
	var effective_capabilities: CapabilityBlock = capabilities
	if effective_capabilities == null:
		effective_capabilities = CapabilityBlock.create(99, 78, 78, 46, 50, 100)
	var member_ids: Array[StringName] = [
		&"resolver_alpha",
		&"resolver_bravo",
		&"resolver_charlie",
		&"resolver_delta",
	]
	var members: Array[AdventurerSnapshot] = []
	for index: int in range(member_ids.size()):
		var member_relationships: Dictionary[StringName, int] = {}
		var raw_relationships: Dictionary = relationships_by_member.get(member_ids[index], {})
		for target_id: StringName in raw_relationships:
			member_relationships[target_id] = raw_relationships[target_id]
		members.append(_create_snapshot(
			member_ids[index],
			effective_capabilities,
			fatigues[index],
			injuries[index],
			member_relationships
		))
	return members


static func create_north_road_contract() -> EffectiveContract:
	var stages: Array[ContractStageDefinition] = [
		ContractStageDefinition.create(
			&"stage_evac_approach",
			&"approach",
			ContractCheckDefinition.create(
				&"evac_find_safe_route",
				&"navigation",
				CapabilityWeights.create(0.10, 0.0, 0.55, 0.15, 0.0, 0.20),
				22,
				0.15,
				&"partial",
				_names([&"scouting", &"rescue"]),
				_modifiers([]),
				&"careful",
				_route_outcomes()
			)
		),
		ContractStageDefinition.create(
			&"stage_evac_main",
			&"main_action",
			ContractCheckDefinition.create(
				&"evac_secure_column",
				&"protection",
				CapabilityWeights.create(0.45, 0.10, 0.0, 0.25, 0.0, 0.20),
				30,
				0.30,
				&"partial",
				_names([&"protection", &"nonlethal"]),
				_modifiers([
					MissionModifier.context_per_point(&"route_safety", 2, 6),
					MissionModifier.context_per_point(&"enemy_pressure", -2),
				]),
				&"careful",
				_column_outcomes()
			)
		),
		ContractStageDefinition.create(
			&"stage_evac_special",
			&"special_objective",
			ContractCheckDefinition.create(
				&"evac_recover_stragglers",
				&"rescue",
				CapabilityWeights.create(0.15, 0.0, 0.20, 0.40, 0.0, 0.25),
				26,
				0.25,
				&"partial",
				_names([&"rescue", &"medical"]),
				_modifiers([
					MissionModifier.context_per_point(&"intel", 2, 6),
					MissionModifier.context_per_point(&"time_pressure", -2),
				]),
				&"careful",
				_straggler_outcomes()
			)
		),
		ContractStageDefinition.create(
			&"stage_evac_extraction",
			&"extraction",
			ContractCheckDefinition.create(
				&"evac_move_column_out",
				&"extraction",
				CapabilityWeights.create(0.20, 0.0, 0.25, 0.25, 0.0, 0.30),
				28,
				0.30,
				&"failure",
				_names([&"evacuation", &"protection"]),
				_modifiers([
					MissionModifier.context_per_point(&"route_safety", 2),
					MissionModifier.context_per_point(&"protected_civilians", 1, 4),
					MissionModifier.context_per_point(&"time_pressure", -2),
					MissionModifier.context_per_point(&"extraction_pressure", -3),
				]),
				&"careful",
				_extraction_outcomes()
			)
		),
	]
	var initial_deltas: Array[Dictionary] = []
	return EffectiveContract.create_complete(
		&"offer_north_road_fixture",
		&"contract_north_road_evacuation",
		220,
		12,
		2,
		0,
		IdeologyVector.create_task_accumulation(4, 1, 0, 0, -1),
		_names([&"rescue", &"protection", &"evacuation"]),
		_names([&"medical", &"scouting", &"protection", &"rations"]),
		stages,
		_north_road_clauses(),
		initial_deltas,
		_north_road_final_outcomes(),
		_method_definitions(_names([
			&"scouting",
			&"rescue",
			&"protection",
			&"nonlethal",
			&"medical",
			&"evacuation",
		]))
	)


static func _north_road_clauses() -> Array[ContractClauseDefinition]:
	var clauses: Array[ContractClauseDefinition] = []
	clauses.append(ContractClauseDefinition.create(
		&"evac_no_wounded_abandoned",
		&"target_state",
		&"mandatory",
		[TraceCondition.create(&"outcome_tag_present", &"", &"", 0, &"all_stragglers_recovered")],
		[],
		[ContractEffect.create(&"modify_reward_percent", -20), ContractEffect.create(&"modify_sponsor_relation", -6)],
		&"partial",
		IdeologyVector.create_task_accumulation(1, 0, 0, 0, 0),
		IdeologyVector.create_task_accumulation(-3, 0, 0, 0, 0),
		_names([&"clause.humane_evacuation"]),
		[],
		10
	))
	clauses.append(ContractClauseDefinition.create(
		&"evac_collateral_limit",
		&"collateral",
		&"mandatory",
		[TraceCondition.create(&"context_lte", &"", &"collateral_pressure", 2)],
		[ContractEffect.create(&"modify_sponsor_relation", 2)],
		[ContractEffect.create(&"modify_sponsor_relation", -4)],
		&"",
		IdeologyVector.create_task_accumulation(0, 0, 0, 0, 0),
		IdeologyVector.create_task_accumulation(0, 0, 0, 0, 0),
		[],
		_names([&"clause.excessive_destruction"]),
		20
	))
	clauses.append(ContractClauseDefinition.create(
		&"evac_no_heavy_injury",
		&"personnel_safety",
		&"bonus",
		[TraceCondition.create(&"member_heavy_injury_count_lte", &"", &"", 0)],
		[ContractEffect.create(&"modify_reward_percent", 10), ContractEffect.create(&"modify_sponsor_relation", 2)],
		[],
		&"",
		IdeologyVector.create_task_accumulation(0, 0, 0, 0, 0),
		IdeologyVector.create_task_accumulation(0, 0, 0, 0, 0),
		[],
		[],
		30
	))
	return clauses


static func _north_road_final_outcomes() -> ContractOutcomeTable:
	return _final_outcomes([
		[1.25, 0.90, -10, 8, [&"contract.exceptional", &"evacuation.heroic"]],
		[1.00, 1.00, -5, 5, [&"contract.success"]],
		[0.65, 1.10, 0, 1, [&"contract.partial"]],
		[0.25, 1.25, 10, -4, [&"contract.failure"]],
		[0.00, 1.40, 20, -8, [&"contract.severe_failure"]],
	])


static func _final_outcomes(rows: Array) -> ContractOutcomeTable:
	var outcomes: Array[ContractOutcomeDefinition] = []
	var empty_world: Array[WorldEffect] = []
	for row: Array in rows:
		outcomes.append(ContractOutcomeDefinition.create(
			row[0],
			row[1],
			row[2],
			row[3],
			empty_world,
			_names(row[4])
		))
	return ContractOutcomeTable.create(
		outcomes[0],
		outcomes[1],
		outcomes[2],
		outcomes[3],
		outcomes[4]
	)


static func _method_definitions(tags: Array[StringName]) -> Array[MethodTagDefinition]:
	var definitions: Array[MethodTagDefinition] = []
	for tag: StringName in tags:
		definitions.append(MethodTagDefinition.create(
			tag,
			IdeologyVector.create_task_accumulation(0, 0, 0, 0, 0),
			0
		))
	return definitions


static func _create_snapshot(
	member_id: StringName,
	capabilities: CapabilityBlock,
	fatigue: int,
	injury: int,
	relationships: Dictionary[StringName, int]
) -> AdventurerSnapshot:
	var traits: Array[StringName] = []
	var starting_relationships: Array[RelationshipDefinition] = []
	var definition: AdventurerDefinition = AdventurerDefinition.create(
		member_id,
		String(member_id),
		&"resolver_fixture_class",
		capabilities,
		IdeologyVector.create_base(0, 0, 0, 0, 0),
		traits,
		starting_relationships
	)
	var state: AdventurerState = AdventurerState.create(
		member_id,
		fatigue,
		60,
		injury,
		0,
		0,
		true,
		relationships
	)
	return AdventurerSnapshot.create(definition, state)


static func _route_outcomes() -> CheckOutcomeTable:
	return CheckOutcomeTable.create(
		_outcome(
			_deltas([[&"route_safety", 3], [&"intel", 2]]),
			_world([[&"settlement_destruction", 0]]),
			0,
			_names([&"route_mastered"]),
			1
		),
		_outcome(
			_deltas([[&"route_safety", 2], [&"intel", 1]]),
			_world([[&"settlement_destruction", 1]]),
			0,
			_names([&"route_secured"]),
			1
		),
		_outcome(
			_deltas([[&"route_safety", 1], [&"time_pressure", 1]]),
			_world([[&"settlement_destruction", 2]]),
			0,
			_names([&"route_uncertain"]),
			0
		),
		_outcome(
			_deltas([[&"time_pressure", 2], [&"enemy_pressure", 1]]),
			_world([[&"settlement_destruction", 4]]),
			5,
			_names([&"route_delayed"]),
			0
		),
		_outcome(
			_deltas([
				[&"route_safety", -1],
				[&"time_pressure", 3],
				[&"enemy_pressure", 2],
			]),
			_world([[&"settlement_destruction", 6]]),
			10,
			_names([&"route_compromised"]),
			-1
		)
	)


static func _column_outcomes() -> CheckOutcomeTable:
	return CheckOutcomeTable.create(
		_outcome(
			_deltas([[&"protected_civilians", 3], [&"enemy_pressure", -2]]),
			_world([
				[&"settlement_destruction", 0],
				[&"dragon_exhaustion", 2],
			]),
			0,
			_names([&"column_secure"]),
			1
		),
		_outcome(
			_deltas([[&"protected_civilians", 2], [&"enemy_pressure", -1]]),
			_world([
				[&"settlement_destruction", 1],
				[&"dragon_exhaustion", 1],
			]),
			3,
			_names([&"column_protected"]),
			1
		),
		_outcome(
			_deltas([[&"protected_civilians", 1], [&"team_strain", 1]]),
			_world([[&"settlement_destruction", 3]]),
			8,
			_names([&"column_disrupted"]),
			0
		),
		_outcome(
			_deltas([[&"collateral_pressure", 2], [&"team_strain", 2]]),
			_world([[&"settlement_destruction", 6]]),
			15,
			_names([&"civilians_exposed"]),
			-1
		),
		_outcome(
			_deltas([[&"collateral_pressure", 3], [&"extraction_pressure", 2]]),
			_world([[&"settlement_destruction", 9]]),
			25,
			_names([&"column_broken"]),
			-2
		)
	)


static func _straggler_outcomes() -> CheckOutcomeTable:
	return CheckOutcomeTable.create(
		_outcome(
			_deltas([[&"protected_civilians", 4]]),
			_world([[&"settlement_destruction", 0]]),
			0,
			_names([&"all_stragglers_recovered"]),
			2
		),
		_outcome(
			_deltas([[&"protected_civilians", 3], [&"time_pressure", 1]]),
			_world([[&"settlement_destruction", 1]]),
			3,
			_names([&"all_stragglers_recovered"]),
			2
		),
		_outcome(
			_deltas([[&"protected_civilians", 2], [&"time_pressure", 2]]),
			_world([[&"settlement_destruction", 2]]),
			8,
			_names([&"some_stragglers_recovered"]),
			1
		),
		_outcome(
			_deltas([
				[&"protected_civilians", 1],
				[&"time_pressure", 2],
				[&"collateral_pressure", 1],
			]),
			_world([
				[&"settlement_destruction", 4],
				[&"necrotic_corruption", 1],
			]),
			12,
			_names([&"stragglers_abandoned"]),
			-2
		),
		_outcome(
			_deltas([[&"collateral_pressure", 2], [&"extraction_pressure", 1]]),
			_world([
				[&"settlement_destruction", 6],
				[&"necrotic_corruption", 3],
			]),
			20,
			_names([&"stragglers_lost"]),
			-3
		)
	)


static func _extraction_outcomes() -> CheckOutcomeTable:
	var no_deltas: Array[Dictionary] = []
	return CheckOutcomeTable.create(
		_outcome(
			no_deltas,
			_world([
				[&"villagers_evacuated", 24],
				[&"settlement_destruction", 2],
				[&"dragon_exhaustion", 4],
				[&"necrotic_corruption", -3],
			]),
			0,
			_names([&"evacuation_complete"]),
			2
		),
		_outcome(
			no_deltas,
			_world([
				[&"villagers_evacuated", 18],
				[&"settlement_destruction", 5],
				[&"dragon_exhaustion", 2],
			]),
			3,
			_names([&"evacuation_success"]),
			2
		),
		_outcome(
			no_deltas,
			_world([
				[&"villagers_evacuated", 10],
				[&"settlement_destruction", 10],
				[&"necrotic_corruption", 2],
			]),
			8,
			_names([&"evacuation_partial"]),
			1
		),
		_outcome(
			no_deltas,
			_world([
				[&"villagers_evacuated", 3],
				[&"settlement_destruction", 16],
				[&"necrotic_corruption", 5],
			]),
			15,
			_names([&"evacuation_failed"]),
			-2
		),
		_outcome(
			no_deltas,
			_world([
				[&"villagers_evacuated", 0],
				[&"settlement_destruction", 24],
				[&"dragon_exhaustion", -2],
				[&"necrotic_corruption", 10],
			]),
			25,
			_names([&"evacuation_disaster"]),
			-4
		)
	)


static func _outcome(
	deltas: Array[Dictionary],
	world_effects: Array[WorldEffect],
	injury_risk: int,
	tags: Array[StringName],
	protect_life: int
) -> CheckOutcomeDefinition:
	var member_effects: Array[MemberEffect] = []
	if injury_risk != 0:
		member_effects.append(MemberEffect.create(
			&"",
			&"injury_risk",
			injury_risk,
			&"check_injury_risk"
		))
	return CheckOutcomeDefinition.create(
		deltas,
		member_effects,
		world_effects,
		IdeologyVector.create_task_accumulation(protect_life, 0, 0, 0, 0),
		tags
	)


static func _deltas(raw_values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_value: Array in raw_values:
		result.append(MissionContext.create_delta(raw_value[0], raw_value[1], &"fixture"))
	return result


static func _world(raw_values: Array) -> Array[WorldEffect]:
	var result: Array[WorldEffect] = []
	for raw_value: Array in raw_values:
		result.append(WorldEffect.create(
			&"modify_clock",
			raw_value[0],
			raw_value[1],
			&"north_road_check_outcome"
		))
	return result


static func _names(raw_values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_value: StringName in raw_values:
		result.append(raw_value)
	return result


static func _modifiers(raw_values: Array) -> Array[MissionModifier]:
	var result: Array[MissionModifier] = []
	for raw_value: MissionModifier in raw_values:
		result.append(raw_value)
	return result
