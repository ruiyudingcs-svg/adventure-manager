extends RefCounted

const StableSeed = preload("res://game/core/random/stable_seed.gd")


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var fragments: Array[StringName] = [&"week_1", &"contract_resolution"]
	var expected_seed: int = StableSeed.derive(42, fragments)
	var expected_sequence: Array[int] = _random_sequence(StableSeed.create_rng(42, fragments))

	var repeats_are_identical := true
	for _iteration: int in range(100):
		if StableSeed.derive(42, fragments) != expected_seed:
			repeats_are_identical = false
			break
		if _random_sequence(StableSeed.create_rng(42, fragments)) != expected_sequence:
			repeats_are_identical = false
			break
	results.append(_result(
		"same seed and fragments repeat 100 times",
		repeats_are_identical,
		"Derived seed or RNG sequence changed across repetitions."
	))

	var stream_a_fragments: Array[StringName] = [&"contract_alpha", &"approach"]
	var stream_b_fragments: Array[StringName] = [&"contract_beta", &"approach"]
	var stream_a_before: Array[int] = _random_sequence(StableSeed.create_rng(77, stream_a_fragments))
	var stream_b: RandomNumberGenerator = StableSeed.create_rng(77, stream_b_fragments)
	for _draw: int in range(50):
		stream_b.randi()
	var stream_a_after: Array[int] = _random_sequence(StableSeed.create_rng(77, stream_a_fragments))
	results.append(_result(
		"derived RNG streams are isolated",
		stream_a_before == stream_a_after \
			and StableSeed.derive(77, stream_a_fragments) != StableSeed.derive(77, stream_b_fragments),
		"Consuming one derived stream changed another stream."
	))

	var boundary_a: Array[StringName] = [&"ab", &"c"]
	var boundary_b: Array[StringName] = [&"a", &"bc"]
	results.append(_result(
		"fragment boundaries are unambiguous",
		StableSeed.derive(5, boundary_a) != StableSeed.derive(5, boundary_b),
		"Different fragment boundaries produced the same derived seed."
	))

	var unicode_fragments: Array[StringName] = [StringName("巨龙_β"), StringName("阶段_一")]
	results.append(_result(
		"non-ASCII seed has stable golden value",
		StableSeed.derive(987654321, unicode_fragments) == 1999668203,
		"UTF-8 seed encoding changed from its golden value."
	))
	return results


func _random_sequence(random: RandomNumberGenerator) -> Array[int]:
	var sequence: Array[int] = []
	for _draw: int in range(8):
		sequence.append(random.randi_range(-100000, 100000))
	return sequence


func _result(test_name: String, passed: bool, failure_message: String) -> Dictionary:
	return {
		"name": test_name,
		"passed": passed,
		"message": "" if passed else failure_message,
	}
