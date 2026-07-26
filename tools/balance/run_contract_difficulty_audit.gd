extends SceneTree

const GameSessionScript = preload("res://game/app/game_session.gd")
const DataCatalog = preload("res://game/data/catalogs/data_catalog.gd")
const PlanningDraft = preload(
	"res://game/features/contract_planning/planning_draft.gd"
)
const PlanningPresenter = preload(
	"res://game/features/contract_planning/planning_presenter.gd"
)
const AdventurerSnapshot = preload(
	"res://game/domain/adventurers/adventurer_snapshot.gd"
)
const ContractPlan = preload(
	"res://game/domain/contracts/contract_plan.gd"
)
const SupplyDefinition = preload(
	"res://game/domain/contracts/supply_definition.gd"
)
const ContractOfferService = preload(
	"res://game/domain/simulation/contract_offer_service.gd"
)
const ContractResolver = preload(
	"res://game/domain/simulation/contract_resolver.gd"
)

const SETUP_ID: StringName = &"campaign_setup_dragon_invasion_v0_1"
const AUDIT_SEED: int = 170201
const TOP_UNPREPARED_CANDIDATES: int = 5
const APPROACHES: Array[StringName] = [
	&"cautious",
	&"balanced",
	&"aggressive",
]
const TIER_ORDER: Array[StringName] = [
	&"severe",
	&"failure",
	&"partial",
	&"success",
	&"exceptional",
]


func _initialize() -> void:
	var catalog := DataCatalog.new()
	var load_result = catalog.load_manifest(DataCatalog.DEFAULT_MANIFEST_PATH)
	if not load_result.is_success():
		push_error("Difficulty audit catalog load failed: %s" % load_result.issues)
		quit(1)
		return
	var session: Node = GameSessionScript.new()
	session.call("set_catalog_for_testing", catalog)
	if not session.call("start_new_campaign", SETUP_ID, AUDIT_SEED):
		push_error("Difficulty audit bootstrap failed: %s" % session.call("get_last_error"))
		session.free()
		catalog.free()
		quit(1)
		return
	var state = session.call("get_campaign_snapshot")
	var offers: Array = []
	for offer in state.pending_contracts:
		if offer != null and offer.status == &"pending":
			offers.append(offer)
	offers.sort_custom(func(left, right) -> bool:
		return String(left.definition_id) < String(right.definition_id)
	)
	if OS.get_cmdline_user_args().has("--finalize-only"):
		var finalized := _finalize_existing_report(catalog, state, offers)
		session.free()
		catalog.free()
		quit(0 if finalized else 1)
		return

	var reports: Array[Dictionary] = []
	for offer in offers:
		print("Auditing %s..." % offer.definition_id)
		reports.append(_audit_offer(catalog, state, offer))
	var output := {
		"generated_by": "Task017 real ContractForecastService difficulty audit",
		"campaign_seed": AUDIT_SEED,
		"week_index": state.week_index,
		"check_tier_thresholds": {
			"exceptional": ContractResolver.CHECK_EXCEPTIONAL_THRESHOLD,
			"success": ContractResolver.CHECK_SUCCESS_THRESHOLD,
			"partial": ContractResolver.CHECK_PARTIAL_THRESHOLD,
			"failure": ContractResolver.CHECK_FAILURE_THRESHOLD,
		},
		"contract_tier_thresholds": {
			"exceptional": ContractResolver.CONTRACT_EXCEPTIONAL_THRESHOLD,
			"success": ContractResolver.CONTRACT_SUCCESS_THRESHOLD,
			"partial": ContractResolver.CONTRACT_PARTIAL_THRESHOLD,
			"failure": ContractResolver.CONTRACT_FAILURE_THRESHOLD,
		},
		"offers": reports,
	}
	if not _write_report(output):
		push_error("Could not write contract difficulty report.")
		session.free()
		catalog.free()
		quit(1)
		return
	print(JSON.stringify(output, "\t", false))
	session.free()
	catalog.free()
	quit(0)


