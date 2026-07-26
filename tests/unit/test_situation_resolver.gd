extends RefCounted

const SituationResolver = preload(
	"res://game/domain/simulation/situation_resolver.gd"
)
const CampaignTransaction = preload(
	"res://game/domain/simulation/campaign_transaction.gd"
)
const StateOperation = preload("res://game/core/result/state_operation.gd")
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const WorldRule = preload("res://game/domain/situations/world_rule.gd")
const EndingDefinition = preload(
	"res://game/domain/situations/ending_definition.gd"
)
const SituationFixtures = preload(
	"res://tests/fixtures/situation_fixtures.gd"
)
const CatalogValidator = preload("res://game/data/catalogs/catalog_validator.gd")
const ProblemUrgencyRuleResource = preload(
	"res://game/data/definitions/situations/problem_urgency_rule_resource.gd"
)
const WorldConditionResource = preload(
	"res://game/data/definitions/situations/world_condition_resource.gd"
)
const CatalogFixtures = preload("res://tests/fixtures/catalog_fixtures.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_clock_merge_before_trigger_test(),
		_passive_boundary_test(),
		_problem_activation_and_resolution_test(),
		_problem_escalates_once_test(),
		_trigger_batch_is_not_recursive_test(),
		_once_marker_waits_for_commit_test(),
		_ending_priority_and_terminal_phase_test(),
		_determinism_test(),
		_catalog_rejects_overlapping_urgency_intervals_test(),
		_catalog_requires_escalation_event_test(),
	]


func _clock_merge_before_trigger_test() -> Dictionary:
	var threshold_trigger := SituationFixtures.rule(
		&"trigger_merged_clock",
		[SituationFixtures.condition(
			&"clock_gte",
			&"settlement_destruction",
			83
		)],
		[],
		[SituationFixtures.effect(
			&"unlock_contract",
			&"contract_unlocked_by_merge",
			0,
			&"unlock_after_merge"
		)]
	)
	var triggers: Array[WorldRule] = [threshold_trigger]
	var definition = SituationFixtures.create_definition(triggers)
	var state = SituationFixtures.create_state(
		WorldProblemState.STATUS_INACTIVE,
		-1,
		-1,
		{&"settlement_destruction": 95}
	)
	var base_operations: Array[StateOperation] = [
		_clock_operation(10, &"clock_source_positive", 100),
		_clock_operation(-20, &"clock_source_negative", 101),
	]
	var resolved = SituationResolver.resolve(
		1,
		definition,
		state,
		[],
		[],
		base_operations,
		SituationResolver.BOUNDARY_WEEK_END
	)
	var passed: bool = resolved.is_success() \
		and resolved.triggered_rule_ids == [&"trigger_merged_clock"]
	return _result(
		"base clock sources merge then clamp before trigger snapshot",
		passed,
		"Expected merged value 85 to satisfy the threshold trigger."
	)


