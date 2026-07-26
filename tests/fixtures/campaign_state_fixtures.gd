class_name CampaignStateFixtures
extends RefCounted

const AdventurerState = preload(
	"res://game/domain/adventurers/adventurer_state.gd"
)
const GuildState = preload("res://game/domain/guild/guild_state.gd")
const FactionState = preload("res://game/domain/factions/faction_state.gd")
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const CampaignState = preload(
	"res://game/domain/campaign/campaign_state.gd"
)
const CatalogContentFixtures = preload(
	"res://tests/fixtures/catalog_content_fixtures.gd"
)


static func create_baseline_state(gold: int = 1000) -> CampaignState:
	var catalog = CatalogContentFixtures.create_catalog()
	var adventurers: Dictionary[StringName, AdventurerState] = {}
	for snapshot in CatalogContentFixtures.create_baseline_team():
		adventurers[snapshot.id] = AdventurerState.create(
			snapshot.id,
			snapshot.fatigue,
			snapshot.morale,
			snapshot.injury_severity,
			snapshot.recovery_weeks_remaining,
			snapshot.growth_xp,
			snapshot.is_available,
			{},
			snapshot.recent_assignment_count,
			snapshot.recent_neglect_count
		)

	var factions: Dictionary[StringName, FactionState] = {}
	for definition in catalog.get_all_factions():
		factions[definition.id] = FactionState.create(definition.id, 0, 50)

	var clocks: Dictionary[StringName, int] = {}
	for definition in catalog.get_all_clocks():
		clocks[definition.id] = definition.initial_value
	var problems: Dictionary[StringName, WorldProblemState] = {}
	for definition in catalog.get_all_problems():
		problems[definition.id] = WorldProblemState.create(definition.id)
	var situation_definition = catalog.get_all_situations()[0]
	var situation := SituationState.create(
		situation_definition.id,
		situation_definition.initial_phase,
		clocks,
		[],
		[],
		problems
	)
	return CampaignState.create(
		424242,
		1,
		GuildState.create(gold, 50, 60, 25),
		adventurers,
		factions,
		situation
	)


static func sponsor_for_contract(contract_definition_id: StringName) -> StringName:
	match contract_definition_id:
		&"contract_north_road_evacuation":
			return &"faction_free_adventurers"
		&"contract_deploy_binding_towers":
			return &"faction_arcane_guild"
		&"contract_recover_intact_corpses":
			return &"faction_necrotic_collective"
	return &""


static func state_signature(state: CampaignState) -> String:
	var member_parts := PackedStringArray()
	var member_ids: Array[StringName] = []
	member_ids.assign(state.adventurers.keys())
	member_ids.sort()
	for member_id: StringName in member_ids:
		var member: AdventurerState = state.adventurers[member_id]
		member_parts.append("%s:%d:%d:%d:%d:%s:%d:%d" % [
			member_id,
			member.get_fatigue(),
			member.get_morale(),
			member.get_injury_severity(),
			member.get_recovery_weeks_remaining(),
			member.get_is_available(),
			member.get_recent_assignment_count(),
			member.get_recent_neglect_count(),
		])
	var faction_parts := PackedStringArray()
	var faction_ids: Array[StringName] = []
	faction_ids.assign(state.factions.keys())
	faction_ids.sort()
	for faction_id: StringName in faction_ids:
		var faction: FactionState = state.factions[faction_id]
		faction_parts.append("%s:%d:%d" % [
			faction_id,
			faction.relation,
			faction.influence,
		])
	var clock_parts := PackedStringArray()
	var clock_ids: Array[StringName] = []
	clock_ids.assign(state.situation.clock_values.keys())
	clock_ids.sort()
	for clock_id: StringName in clock_ids:
		clock_parts.append("%s:%d" % [
			clock_id,
			state.situation.clock_values[clock_id],
		])
	var offer_parts := PackedStringArray()
	for offer in state.pending_contracts:
		offer_parts.append(
			"<null>" if offer == null else offer.content_signature()
		)
	var plan_signature: String = (
		""
		if state.active_plan == null
		else state.active_plan.content_signature()
	)
	var commitment_parts := PackedStringArray()
	for commitment in state.faction_action_commitments:
		commitment_parts.append(
			"<null>" if commitment == null else commitment.content_signature()
		)
	var message_parts := PackedStringArray()
	for message in state.message_history:
		message_parts.append(
			"<null>" if message == null else message.signature()
		)
	return "%d|%d|%s|%s|%s|%d|%d|%s|%s|%d|%s|%s" % [
		state.week_index,
		state.guild.gold,
		member_parts,
		faction_parts,
		clock_parts,
		state.contract_history.size(),
		state.world_events.size(),
		offer_parts,
		plan_signature,
		state.declined_offer_week,
		commitment_parts,
		message_parts,
	]