func _audit_offer(catalog, state, offer) -> Dictionary:
	var member_ids: Array[StringName] = []
	member_ids.assign(state.adventurers.keys())
	member_ids.sort_custom(_stable_id_less)
	var teams := _four_member_teams(member_ids)
	var unprepared: Array[Dictionary] = []
	var interval_counts: Dictionary = {}
	for team: Array[StringName] in teams:
		for approach: StringName in APPROACHES:
			var candidate := _forecast_candidate(
				catalog,
				state,
				offer,
				team,
				[],
				approach
			)
			if candidate.is_empty():
				continue
			unprepared.append(candidate)
			var interval: String = "%s..%s" % [
				candidate["likely_tier_low"],
				candidate["likely_tier_high"],
			]
			interval_counts[interval] = int(interval_counts.get(interval, 0)) + 1
	unprepared.sort_custom(_candidate_better)
	var exact_unprepared := _exact_ranked_candidates(
		catalog,
		state,
		offer,
		unprepared
	)
	var shortlist: Array[Dictionary] = exact_unprepared.slice(
		0,
		mini(TOP_UNPREPARED_CANDIDATES, exact_unprepared.size())
	)
	var prepared: Array[Dictionary] = shortlist.duplicate(true)
	var supply_options := _legal_supply_options(catalog, offer, state.guild.gold)
	for baseline: Dictionary in shortlist:
		for supply_ids: Array[StringName] in supply_options:
			if supply_ids.is_empty():
				continue
			for approach: StringName in APPROACHES:
				var candidate := _forecast_candidate(
					catalog,
					state,
					offer,
					baseline["member_ids"],
					supply_ids,
					approach
				)
				if not candidate.is_empty():
					prepared.append(candidate)
	prepared.sort_custom(_candidate_better)
	# Forecast intervals intentionally stay coarse. Re-rank every evaluated
	# candidate with the real resolver so wide intervals and signature order do
	# not label a clause-capped Failure as the audit's "best" plan.
	var exact_prepared := _exact_ranked_candidates(
		catalog,
		state,
		offer,
		prepared
	)
	var best_unprepared: Dictionary = (
		exact_unprepared[0] if not exact_unprepared.is_empty() else {}
	)
	var best_prepared: Dictionary = (
		exact_prepared[0] if not exact_prepared.is_empty() else {}
	)
	return {
		"contract_id": String(offer.definition_id),
		"offer_id": String(offer.instance_id),
		"evaluated_unprepared_plans": unprepared.size(),
		"unprepared_interval_counts": interval_counts,
		"exact_reranked_unprepared_plans": exact_unprepared.size(),
		"best_unprepared": best_unprepared,
		"evaluated_prepared_shortlist_plans": prepared.size(),
		"exact_reranked_prepared_plans": exact_prepared.size(),
		"best_prepared": best_prepared,
	}


func _exact_ranked_candidates(
	catalog,
	state,
	offer,
	forecast_ranked: Array[Dictionary]
) -> Array[Dictionary]:
	var exact_ranked: Array[Dictionary] = []
	for forecast_candidate: Dictionary in forecast_ranked:
		var candidate: Dictionary = forecast_candidate.duplicate(true)
		candidate["tier_counts"] = _tier_counts(catalog, state, offer, candidate)
		candidate.erase("_sample_seeds")
		exact_ranked.append(candidate)
	exact_ranked.sort_custom(_exact_candidate_better)
	return exact_ranked


func _exact_candidate_better(left: Dictionary, right: Dictionary) -> bool:
	var left_counts: Dictionary = left["tier_counts"]
	var right_counts: Dictionary = right["tier_counts"]
	var left_points := _distribution_points(left_counts)
	var right_points := _distribution_points(right_counts)
	if left_points != right_points:
		return left_points > right_points
	var left_locked := TIER_ORDER.find(
		StringName(left_counts.get("locked_seed_tier", "severe"))
	)
	var right_locked := TIER_ORDER.find(
		StringName(right_counts.get("locked_seed_tier", "severe"))
	)
	if left_locked != right_locked:
		return left_locked > right_locked
	return _candidate_better(left, right)


