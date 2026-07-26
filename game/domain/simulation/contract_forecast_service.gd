class_name ContractForecastService
extends RefCounted

const StableSeed = preload("res://game/core/random/stable_seed.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const EffectiveContract = preload(
	"res://game/domain/contracts/effective_contract.gd"
)
const ContractPlan = preload("res://game/domain/contracts/contract_plan.gd")
const ContractResolver = preload(
	"res://game/domain/simulation/contract_resolver.gd"
)

const SAMPLE_COUNT: int = 64
const LOW_TIER_INDEX: int = 6
const HIGH_TIER_INDEX: int = 57
const TIER_ORDER: Array[StringName] = [
	&"severe",
	&"failure",
	&"partial",
	&"success",
	&"exceptional",
]


class ForecastRequest extends RefCounted:
	var offer_instance_id: StringName
	var plan_content_signature: String
	var locked_resolution_seed: int
	var effective_contract: EffectiveContract
	var plan: ContractPlan
	var guild_base_cohesion: int

	static func create(
		p_offer_instance_id: StringName,
		p_plan_content_signature: String,
		p_locked_resolution_seed: int,
		p_effective_contract: EffectiveContract,
		p_plan: ContractPlan,
		p_guild_base_cohesion: int
	) -> ForecastRequest:
		var request := ForecastRequest.new()
		request.offer_instance_id = p_offer_instance_id
		request.plan_content_signature = p_plan_content_signature
		request.locked_resolution_seed = p_locked_resolution_seed
		request.effective_contract = (
			p_effective_contract.duplicate_value()
			if p_effective_contract != null else null
		)
		request.plan = p_plan.duplicate_value() if p_plan != null else null
		request.guild_base_cohesion = p_guild_base_cohesion
		return request


class ForecastResult extends RefCounted:
	var likely_tier_low: StringName
	var likely_tier_high: StringName
	var supply_cost_total: int
	var member_injury_bands: Dictionary[StringName, StringName] = {}
	var clause_statuses: Dictionary[StringName, StringName] = {}
	var attitude_statuses: Dictionary[StringName, StringName] = {}
	var warning_reasons: Array[ReasonEntry]
	var sample_seeds: Array[int]
	var issues: PackedStringArray

	func is_success() -> bool:
		return issues.is_empty() \
			and not likely_tier_low.is_empty() \
			and not likely_tier_high.is_empty()

	func duplicate_value() -> ForecastResult:
		var copy := ForecastResult.new()
		copy.likely_tier_low = likely_tier_low
		copy.likely_tier_high = likely_tier_high
		copy.supply_cost_total = supply_cost_total
		copy.member_injury_bands = member_injury_bands.duplicate(true)
		copy.clause_statuses = clause_statuses.duplicate(true)
		copy.attitude_statuses = attitude_statuses.duplicate(true)
		for reason: ReasonEntry in warning_reasons:
			copy.warning_reasons.append(reason.duplicate_value())
		copy.sample_seeds.append_array(sample_seeds)
		copy.issues = issues.duplicate()
		return copy

	func content_signature() -> String:
		return "%s|%s|%d|%s|%s|%s|%s" % [
			likely_tier_low,
			likely_tier_high,
			supply_cost_total,
			_sorted_dictionary_signature(member_injury_bands),
			_sorted_dictionary_signature(clause_statuses),
			_sorted_dictionary_signature(attitude_statuses),
			_reason_signature(warning_reasons),
		]

	static func _sorted_dictionary_signature(values: Dictionary) -> String:
		var keys: Array[StringName] = []
		keys.assign(values.keys())
		keys.sort()
		var parts := PackedStringArray()
		for key: StringName in keys:
			parts.append("%s:%s" % [key, values[key]])
		return ",".join(parts)

	static func _reason_signature(reasons: Array[ReasonEntry]) -> String:
		var parts := PackedStringArray()
		for reason: ReasonEntry in reasons:
			parts.append("%s:%s:%s:%s" % [
				reason.target_id,
				reason.code,
				reason.amount,
				reason.visibility,
			])
		return ",".join(parts)


