extends RefCounted

const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const AdventurerDefinition = preload("res://game/domain/adventurers/adventurer_definition.gd")
const AdventurerState = preload("res://game/domain/adventurers/adventurer_state.gd")
const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const CapabilityWeights = preload("res://game/domain/contracts/capability_weights.gd")
const ReasonEntry = preload("res://game/core/result/reason_entry.gd")
const AdventurerFixtures = preload("res://tests/fixtures/adventurer_fixtures.gd")

const FLOAT_EPSILON: float = 0.000001


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var boundary_block := CapabilityBlock.create(0, 100, 0, 100, 0, 100)
	results.append(_result(
		"capability boundaries are accepted",
		boundary_block != null,
		"Expected 0 and 100 capability values to be valid."
	))
	results.append(_result(
		"capability out-of-range values are rejected",
		CapabilityBlock.create(-1, 0, 0, 0, 0, 0) == null \
			and CapabilityBlock.create(0, 0, 0, 0, 0, 101) == null,
		"Expected capability values outside 0..100 to fail construction."
	))

	var block_copy: CapabilityBlock = boundary_block.duplicate_value()
	results.append(_result(
		"capability copy is equal and independent",
		block_copy != boundary_block and block_copy.is_equal_to(boundary_block),
		"CapabilityBlock copy reused the source instance or changed values."
	))

	var valid_weights := CapabilityWeights.create(0.2, 0.2, 0.2, 0.2, 0.2, 0.0)
	results.append(_result(
		"capability weights validate and calculate dot product",
		valid_weights != null \
			and absf(valid_weights.weighted_dot(CapabilityBlock.create(100, 80, 60, 40, 20, 0)) - 60.0) < FLOAT_EPSILON,
		"Expected the hand-calculated weighted dot product to equal 60.0."
	))
	results.append(_result(
		"invalid capability weights are rejected",
		CapabilityWeights.create(-0.1, 0.3, 0.2, 0.2, 0.2, 0.2) == null \
			and CapabilityWeights.create(0.1, 0.1, 0.1, 0.1, 0.1, 0.1) == null \
			and CapabilityWeights.create(0.3, 0.3, 0.3, 0.3, 0.0, 0.0) == null,
		"Expected negative, under-sum, and over-sum weights to fail construction."
	))

	var base_values := IdeologyVector.create_base(-5, 5, -5, 5, 0)
	var task_values := IdeologyVector.create_task_accumulation(-10, 10, 0, 3, -4)
	results.append(_result(
		"ideology construction separates base and task ranges",
		base_values != null \
			and task_values != null \
			and IdeologyVector.create_base(6, 0, 0, 0, 0) == null \
			and IdeologyVector.create_task_accumulation(11, 0, 0, 0, 0) == null,
		"Base -5..5 and task -10..10 boundaries were not enforced independently."
	))
	results.append(_result(
		"adventurer definitions reject task-range base values",
		AdventurerDefinition.create(
			&"invalid_values_member",
			"Invalid",
			&"fixture_class",
			CapabilityBlock.create(10, 10, 10, 10, 10, 10),
			IdeologyVector.create_task_accumulation(10, 0, 0, 0, 0)
		) == null,
		"AdventurerDefinition accepted an ideology value outside the hero base range."
	))
	var summed_values: IdeologyVector = base_values.added_and_clamped_for_task(
		IdeologyVector.create_base(-5, 5, 5, 5, -5)
	)
	results.append(_result(
		"ideology addition clamps each task dimension",
		summed_values.protect_life == -10 \
			and summed_values.respect_authority == 10 \
			and summed_values.seek_knowledge == 0 \
			and summed_values.pursue_profit == 10 \
			and summed_values.taboo_tolerance == -5,
		"Task ideology addition did not clamp dimension values to -10..10."
	))
	results.append(_result(
		"ideology dot product is deterministic",
		base_values.dot(IdeologyVector.create_base(1, 1, 1, 1, 1)) == 0,
		"IdeologyVector dot product differed from the hand calculation."
	))

	var reason := ReasonEntry.create(
		&"fixture_reason",
		&"capability",
		&"member_alpha",
		&"team",
		2.0,
		&"reason.fixture",
		{"nested": {"value": 1}},
		&"approach",
		&"player"
	)
	results.append(_result(
		"reason visibility whitelist is enforced",
		reason != null \
			and ReasonEntry.create(&"debug", &"test", &"source", &"target", 0.0, &"debug", {}, &"", &"debug") != null \
			and ReasonEntry.create(&"bad", &"test", &"source", &"target", 0.0, &"bad", {}, &"", &"private") == null,
		"ReasonEntry accepted a visibility outside player/debug."
	))

	var bundle: Dictionary = AdventurerFixtures.create_member_bundle(
		&"copy_subject",
		CapabilityBlock.create(70, 60, 50, 40, 30, 20),
		15,
		55,
		5
	)
	var definition: AdventurerDefinition = bundle["definition"] as AdventurerDefinition
	var state: AdventurerState = bundle["state"] as AdventurerState
	var snapshot: AdventurerSnapshot = bundle["snapshot"] as AdventurerSnapshot
	var state_copy: AdventurerState = state.duplicate_state()
	state_copy.set_fatigue(90)
	state_copy.set_relationship_delta(&"fixture_contact", 99)
	var snapshot_relationships: Dictionary[StringName, int] = snapshot.relationship_values
	snapshot_relationships[&"fixture_contact"] = -999
	results.append(_result(
		"definition state and snapshot copies do not alias",
		state.get_fatigue() == 15 \
			and state.get_relationship_deltas()[&"fixture_contact"] == 3 \
			and snapshot.relationship_values[&"fixture_contact"] == 7 \
			and definition.base_capabilities != definition.base_capabilities \
			and definition.base_capabilities.is_equal_to(snapshot.capabilities),
		"A copied nested value mutated its source Definition, State, or Snapshot."
	))
	return results


func _result(test_name: String, passed: bool, failure_message: String) -> Dictionary:
	return {
		"name": test_name,
		"passed": passed,
		"message": "" if passed else failure_message,
	}