func _distribution_points(counts: Dictionary) -> int:
	return int(counts.get("failure", 0)) * 25 \
		+ int(counts.get("partial", 0)) * 50 \
		+ int(counts.get("success", 0)) * 75 \
		+ int(counts.get("exceptional", 0)) * 100


func _forecast_candidate(
	catalog,
	state,
	offer,
	member_ids: Array[StringName],
	supply_ids: Array[StringName],
	approach: StringName
) -> Dictionary:
	var draft := PlanningDraft.new()
	draft.select_offer(offer.instance_id)
	for member_id: StringName in member_ids:
		draft.toggle_member(member_id)
	for supply_id: StringName in supply_ids:
		draft.toggle_supply(supply_id)
	draft.set_approach(approach)
	var forecast = PlanningPresenter.build_forecast(
		state,
		draft,
		catalog.get_all_contracts(),
		catalog.get_all_adventurers(),
		catalog.get_all_supplies(),
		catalog.get_all_contract_clauses(),
		catalog.get_all_method_tags()
	)
	if forecast == null or not forecast.is_success():
		return {}
	var members: Array[StringName] = []
	for member_id: StringName in member_ids:
		members.append(member_id)
	var supplies: Array[StringName] = []
	for supply_id: StringName in supply_ids:
		supplies.append(supply_id)
	return {
		"member_ids": members,
		"supply_ids": supplies,
		"approach": String(approach),
		"likely_tier_low": String(forecast.likely_tier_low),
		"likely_tier_high": String(forecast.likely_tier_high),
		"plan_signature": draft.content_signature,
		"_sample_seeds": forecast.sample_seeds.duplicate(),
	}