func _passive_boundary_test() -> Dictionary:
	var definition = SituationFixtures.create_definition()
	var week_one = SituationResolver.resolve(
		1,
		definition,
		SituationFixtures.create_state(),
		[],
		[],
		[],
		SituationResolver.BOUNDARY_WEEK_START
	)
	var week_two = SituationResolver.resolve(
		2,
		definition,
		SituationFixtures.create_state(),
		[],
		[],
		[],
		SituationResolver.BOUNDARY_WEEK_START
	)
	var week_end = SituationResolver.resolve(
		2,
		definition,
		SituationFixtures.create_state(),
		[],
		[],
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var week_one_passive: int = _source_count(
		week_one.operations,
		SituationResolver.SOURCE_PASSIVE
	)
	var week_two_passive: int = _source_count(
		week_two.operations,
		SituationResolver.SOURCE_PASSIVE
	)
	var week_end_passive: int = _source_count(
		week_end.operations,
		SituationResolver.SOURCE_PASSIVE
	)
	return _result(
		"passive skips week one and runs once at later week starts",
		week_one_passive == 0 \
			and week_two_passive == 3 \
			and week_end_passive == 0,
		"Expected 0/3/0 passive operations."
	)


func _problem_activation_and_resolution_test() -> Dictionary:
	var definition = SituationFixtures.create_definition()
	var initial_state = SituationFixtures.create_state(
		WorldProblemState.STATUS_INACTIVE,
		-1,
		-1,
		{&"settlement_destruction": 30}
	)
	var campaign = SituationFixtures.create_campaign(2, initial_state)
	var activation = SituationResolver.resolve(
		2,
		definition,
		campaign.situation,
		campaign.world_events,
		campaign.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var activated_commit = CampaignTransaction.apply(campaign, activation.operations)
	if not activated_commit.is_success():
		return _result(
			"problem activation locks deadline and later resolves",
			false,
			"Activation commit failed: %s" % activated_commit.issues
		)
	var activated = activated_commit.new_state.situation.problems[
		SituationFixtures.PROBLEM_ID
	]
	var resolution_event = SituationFixtures.event_state(
		&"fixture_problem_resolution",
		&"event_timed_pressure_resolved",
		3
	)
	var campaign_with_event = SituationFixtures.create_campaign(
		3,
		activated_commit.new_state.situation,
		[resolution_event]
	)
	var resolution = SituationResolver.resolve(
		3,
		definition,
		campaign_with_event.situation,
		campaign_with_event.world_events,
		campaign_with_event.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var resolved_commit = CampaignTransaction.apply(
		campaign_with_event,
		resolution.operations
	)
	var resolved_problem = (
		resolved_commit.new_state.situation.problems[SituationFixtures.PROBLEM_ID]
		if resolved_commit.is_success()
		else null
	)
	var passed: bool = activated.status == WorldProblemState.STATUS_ACTIVE \
		and activated.opened_week == 2 \
		and activated.response_deadline_week == 4 \
		and resolved_problem != null \
		and resolved_problem.status == WorldProblemState.STATUS_RESOLVED \
		and resolved_problem.closed_week == 3
	return _result(
		"problem activation locks deadline and later resolves",
		passed,
		"Expected active at week 2 with deadline 4, then resolved at week 3."
	)


func _problem_escalates_once_test() -> Dictionary:
	var definition = SituationFixtures.create_definition()
	var state = SituationFixtures.create_state(
		WorldProblemState.STATUS_ACTIVE,
		1,
		1
	)
	var campaign = SituationFixtures.create_campaign(2, state)
	var escalation = SituationResolver.resolve(
		2,
		definition,
		campaign.situation,
		campaign.world_events,
		campaign.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_START
	)
	var first_commit = CampaignTransaction.apply(campaign, escalation.operations)
	if not first_commit.is_success():
		return _result(
			"expired problem escalates once with one stable event",
			false,
			"Escalation commit failed: %s" % first_commit.issues
		)
	var next_campaign = first_commit.new_state
	next_campaign.week_index = 3
	var repeated = SituationResolver.resolve(
		3,
		definition,
		next_campaign.situation,
		next_campaign.world_events,
		next_campaign.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var problem = next_campaign.situation.problems[SituationFixtures.PROBLEM_ID]
	var passed: bool = problem.status == WorldProblemState.STATUS_ESCALATED \
		and problem.closed_week == 2 \
		and next_campaign.world_events.size() == 1 \
		and repeated.escalated_problem_ids.is_empty() \
		and repeated.created_world_event_ids.is_empty()
	return _result(
		"expired problem escalates once with one stable event",
		passed,
		"Expected one escalation and no repeated event."
	)


func _trigger_batch_is_not_recursive_test() -> Dictionary:
	var first := SituationFixtures.rule(
		&"trigger_chain_first",
		[SituationFixtures.condition(
			&"clock_gte",
			&"settlement_destruction",
			10
		)],
		[],
		[SituationFixtures.effect(
			&"modify_clock",
			&"capture_preparation",
			10,
			&"chain_first_progress"
		)],
		true,
		20
	)
	var second := SituationFixtures.rule(
		&"trigger_chain_second",
		[SituationFixtures.condition(
			&"clock_gte",
			&"capture_preparation",
			10
		)],
		[],
		[SituationFixtures.effect(
			&"unlock_contract",
			&"contract_chain_followup",
			0,
			&"chain_second_unlock"
		)],
		true,
		10
	)
	var triggers: Array[WorldRule] = [first, second]
	var definition = SituationFixtures.create_definition(triggers)
	var campaign = SituationFixtures.create_campaign(
		1,
		SituationFixtures.create_state()
	)
	var first_result = SituationResolver.resolve(
		1,
		definition,
		campaign.situation,
		campaign.world_events,
		campaign.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var first_commit = CampaignTransaction.apply(campaign, first_result.operations)
	var second_result = SituationResolver.resolve(
		1,
		definition,
		first_commit.new_state.situation,
		first_commit.new_state.world_events,
		first_commit.new_state.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var passed: bool = first_result.triggered_rule_ids == [&"trigger_chain_first"] \
		and second_result.triggered_rule_ids == [&"trigger_chain_second"]
	return _result(
		"trigger eligibility locks one non-recursive snapshot",
		passed,
		"Expected the second trigger only on the next boundary."
	)


func _once_marker_waits_for_commit_test() -> Dictionary:
	var trigger_a := SituationFixtures.rule(
		&"trigger_conflict_a",
		[SituationFixtures.condition(&"week_gte", &"", 1)],
		[],
		[SituationFixtures.effect(
			&"change_phase",
			&"phase_open_conflict",
			0,
			&"conflict_phase_a"
		)],
		true,
		20
	)
	var trigger_b := SituationFixtures.rule(
		&"trigger_conflict_b",
		[SituationFixtures.condition(&"week_gte", &"", 1)],
		[],
		[SituationFixtures.effect(
			&"change_phase",
			&"phase_final_window",
			0,
			&"conflict_phase_b"
		)],
		true,
		10
	)
	var triggers: Array[WorldRule] = [trigger_a, trigger_b]
	var definition = SituationFixtures.create_definition(triggers)
	var campaign = SituationFixtures.create_campaign(
		1,
		SituationFixtures.create_state()
	)
	var resolved = SituationResolver.resolve(
		1,
		definition,
		campaign.situation,
		campaign.world_events,
		campaign.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var committed = CampaignTransaction.apply(campaign, resolved.operations)
	var passed: bool = not committed.is_success() \
		and campaign.situation.triggered_rule_ids.is_empty() \
		and campaign.situation.phase_id == &"phase_early_crisis"
	return _result(
		"once markers commit only with a conflict-free trigger batch",
		passed,
		"Expected conflicting phase writes to roll back trigger IDs."
	)


func _ending_priority_and_terminal_phase_test() -> Dictionary:
	var ending_alpha := SituationFixtures.ending(
		&"ending_alpha",
		100,
		[SituationFixtures.condition(&"week_gte", &"", 10)]
	)
	var ending_beta := SituationFixtures.ending(
		&"ending_beta",
		100,
		[SituationFixtures.condition(&"week_gte", &"", 10)]
	)
	var endings: Array[EndingDefinition] = [ending_beta, ending_alpha]
	var definition = SituationFixtures.create_definition([], endings)
	var state = SituationFixtures.create_state(
		WorldProblemState.STATUS_ACTIVE,
		1,
		20,
		{},
		&"phase_final_window"
	)
	var campaign = SituationFixtures.create_campaign(10, state)
	var resolved = SituationResolver.resolve(
		10,
		definition,
		campaign.situation,
		campaign.world_events,
		campaign.contract_history,
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var committed = CampaignTransaction.apply(campaign, resolved.operations)
	var problem = (
		committed.new_state.situation.problems[SituationFixtures.PROBLEM_ID]
		if committed.is_success()
		else null
	)
	var passed: bool = resolved.selected_ending_id == &"ending_alpha" \
		and committed.is_success() \
		and committed.new_state.situation.ending_id == &"ending_alpha" \
		and committed.new_state.situation.phase_id == &"phase_ended" \
		and problem.status == WorldProblemState.STATUS_CLOSED
	return _result(
		"ending ties use stable ID and enter the sole terminal phase",
		passed,
		"Expected ending_alpha, phase_ended, and active problems closed."
	)


func _determinism_test() -> Dictionary:
	var definition = SituationFixtures.create_definition(
		SituationFixtures.accepted_phase_triggers(),
		SituationFixtures.accepted_endings()
	)
	var state = SituationFixtures.create_state(
		WorldProblemState.STATUS_ACTIVE,
		1,
		20,
		{
			&"villagers_evacuated": 50,
			&"capture_preparation": 40,
			&"dragon_exhaustion": 45,
			&"necrotic_corruption": 30,
		},
		&"phase_final_window"
	)
	var baseline = SituationResolver.resolve(
		12,
		definition,
		state,
		[],
		[],
		[],
		SituationResolver.BOUNDARY_WEEK_END
	)
	var signature: String = baseline.signature()
	for _iteration: int in range(100):
		var repeated = SituationResolver.resolve(
			12,
			definition,
			state,
			[],
			[],
			[],
			SituationResolver.BOUNDARY_WEEK_END
		)
		if repeated.signature() != signature:
			return _result(
				"same world snapshot repeats 100 times",
				false,
				"Situation resolution signature changed."
			)
	return _result("same world snapshot repeats 100 times", true, "")


func _catalog_rejects_overlapping_urgency_intervals_test() -> Dictionary:
	var manifest = CatalogFixtures.create_valid_manifest()
	var problem = manifest.problem_definitions[0]
	problem.urgency_rules.append(_urgency_resource(
		&"urgency_low",
		&"clock_gte",
		10
	))
	problem.urgency_rules.append(_urgency_resource(
		&"urgency_overlap",
		&"clock_lte",
		20
	))
	var issues = CatalogValidator.new().validate(
		manifest,
		"memory://overlapping_urgency"
	)
	var passed: bool = _has_validation_issue(
		issues,
		&"overlapping_range",
		"problem_definitions[0].urgency_rules[1].all_conditions"
	)
	return _result(
		"catalog rejects overlapping urgency intervals on one problem clock",
		passed,
		"Expected a structured overlapping_range issue at the second rule."
	)


func _catalog_requires_escalation_event_test() -> Dictionary:
	var manifest = CatalogFixtures.create_valid_manifest()
	manifest.problem_definitions[0].escalation_effects.clear()
	var issues = CatalogValidator.new().validate(
		manifest,
		"memory://missing_escalation_event"
	)
	var passed: bool = _has_validation_issue(
		issues,
		&"missing_required",
		"problem_definitions[0].escalation_effects"
	)
	return _result(
		"catalog requires every problem escalation to create an event",
		passed,
		"Expected escalation_effects to require a stable world event."
	)


func _urgency_resource(
	id: StringName,
	condition_type: StringName,
	threshold: int
) -> ProblemUrgencyRuleResource:
	var condition := WorldConditionResource.new()
	condition.type = condition_type
	condition.target_id = &"clock_test"
	condition.int_value = threshold
	var resource := ProblemUrgencyRuleResource.new()
	resource.id = id
	resource.all_conditions.append(condition)
	resource.urgency_delta = 10
	resource.reason_code = id
	return resource


func _has_validation_issue(
	issues: Array,
	code: StringName,
	field_path: String
) -> bool:
	for issue in issues:
		if issue.code == code and issue.field_path == field_path:
			return true
	return false


func _clock_operation(
	amount: int,
	reason_code: StringName,
	source_order: int
) -> StateOperation:
	return StateOperation.create(
		CampaignTransaction.TARGET_CLOCK,
		&"settlement_destruction",
		CampaignTransaction.FIELD_VALUE,
		StateOperation.OP_ADD_INT,
		amount,
		reason_code,
		source_order
	)


func _source_count(operations: Array, source_start: int) -> int:
	var count: int = 0
	for operation in operations:
		if operation.source_order >= source_start \
			and operation.source_order < source_start + 50:
			count += 1
	return count


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
