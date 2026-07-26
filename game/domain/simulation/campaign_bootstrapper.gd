## Pure Gate F service that composes published content into the first planning week.
class_name CampaignBootstrapper
extends RefCounted

const CampaignSetupDefinition = preload(
	"res://game/domain/campaign/campaign_setup_definition.gd"
)
const CampaignState = preload("res://game/domain/campaign/campaign_state.gd")
const GuildState = preload("res://game/domain/guild/guild_state.gd")
const AdventurerState = preload(
	"res://game/domain/adventurers/adventurer_state.gd"
)
const AdventurerDefinition = preload(
	"res://game/domain/adventurers/adventurer_definition.gd"
)
const FactionState = preload("res://game/domain/factions/faction_state.gd")
const FactionDefinition = preload(
	"res://game/domain/factions/faction_definition.gd"
)
const FactionActionDefinition = preload(
	"res://game/domain/factions/faction_action_definition.gd"
)
const ContractDefinition = preload(
	"res://game/domain/contracts/contract_definition.gd"
)
const SituationDefinition = preload(
	"res://game/domain/situations/situation_definition.gd"
)
const SituationState = preload(
	"res://game/domain/situations/situation_state.gd"
)
const WorldProblemDefinition = preload(
	"res://game/domain/situations/world_problem_definition.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const WeekFlowCoordinator = preload(
	"res://game/domain/simulation/week_flow_coordinator.gd"
)


class BootstrapRequest extends RefCounted:
	var setup: CampaignSetupDefinition
	var campaign_seed: int
	var adventurer_definitions: Array[AdventurerDefinition]
	var faction_definitions: Array[FactionDefinition]
	var contract_definitions: Array[ContractDefinition]
	var action_definitions: Array[FactionActionDefinition]
	var problem_definitions: Array[WorldProblemDefinition]
	var situation_definition: SituationDefinition

	static func create(
		p_setup: CampaignSetupDefinition,
		p_campaign_seed: int,
		p_adventurers: Array[AdventurerDefinition],
		p_factions: Array[FactionDefinition],
		p_contracts: Array[ContractDefinition],
		p_actions: Array[FactionActionDefinition],
		p_problems: Array[WorldProblemDefinition],
		p_situation: SituationDefinition
	) -> BootstrapRequest:
		var request := BootstrapRequest.new()
		request.setup = (
			p_setup.duplicate_value() if p_setup != null else null
		)
		request.campaign_seed = p_campaign_seed
		for definition: AdventurerDefinition in p_adventurers:
			request.adventurer_definitions.append(
				definition.duplicate_value() if definition != null else null
			)
		for definition: FactionDefinition in p_factions:
			request.faction_definitions.append(
				definition.duplicate_value() if definition != null else null
			)
		for definition: ContractDefinition in p_contracts:
			request.contract_definitions.append(
				definition.duplicate_value() if definition != null else null
			)
		for definition: FactionActionDefinition in p_actions:
			request.action_definitions.append(
				definition.duplicate_value() if definition != null else null
			)
		for definition: WorldProblemDefinition in p_problems:
			request.problem_definitions.append(
				definition.duplicate_value() if definition != null else null
			)
		request.situation_definition = (
			p_situation.duplicate_value() if p_situation != null else null
		)
		return request


class BootstrapResult extends RefCounted:
	var new_state: CampaignState
	var opening_result: WeekFlowCoordinator.WeekOpeningResult
	var issues: PackedStringArray

	func is_success() -> bool:
		return new_state != null \
			and opening_result != null \
			and opening_result.is_success() \
			and issues.is_empty()

	## Stable summary used by deterministic bootstrap tests and diagnostics.
	func content_signature() -> String:
		if new_state == null:
			return ""
		var offer_parts := PackedStringArray()
		for offer in new_state.pending_contracts:
			offer_parts.append(offer.content_signature())
		var message_parts := PackedStringArray()
		for message in new_state.message_history:
			message_parts.append(message.signature())
		var commitment_parts := PackedStringArray()
		for commitment in new_state.faction_action_commitments:
			commitment_parts.append(commitment.content_signature())
		var clock_parts := PackedStringArray()
		var clock_ids: Array[StringName] = []
		clock_ids.assign(new_state.situation.clock_values.keys())
		clock_ids.sort()
		for clock_id: StringName in clock_ids:
			clock_parts.append("%s:%d" % [
				clock_id,
				new_state.situation.clock_values[clock_id],
			])
		return "%d|%d|%d|%d|%s|%s|%s|%s" % [
			new_state.campaign_seed,
			new_state.week_index,
			new_state.guild.gold,
			new_state.guild.reputation,
			clock_parts,
			offer_parts,
			message_parts,
			commitment_parts,
		]