func _tier_counts(
	catalog,
	state,
	offer,
	candidate: Dictionary
) -> Dictionary:
	var contract = catalog.get_contract(offer.definition_id)
	var effective = ContractOfferService.build_effective_contract(
		offer,
		contract,
		catalog.get_all_contract_clauses(),
		catalog.get_all_method_tags()
	)
	var adventurer_index := _index_by_id(catalog.get_all_adventurers())
	var supply_index := _index_by_id(catalog.get_all_supplies())
	var members: Array[AdventurerSnapshot] = []
	var member_ids: Array[StringName] = []
	for raw_id: Variant in candidate["member_ids"]:
		var member_id := StringName(raw_id)
		member_ids.append(member_id)
		members.append(AdventurerSnapshot.create(
			adventurer_index[member_id],
			state.adventurers[member_id]
		))
	var selected_supplies: Array[SupplyDefinition] = []
	var supply_ids: Array[StringName] = []
	for raw_id: Variant in candidate["supply_ids"]:
		var supply_id := StringName(raw_id)
		supply_ids.append(supply_id)
		selected_supplies.append(supply_index[supply_id])
	var plan := ContractPlan.create(
		members,
		selected_supplies,
		StringName(candidate["approach"])
	)
	var sample_seeds: Array[int] = []
	sample_seeds.assign(candidate.get("_sample_seeds", []))
	if sample_seeds.is_empty():
		var draft := PlanningDraft.new()
		draft.select_offer(offer.instance_id)
		for member_id: StringName in member_ids:
			draft.toggle_member(member_id)
		for supply_id: StringName in supply_ids:
			draft.toggle_supply(supply_id)
		draft.set_approach(StringName(candidate["approach"]))
		var forecast = PlanningPresenter.build_forecast(
			state,
			draft,
			catalog.get_all_contracts(),
			catalog.get_all_adventurers(),
			catalog.get_all_supplies(),
			catalog.get_all_contract_clauses(),
			catalog.get_all_method_tags()
		)
		sample_seeds.assign(forecast.sample_seeds)
	var counts: Dictionary = {
		"severe": 0,
		"failure": 0,
		"partial": 0,
		"success": 0,
		"exceptional": 0,
	}
	var initial_tier_counts: Dictionary = {}
	var operational_tier_counts: Dictionary = {}
	var clause_satisfied_counts: Dictionary = {}
	var score_stats: Dictionary = {}
	for sample_seed: int in sample_seeds:
		var resolution_result = ContractResolver.resolve(
			effective,
			plan,
			sample_seed,
			state.guild.base_cohesion
		)
		if resolution_result.is_success():
			var resolution = resolution_result.resolution
			var tier: String = resolution.result_tier
			counts[tier] = int(counts[tier]) + 1
			var initial_tier: String = String(resolution.initial_result_tier)
			initial_tier_counts[initial_tier] = int(
				initial_tier_counts.get(initial_tier, 0)
			) + 1
			var operational_tier: String = String(resolution.operational_result_tier)
			operational_tier_counts[operational_tier] = int(
				operational_tier_counts.get(operational_tier, 0)
			) + 1
			for clause_result in resolution.clause_results:
				var clause_id: String = String(clause_result.clause_id)
				if clause_result.satisfied:
					clause_satisfied_counts[clause_id] = int(
						clause_satisfied_counts.get(clause_id, 0)
					) + 1
			for phase_result in resolution.phase_results:
				var check_result = phase_result.check_result
				var check_id: String = String(check_result.check_id)
				var stats: Dictionary = score_stats.get(check_id, {
					"minimum": check_result.score,
					"maximum": check_result.score,
					"total": 0,
					"tier_counts": {},
				})
				stats["minimum"] = mini(int(stats["minimum"]), check_result.score)
				stats["maximum"] = maxi(int(stats["maximum"]), check_result.score)
				stats["total"] = int(stats["total"]) + check_result.score
				var check_tiers: Dictionary = stats["tier_counts"]
				var check_tier: String = String(check_result.result_tier)
				check_tiers[check_tier] = int(check_tiers.get(check_tier, 0)) + 1
				stats["tier_counts"] = check_tiers
				score_stats[check_id] = stats
	var normalized_stats: Dictionary = {}
	for check_id: String in score_stats:
		var stats: Dictionary = score_stats[check_id]
		normalized_stats[check_id] = {
			"minimum": stats["minimum"],
			"maximum": stats["maximum"],
			"average": snappedf(
				float(stats["total"]) / float(sample_seeds.size()),
				0.01
			),
			"tier_counts": stats["tier_counts"],
		}
	counts["check_score_stats"] = normalized_stats
	counts["initial_tier_counts"] = initial_tier_counts
	counts["operational_tier_counts"] = operational_tier_counts
	counts["clause_satisfied_counts"] = clause_satisfied_counts
	var locked = ContractResolver.resolve(
		effective,
		plan,
		offer.locked_seed,
		state.guild.base_cohesion
	)
	counts["locked_seed_tier"] = (
		String(locked.resolution.result_tier)
		if locked.is_success() else "error"
	)
	var locked_checks: Array[Dictionary] = []
	var locked_clauses: Array[Dictionary] = []
	if locked.is_success():
		for phase_result in locked.resolution.phase_results:
			locked_checks.append({
				"check_id": String(phase_result.check_result.check_id),
				"score": phase_result.check_result.score,
				"tier": String(phase_result.check_result.result_tier),
			})
		for clause_result in locked.resolution.clause_results:
			locked_clauses.append({
				"clause_id": String(clause_result.clause_id),
				"satisfied": clause_result.satisfied,
				"result_cap": String(clause_result.result_cap),
			})
		counts["locked_initial_tier"] = String(
			locked.resolution.initial_result_tier
		)
		counts["locked_operational_tier"] = String(
			locked.resolution.operational_result_tier
		)
	counts["locked_check_results"] = locked_checks
	counts["locked_clause_results"] = locked_clauses
	return counts


