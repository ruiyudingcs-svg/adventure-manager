extends RefCounted

const FullCampaignDriver = preload(
	"res://tests/scenarios/full_campaign_driver.gd"
)

const RUNS: Array[Dictionary] = [
	{"policy": &"evacuation", "seed": 170101},
	{"policy": &"arcane", "seed": 170102},
	{"policy": &"necrotic", "seed": 170103},
	{"policy": &"skip_all", "seed": 170104},
	{"policy": &"high_reward", "seed": 170105},
	{"policy": &"low_risk", "seed": 170106},
	{"policy": &"free_faction", "seed": 170107},
	{"policy": &"arcane_faction", "seed": 170108},
	{"policy": &"high_supply", "seed": 170109},
	{"policy": &"fatigue_rotation", "seed": 170110},
]


func run(_scene_tree: SceneTree) -> Array[Dictionary]:
	var reports: Array = []
	var signatures: Array[String] = []
	var issues := PackedStringArray()
	for index: int in range(RUNS.size()):
		var definition: Dictionary = RUNS[index]
		var result = FullCampaignDriver.run_campaign(
			definition["policy"],
			definition["seed"],
			"run_%02d" % index
		)
		reports.append(result.report)
		signatures.append(result.signature)
		issues.append_array(result.issues)
		if result.report.get("ending_week", 0) < 10 \
				or result.report.get("ending_week", 0) > 15:
			issues.append("Run %d ended outside week 10..15." % index)
		if result.report.get("save_load_checkpoints", 0) != 1:
			issues.append("Run %d missed its planning checkpoint." % index)

	var repeat = FullCampaignDriver.run_campaign(
		RUNS[0]["policy"],
		RUNS[0]["seed"],
		"repeat"
	)
	issues.append_array(repeat.issues)
	if repeat.signature != signatures[0]:
		issues.append(
			"Repeated seed and policy changed the final signature: %s; "
			% _first_difference(signatures[0], repeat.signature)
			+ "first=%s repeat=%s"
			% [reports[0], repeat.report]
		)

	var ending_ids: Dictionary = {}
	for report: Dictionary in reports:
		var ending_id: String = report.get("ending_id", "")
		ending_ids[ending_id] = int(ending_ids.get(ending_id, 0)) + 1
	return [
		_result(
			"ten real GameSession campaigns end with save/load checkpoints",
			issues.is_empty(),
			"; ".join(issues)
		),
		_result(
			"same seed and policy repeat the full campaign signature",
			repeat.signature == signatures[0],
			"Repeated run diverged."
		),
		_result(
			"balance sample records at least two natural ending outcomes",
			ending_ids.size() >= 2,
			"All ten policy samples collapsed to one ending: %s." % ending_ids
		),
	]


func _result(name: String, passed: bool, message: String) -> Dictionary:
	return {"name": name, "passed": passed, "message": message}


func _first_difference(left: String, right: String) -> String:
	var common_size: int = mini(left.length(), right.length())
	for index: int in range(common_size):
		if left[index] != right[index]:
			var start: int = maxi(0, index - 80)
			return "index=%d left=%s right=%s" % [
				index,
				left.substr(start, 160),
				right.substr(start, 160),
			]
	return "length left=%d right=%d" % [left.length(), right.length()]