## Runs the official resolver over Gate F's fixed, isolated 64-seed stream.
## No sample can consume or reveal the Offer's locked resolution seed.
static func forecast(request: ForecastRequest) -> ForecastResult:
	var result := ForecastResult.new()
	if request == null:
		result.issues.append("Contract forecast requires a request.")
		return result
	if request.offer_instance_id.is_empty():
		result.issues.append("Contract forecast requires an Offer instance ID.")
	if request.plan_content_signature.is_empty():
		result.issues.append("Contract forecast requires a plan content signature.")
	if request.effective_contract == null:
		result.issues.append("Contract forecast requires an EffectiveContract.")
	if request.plan == null:
		result.issues.append("Contract forecast requires a ContractPlan.")
	if request.guild_base_cohesion < 0 or request.guild_base_cohesion > 100:
		result.issues.append("Contract forecast cohesion must be between 0 and 100.")
	if not result.issues.is_empty():
		return result

	var tiers: Array[StringName] = []
	var injury_totals: Dictionary[StringName, int] = {}
	var clause_satisfied_counts: Dictionary[StringName, int] = {}
	for sample_index: int in range(SAMPLE_COUNT):
		var sample_seed := _sample_seed(
			request.offer_instance_id,
			request.plan_content_signature,
			sample_index,
			request.locked_resolution_seed
		)
		result.sample_seeds.append(sample_seed)
		var resolved = ContractResolver.resolve(
			request.effective_contract,
			request.plan,
			sample_seed,
			request.guild_base_cohesion
		)
		if not resolved.is_success():
			for issue: String in resolved.errors:
				result.issues.append(
					"Forecast sample %d: %s" % [sample_index, issue]
				)
			return _clear_failed(result)
		var resolution = resolved.resolution
		tiers.append(resolution.result_tier)
		for member_outcome in resolution.member_outcomes:
			injury_totals[member_outcome.member_id] = (
				injury_totals.get(member_outcome.member_id, 0)
				+ member_outcome.any_injury_chance
			)
		for clause_result in resolution.clause_results:
			if not clause_satisfied_counts.has(clause_result.clause_id):
				clause_satisfied_counts[clause_result.clause_id] = 0
			if clause_result.satisfied:
				clause_satisfied_counts[clause_result.clause_id] += 1
		if sample_index == 0:
			result.supply_cost_total = resolution.supply_cost_total
			for attitude in resolution.attitude_results:
				result.attitude_statuses[attitude.member_id] = attitude.status
			result.warning_reasons = _planning_warnings(
				resolution.attitude_results
			)

	tiers.sort_custom(func(left: StringName, right: StringName) -> bool:
		return TIER_ORDER.find(left) < TIER_ORDER.find(right)
	)
	result.likely_tier_low = tiers[LOW_TIER_INDEX]
	result.likely_tier_high = tiers[HIGH_TIER_INDEX]
	for member_id: StringName in injury_totals:
		var average_chance: int = roundi(
			float(injury_totals[member_id]) / float(SAMPLE_COUNT)
		)
		result.member_injury_bands[member_id] = _injury_band(average_chance)
	for clause_id: StringName in clause_satisfied_counts:
		result.clause_statuses[clause_id] = _clause_status(
			clause_satisfied_counts[clause_id]
		)
	return result


static func _sample_seed(
	offer_instance_id: StringName,
	plan_content_signature: String,
	sample_index: int,
	locked_resolution_seed: int
) -> int:
	var fragments: Array[StringName] = [
		&"contract_forecast",
		offer_instance_id,
		StringName(plan_content_signature),
		StringName(str(sample_index)),
	]
	var sample_seed: int = StableSeed.derive(0, fragments)
	var retry_index: int = 1
	while sample_seed == locked_resolution_seed:
		var retried: Array[StringName] = fragments.duplicate()
		retried.append(StringName("retry_%d" % retry_index))
		sample_seed = StableSeed.derive(0, retried)
		retry_index += 1
	return sample_seed


static func _injury_band(average_chance: int) -> StringName:
	if average_chance <= 14:
		return &"low"
	if average_chance <= 29:
		return &"medium"
	if average_chance <= 49:
		return &"high"
	return &"severe"


static func _clause_status(satisfied_count: int) -> StringName:
	if satisfied_count == SAMPLE_COUNT:
		return &"expected_met"
	if satisfied_count >= 45:
		return &"favorable"
	if satisfied_count >= 20:
		return &"uncertain"
	if satisfied_count >= 1:
		return &"high_risk"
	return &"expected_conflict"


static func _planning_warnings(attitudes: Array) -> Array[ReasonEntry]:
	var warnings: Array[ReasonEntry] = []
	for attitude in attitudes:
		if attitude.status != &"reluctant" and attitude.status != &"opposed":
			continue
		for reason: ReasonEntry in attitude.reason_entries:
			if (
				reason.visibility == ReasonEntry.VISIBILITY_PLAYER
				and reason.amount < 0.0
			):
				warnings.append(reason.duplicate_value())
	warnings.sort_custom(func(left: ReasonEntry, right: ReasonEntry) -> bool:
		var left_key := "%s|%s|%s" % [
			left.target_id,
			left.source_id,
			left.code,
		]
		var right_key := "%s|%s|%s" % [
			right.target_id,
			right.source_id,
			right.code,
		]
		return left_key < right_key
	)
	if warnings.size() > 2:
		warnings.resize(2)
	return warnings


static func _clear_failed(result: ForecastResult) -> ForecastResult:
	result.likely_tier_low = &""
	result.likely_tier_high = &""
	result.supply_cost_total = 0
	result.member_injury_bands.clear()
	result.clause_statuses.clear()
	result.attitude_statuses.clear()
	result.warning_reasons.clear()
	return result