func _finalize_existing_report(catalog, state, offers: Array) -> bool:
	var path := "res://tools/balance/task017_contract_difficulty_report.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Difficulty report does not exist for finalize-only mode.")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Difficulty report is not a JSON object.")
		return false
	var report: Dictionary = parsed
	report["check_tier_thresholds"] = {
		"exceptional": ContractResolver.CHECK_EXCEPTIONAL_THRESHOLD,
		"success": ContractResolver.CHECK_SUCCESS_THRESHOLD,
		"partial": ContractResolver.CHECK_PARTIAL_THRESHOLD,
		"failure": ContractResolver.CHECK_FAILURE_THRESHOLD,
	}
	report["contract_tier_thresholds"] = {
		"exceptional": ContractResolver.CONTRACT_EXCEPTIONAL_THRESHOLD,
		"success": ContractResolver.CONTRACT_SUCCESS_THRESHOLD,
		"partial": ContractResolver.CONTRACT_PARTIAL_THRESHOLD,
		"failure": ContractResolver.CONTRACT_FAILURE_THRESHOLD,
	}
	var offer_index: Dictionary = {}
	for offer in offers:
		offer_index[String(offer.definition_id)] = offer
	for offer_report: Dictionary in report.get("offers", []):
		var contract_id: String = offer_report.get("contract_id", "")
		if not offer_index.has(contract_id):
			push_error("Difficulty report offer is no longer present: %s." % contract_id)
			return false
		for field_name: String in ["best_unprepared", "best_prepared"]:
			var candidate: Dictionary = offer_report.get(field_name, {})
			if candidate.is_empty():
				continue
			candidate["tier_counts"] = _tier_counts(
				catalog,
				state,
				offer_index[contract_id],
				candidate
			)
			offer_report[field_name] = candidate
	if not _write_report(report):
		push_error("Could not write finalized difficulty report.")
		return false
	print(JSON.stringify(report, "\t", false))
	return true


func _write_report(report: Dictionary) -> bool:
	var file := FileAccess.open(
		"res://tools/balance/task017_contract_difficulty_report.json",
		FileAccess.WRITE
	)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "\t", false))
	file.close()
	return true


func _legal_supply_options(catalog, offer, gold: int) -> Array:
	var contract = catalog.get_contract(offer.definition_id)
	var allowed: Array = []
	for supply in catalog.get_all_supplies():
		var matches := false
		for tag: StringName in supply.tags:
			if contract.allowed_supply_tags.has(tag):
				matches = true
				break
		if matches and supply.cost <= gold:
			allowed.append(supply)
	allowed.sort_custom(func(left, right) -> bool:
		return String(left.id) < String(right.id)
	)
	var options: Array = []
	var empty: Array[StringName] = []
	options.append(empty)
	for supply in allowed:
		var single: Array[StringName] = [supply.id]
		options.append(single)
	for left_index: int in range(allowed.size() - 1):
		for right_index: int in range(left_index + 1, allowed.size()):
			if allowed[left_index].cost + allowed[right_index].cost > gold:
				continue
			var pair: Array[StringName] = [
				allowed[left_index].id,
				allowed[right_index].id,
			]
			options.append(pair)
	return options


func _four_member_teams(member_ids: Array[StringName]) -> Array:
	var teams: Array = []
	for a: int in range(member_ids.size() - 3):
		for b: int in range(a + 1, member_ids.size() - 2):
			for c: int in range(b + 1, member_ids.size() - 1):
				for d: int in range(c + 1, member_ids.size()):
					var team: Array[StringName] = [
						member_ids[a],
						member_ids[b],
						member_ids[c],
						member_ids[d],
					]
					teams.append(team)
	return teams


func _index_by_id(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[value.id] = value
	return result


func _candidate_better(left: Dictionary, right: Dictionary) -> bool:
	var left_high := TIER_ORDER.find(StringName(left["likely_tier_high"]))
	var right_high := TIER_ORDER.find(StringName(right["likely_tier_high"]))
	if left_high != right_high:
		return left_high > right_high
	var left_low := TIER_ORDER.find(StringName(left["likely_tier_low"]))
	var right_low := TIER_ORDER.find(StringName(right["likely_tier_low"]))
	if left_low != right_low:
		return left_low > right_low
	return str(left["plan_signature"]) < str(right["plan_signature"])


func _stable_id_less(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
