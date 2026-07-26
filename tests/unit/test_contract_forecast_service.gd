extends RefCounted

const Task015Fixtures = preload("res://tests/fixtures/task015_fixtures.gd")
const PlanningPresenter = preload(
	"res://game/features/contract_planning/planning_presenter.gd"
)
const ContractForecastService = preload(
	"res://game/domain/simulation/contract_forecast_service.gd"
)


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	return [
		_test_stable_samples_and_locked_seed_isolation(),
		_test_signature_changes_reseed_stably(),
		_test_gate_f_band_mappings(),
	]


func _test_stable_samples_and_locked_seed_isolation() -> Dictionary:
	var session := Task015Fixtures.create_session()
	var catalog = session.call("_catalog")
	var state = session.call("get_campaign_snapshot")
	var draft = Task015Fixtures.valid_draft(state)
	var first = _forecast(catalog, state, draft)
	var second = _forecast(catalog, state, draft)
	var offer = Task015Fixtures.first_pending_offer(state)
	var no_locked_seed := true
	for seed: int in first.sample_seeds:
		if seed == offer.locked_seed:
			no_locked_seed = false
	var passed: bool = first.is_success() \
		and second.is_success() \
		and first.sample_seeds.size() == 64 \
		and first.sample_seeds == second.sample_seeds \
		and first.content_signature() == second.content_signature() \
		and no_locked_seed \
		and first.warning_reasons.size() <= 2
	session.free()
	return _result(
		"64 forecast samples are stable and exclude the locked seed",
		passed,
		"Forecast stability, sample count, warning cap, or seed isolation failed."
	)


func _test_signature_changes_reseed_stably() -> Dictionary:
	var session := Task015Fixtures.create_session(150016)
	var catalog = session.call("_catalog")
	var state = session.call("get_campaign_snapshot")
	var draft = Task015Fixtures.valid_draft(state)
	var original_signature: String = draft.content_signature
	var original = _forecast(catalog, state, draft)
	draft.set_approach(&"aggressive")
	var changed_signature: String = draft.content_signature
	var changed = _forecast(catalog, state, draft)
	var repeated = _forecast(catalog, state, draft)
	var passed: bool = original.is_success() \
		and changed.is_success() \
		and original_signature != changed_signature \
		and original.sample_seeds != changed.sample_seeds \
		and changed.sample_seeds == repeated.sample_seeds \
		and changed.content_signature() == repeated.content_signature()
	session.free()
	return _result(
		"plan signature changes create a new stable forecast stream",
		passed,
		"Approach did not alter the signature/stream or repeated prediction drifted."
	)


func _test_gate_f_band_mappings() -> Dictionary:
	var passed: bool = (
		ContractForecastService._clause_status(64) == &"expected_met"
		and ContractForecastService._clause_status(45) == &"favorable"
		and ContractForecastService._clause_status(20) == &"uncertain"
		and ContractForecastService._clause_status(1) == &"high_risk"
		and ContractForecastService._clause_status(0) == &"expected_conflict"
		and ContractForecastService._injury_band(14) == &"low"
		and ContractForecastService._injury_band(15) == &"medium"
		and ContractForecastService._injury_band(30) == &"high"
		and ContractForecastService._injury_band(50) == &"severe"
	)
	return _result(
		"Gate F clause and injury bands use exact boundaries",
		passed,
		"One or more Gate F display-band boundaries changed."
	)


func _forecast(catalog, state, draft):
	return PlanningPresenter.build_forecast(
		state,
		draft,
		catalog.get_all_contracts(),
		catalog.get_all_adventurers(),
		catalog.get_all_supplies(),
		catalog.get_all_contract_clauses(),
		catalog.get_all_method_tags()
	)


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}