## Constructs an internal week-zero state and publishes only the successful
## first-week WeekFlow result (Accepted Gate F, section 3).
static func bootstrap(request: BootstrapRequest) -> BootstrapResult:
	var result := BootstrapResult.new()
	if request == null or request.setup == null:
		result.issues.append("Campaign bootstrap requires a setup.")
		return result
	result.issues.append_array(request.setup.validate())
	var setup := request.setup
	var adventurers_by_id := _index_definitions(
		request.adventurer_definitions,
		"adventurer",
		result.issues
	)
	var factions_by_id := _index_definitions(
		request.faction_definitions,
		"faction",
		result.issues
	)
	var problems_by_id := _index_definitions(
		request.problem_definitions,
		"problem",
		result.issues
	)
	if request.situation_definition == null:
		result.issues.append("Campaign bootstrap requires a SituationDefinition.")
	elif request.situation_definition.id != setup.situation_definition_id:
		result.issues.append(
			"Campaign setup SituationDefinition does not match supplied content."
		)
	for member_id: StringName in setup.adventurer_ids:
		if not adventurers_by_id.has(member_id):
			result.issues.append(
				"Campaign setup references missing adventurer %s." % member_id
			)
	for faction_setup in setup.faction_setups:
		if faction_setup != null \
				and not factions_by_id.has(faction_setup.faction_id):
			result.issues.append(
				"Campaign setup references missing faction %s."
				% faction_setup.faction_id
			)
	var situation_problem_ids: Dictionary[StringName, bool] = {}
	if request.situation_definition != null:
		for problem: WorldProblemDefinition \
				in request.situation_definition.problem_definitions:
			if problem != null:
				situation_problem_ids[problem.id] = true
	for problem_id: StringName in setup.initial_active_problem_ids:
		if not problems_by_id.has(problem_id):
			result.issues.append(
				"Campaign setup references missing problem %s." % problem_id
			)
		elif not situation_problem_ids.has(problem_id):
			result.issues.append(
				"Opening problem %s is outside the selected Situation."
				% problem_id
			)
	if not result.issues.is_empty():
		return result

	var guild := GuildState.create(
		setup.initial_gold,
		setup.initial_reputation,
		setup.initial_base_cohesion,
		setup.weekly_maintenance
	)
	var member_states: Dictionary[StringName, AdventurerState] = {}
	for member_id: StringName in setup.adventurer_ids:
		member_states[member_id] = AdventurerState.create(member_id)
	var faction_states: Dictionary[StringName, FactionState] = {}
	for faction_setup in setup.faction_setups:
		faction_states[faction_setup.faction_id] = FactionState.create(
			faction_setup.faction_id,
			faction_setup.initial_relation,
			faction_setup.initial_influence
		)

	var clocks: Dictionary[StringName, int] = {}
	for clock in request.situation_definition.clock_definitions:
		if clock == null:
			result.issues.append("Situation clock definitions cannot contain null.")
			continue
		clocks[clock.id] = clock.initial_value
	var problem_states: Dictionary[StringName, WorldProblemState] = {}
	for problem: WorldProblemDefinition \
			in request.situation_definition.problem_definitions:
		if problem == null or not problems_by_id.has(problem.id):
			result.issues.append(
				"Situation contains a missing published problem definition."
			)
			continue
		var is_active: bool = setup.initial_active_problem_ids.has(problem.id)
		var deadline := -1
		if is_active and problem.response_window_weeks >= 1:
			deadline = problem.response_window_weeks
		problem_states[problem.id] = WorldProblemState.create(
			problem.id,
			(
				WorldProblemState.STATUS_ACTIVE
				if is_active else WorldProblemState.STATUS_INACTIVE
			),
			1 if is_active else -1,
			deadline,
			-1
		)
	var unlocked_ids: Array[StringName] = []
	for contract: ContractDefinition in request.contract_definitions:
		if contract == null:
			result.issues.append("Contract definitions cannot contain null.")
		elif contract.starts_unlocked:
			unlocked_ids.append(contract.id)
	unlocked_ids.sort()
	if not result.issues.is_empty():
		return result
	var situation_state := SituationState.create(
		request.situation_definition.id,
		request.situation_definition.initial_phase,
		clocks,
		[],
		unlocked_ids,
		problem_states
	)
	var week_zero := CampaignState.create(
		request.campaign_seed,
		0,
		guild,
		member_states,
		faction_states,
		situation_state
	)
	if week_zero == null:
		result.issues.append("Campaign setup produced an invalid week-zero state.")
		return result

	result.opening_result = WeekFlowCoordinator.open_week(
		WeekFlowCoordinator.WeekOpeningRequest.create(
			1,
			week_zero,
			request.adventurer_definitions,
			request.faction_definitions,
			request.contract_definitions,
			request.action_definitions,
			request.problem_definitions,
			request.situation_definition
		)
	)
	if not result.opening_result.is_success():
		result.issues.append_array(result.opening_result.issues)
		result.opening_result = null
		return result
	result.new_state = result.opening_result.new_state.duplicate_state()
	return result


static func _index_definitions(
	definitions: Array,
	label: String,
	issues: PackedStringArray
) -> Dictionary:
	var result: Dictionary = {}
	for definition: Variant in definitions:
		if definition == null:
			issues.append("Campaign bootstrap %s definitions cannot contain null." % label)
			continue
		if result.has(definition.id):
			issues.append(
				"Campaign bootstrap contains duplicate %s %s."
				% [label, definition.id]
			)
		result[definition.id] = definition
	return result
