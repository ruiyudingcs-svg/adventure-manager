extends SceneTree

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


func _initialize() -> void:
	var reports: Array[Dictionary] = []
	var issues := PackedStringArray()
	for index: int in range(RUNS.size()):
		var definition: Dictionary = RUNS[index]
		var result = FullCampaignDriver.run_campaign(
			definition["policy"],
			definition["seed"],
			"audit_%02d" % index
		)
		reports.append(result.report)
		issues.append_array(result.issues)
	var report_json := JSON.stringify({
		"generated_by": "Task017 read-only balance audit",
		"runs": reports,
		"issues": Array(issues),
	}, "  ", true, true)
	var output_path := "res://tools/balance/task017_balance_report.json"
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		issues.append("Could not write %s." % output_path)
	else:
		output.store_string(report_json + "\n")
		output.close()
	print(report_json)
	quit(0 if issues.is_empty() else 1)
