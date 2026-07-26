extends RefCounted

const ProblemUrgencyCalculator = preload(
	"res://game/domain/simulation/problem_urgency_calculator.gd"
)
const ProblemUrgencyResult = preload(
	"res://game/domain/situations/problem_urgency_result.gd"
)
const ProblemUrgencyRule = preload(
	"res://game/domain/situations/problem_urgency_rule.gd"
)
const WorldProblemState = preload(
	"res://game/domain/situations/world_problem_state.gd"
)
const SituationFixtures = preload(
	"res://tests/fixtures/situation_fixtures.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_age_deadline_boundaries_test(),
		_band_boundaries_test(),
		_reason_order_and_purity_test(),
		_score_clamp_test(),
	]


func _age_deadline_boundaries_test() -> Dictionary:
	var definition = SituationFixtures.create_problem_definition(
		20,
		8,
		16,
		3,
		[],
		[],
		[]
	)
	var situation = SituationFixtures.create_state(
		WorldProblemState.STATUS_ACTIVE,
		1,
		3
	)
	var expected_scores: Array[int] = [20, 38, 61, 36]
	var expected_remaining: Array[int] = [3, 2, 1, 0]
	for index: int in range(4):
		var urgency = ProblemUrgencyCalculator.calculate(
			index + 1,
			definition,
			situation.problems[SituationFixtures.PROBLEM_ID],
			situation
		)
		if urgency == null \
			or urgency.score != expected_scores[index] \
			or urgency.remaining_turns != expected_remaining[index]:
			return _result(
				"age cap and 3/2/1/overdue deadline boundaries",
				false,
				"Unexpected week %d urgency." % (index + 1)
			)
	return _result(
		"age cap and 3/2/1/overdue deadline boundaries",
		true,
		""
	)


func _band_boundaries_test() -> Dictionary:
	var scores: Array[int] = [0, 19, 20, 39, 40, 59, 60, 79, 80, 100]
	var bands: Array[StringName] = [
		ProblemUrgencyResult.BAND_LOW,
		ProblemUrgencyResult.BAND_LOW,
		ProblemUrgencyResult.BAND_GUARDED,
		ProblemUrgencyResult.BAND_GUARDED,
		ProblemUrgencyResult.BAND_HIGH,
		ProblemUrgencyResult.BAND_HIGH,
		ProblemUrgencyResult.BAND_SEVERE,
		ProblemUrgencyResult.BAND_SEVERE,
		ProblemUrgencyResult.BAND_CRITICAL,
		ProblemUrgencyResult.BAND_CRITICAL,
	]
	var situation = SituationFixtures.create_state(
		WorldProblemState.STATUS_ACTIVE,
		1,
		-1
	)
	for index: int in range(scores.size()):
		var definition = SituationFixtures.create_problem_definition(
			scores[index],
			0,
			0,
			-1,
			[],
			[],
			[]
		)
		var urgency = ProblemUrgencyCalculator.calculate(
			1,
			definition,
			situation.problems[SituationFixtures.PROBLEM_ID],
			situation
		)
		if urgency == null or urgency.band != bands[index]:
			return _result(
				"urgency band boundaries are exact",
				false,
				"Score %d mapped to the wrong band." % scores[index]
			)
	return _result("urgency band boundaries are exact", true, "")


func _reason_order_and_purity_test() -> Dictionary:
	var definition = SituationFixtures.create_problem_definition()
	var situation = SituationFixtures.create_state(
		WorldProblemState.STATUS_ACTIVE,
		1,
		-1,
		{&"settlement_destruction": 30},
		&"phase_final_window"
	)
	var before: String = _state_signature(situation)
	var urgency = ProblemUrgencyCalculator.calculate(
		3,
		definition,
		situation.problems[SituationFixtures.PROBLEM_ID],
		situation
	)
	var codes: Array[StringName] = []
	for reason in urgency.reason_entries:
		codes.append(reason.code)
	var expected: Array[StringName] = [
		&"problem_urgency_base",
		&"urgency_destruction_pressure",
		&"problem_urgency_age",
		&"urgency_final_phase",
	]
	var passed: bool = urgency.score == 66 \
		and urgency.band == ProblemUrgencyResult.BAND_SEVERE \
		and codes == expected \
		and _state_signature(situation) == before
	return _result(
		"urgency reasons follow formula order without state writes",
		passed,
		"Expected score 66 and base/clock/age/phase reason order."
	)


func _score_clamp_test() -> Dictionary:
	var negative_rules: Array[ProblemUrgencyRule] = [
		ProblemUrgencyRule.create(
			&"urgency_negative",
			[SituationFixtures.condition(
				&"clock_gte",
				&"settlement_destruction",
				0
			)],
			-50,
			&"urgency_negative",
			&"debug",
			1
		),
	]
	var positive_rules: Array[ProblemUrgencyRule] = [
		ProblemUrgencyRule.create(
			&"urgency_positive",
			[SituationFixtures.condition(
				&"clock_gte",
				&"settlement_destruction",
				0
			)],
			100,
			&"urgency_positive",
			&"player",
			1
		),
	]
	var situation = SituationFixtures.create_state(
		WorldProblemState.STATUS_ACTIVE,
		1,
		-1
	)
	var low = ProblemUrgencyCalculator.calculate(
		1,
		SituationFixtures.create_problem_definition(
			0, 0, 0, -1, negative_rules, [], []
		),
		situation.problems[SituationFixtures.PROBLEM_ID],
		situation
	)
	var high = ProblemUrgencyCalculator.calculate(
		1,
		SituationFixtures.create_problem_definition(
			50, 0, 0, -1, positive_rules, [], []
		),
		situation.problems[SituationFixtures.PROBLEM_ID],
		situation
	)
	return _result(
		"urgency clamps only the final score to 0 and 100",
		low.score == 0 and high.score == 100,
		"Expected lower and upper clamp boundaries."
	)


func _state_signature(state) -> String:
	var problem = state.problems[SituationFixtures.PROBLEM_ID]
	return "%s|%s|%s|%d|%d|%d" % [
		state.phase_id,
		state.clock_values,
		problem.status,
		problem.opened_week,
		problem.response_deadline_week,
		problem.closed_week,
	]


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
