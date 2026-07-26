extends RefCounted

const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")
const AdventurerDefinition = preload("res://game/domain/adventurers/adventurer_definition.gd")
const AdventurerState = preload("res://game/domain/adventurers/adventurer_state.gd")
const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")
const CapabilityWeights = preload("res://game/domain/contracts/capability_weights.gd")
const TeamCapabilityCalculator = preload("res://game/domain/simulation/team_capability_calculator.gd")
const AdventurerFixtures = preload("res://tests/fixtures/adventurer_fixtures.gd")

const FLOAT_EPSILON: float = 0.000001


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var bundles: Array[Dictionary] = AdventurerFixtures.create_standard_team_bundles()
	var team: Array[AdventurerSnapshot] = AdventurerFixtures.snapshots_from_bundles(bundles)
	var profile: TeamCapabilityCalculator.TeamCapabilityProfile = TeamCapabilityCalculator.aggregate(team)

	results.append(_result(
		"single-dimension team aggregation matches hand calculation",
		absf(profile.frontline - 81.0) < FLOAT_EPSILON,
		"Expected frontline 100*0.55 + 80*0.25 + average(40,20)*0.20 = 81.0."
	))
	results.append(_result(
		"six team capability dimensions match hand calculations",
		_profile_matches(profile, [81.0, 76.0, 83.0, 85.0, 65.0, 75.0]),
		"One or more aggregated capability dimensions differed from the hand calculation."
	))

	var weights := CapabilityWeights.create(0.20, 0.15, 0.25, 0.10, 0.20, 0.10)
	results.append(_result(
		"six-dimensional capability match is correct",
		absf(TeamCapabilityCalculator.calculate_match(team, weights) - 77.35) < FLOAT_EPSILON,
		"Expected the weighted team capability match to equal 77.35."
	))

	var all_permutations_match := true
	for permutation: Array[AdventurerSnapshot] in _permutations_of_four(team):
		var permutation_profile: TeamCapabilityCalculator.TeamCapabilityProfile = TeamCapabilityCalculator.aggregate(
			permutation
		)
		if not _profile_matches(permutation_profile, [81.0, 76.0, 83.0, 85.0, 65.0, 75.0]):
			all_permutations_match = false
			break
	results.append(_result(
		"all 24 member permutations aggregate identically",
		all_permutations_match,
		"Team aggregation depended on input member order."
	))

	var tied_team: Array[AdventurerSnapshot] = []
	var tied_ids: Array[StringName] = [&"tie_alpha", &"tie_bravo", &"tie_charlie", &"tie_delta"]
	for tied_id: StringName in tied_ids:
		var tied_bundle: Dictionary = AdventurerFixtures.create_member_bundle(
			tied_id,
			CapabilityBlock.create(50, 50, 50, 50, 50, 50)
		)
		tied_team.append(tied_bundle["snapshot"] as AdventurerSnapshot)
	var tied_forward: TeamCapabilityCalculator.TeamCapabilityProfile = TeamCapabilityCalculator.aggregate(tied_team)
	tied_team.reverse()
	var tied_reverse: TeamCapabilityCalculator.TeamCapabilityProfile = TeamCapabilityCalculator.aggregate(tied_team)
	results.append(_result(
		"equal member values remain stable",
		_profile_matches(tied_forward, [50.0, 50.0, 50.0, 50.0, 50.0, 50.0]) \
			and _profile_matches(tied_reverse, [50.0, 50.0, 50.0, 50.0, 50.0, 50.0]),
		"Equal capability values changed when member order was reversed."
	))

	var three_members: Array[AdventurerSnapshot] = [team[0], team[1], team[2]]
	var duplicate_members: Array[AdventurerSnapshot] = [team[0], team[1], team[2], team[0]]
	var extra_bundle: Dictionary = AdventurerFixtures.create_member_bundle(
		&"member_echo",
		CapabilityBlock.create(10, 10, 10, 10, 10, 10)
	)
	var five_members: Array[AdventurerSnapshot] = [
		team[0],
		team[1],
		team[2],
		team[3],
		extra_bundle["snapshot"] as AdventurerSnapshot,
	]
	results.append(_result(
		"invalid team sizes and duplicate IDs are rejected",
		not TeamCapabilityCalculator.validate_team(three_members).is_empty() \
			and not TeamCapabilityCalculator.validate_team(five_members).is_empty() \
			and not TeamCapabilityCalculator.validate_team(duplicate_members).is_empty(),
		"Expected fewer/more than four members and duplicate IDs to fail validation."
	))

	var first_definition: AdventurerDefinition = bundles[0]["definition"] as AdventurerDefinition
	var first_state: AdventurerState = bundles[0]["state"] as AdventurerState
	results.append(_result(
		"team calculation leaves fixture sources unchanged",
		first_definition.base_capabilities.is_equal_to(CapabilityBlock.create(100, 20, 80, 40, 60, 90)) \
			and first_state.get_fatigue() == 10 \
			and first_state.get_relationship_deltas()[&"fixture_contact"] == 3,
		"Team calculation mutated a Definition or State fixture."
	))
	return results


func _permutations_of_four(
	members: Array[AdventurerSnapshot]
) -> Array[Array]:
	var permutations: Array[Array] = []
	for first: int in range(4):
		for second: int in range(4):
			if second == first:
				continue
			for third: int in range(4):
				if third == first or third == second:
					continue
				for fourth: int in range(4):
					if fourth == first or fourth == second or fourth == third:
						continue
					var permutation: Array[AdventurerSnapshot] = [
						members[first],
						members[second],
						members[third],
						members[fourth],
					]
					permutations.append(permutation)
	return permutations


func _profile_matches(
	profile: TeamCapabilityCalculator.TeamCapabilityProfile,
	expected: Array
) -> bool:
	return absf(profile.frontline - float(expected[0])) < FLOAT_EPSILON \
		and absf(profile.offense - float(expected[1])) < FLOAT_EPSILON \
		and absf(profile.scouting - float(expected[2])) < FLOAT_EPSILON \
		and absf(profile.support - float(expected[3])) < FLOAT_EPSILON \
		and absf(profile.arcana - float(expected[4])) < FLOAT_EPSILON \
		and absf(profile.discipline - float(expected[5])) < FLOAT_EPSILON


func _result(test_name: String, passed: bool, failure_message: String) -> Dictionary:
	return {
		"name": test_name,
		"passed": passed,
		"message": "" if passed else failure_message,
	}
