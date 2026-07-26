class_name LoadResult
extends RefCounted

const CampaignState = preload(
	"res://game/domain/campaign/campaign_state.gd"
)
const SaveIssue = preload("res://game/persistence/save_issue.gd")

var path: String
var campaign_setup_id: StringName
var saved_at_unix_seconds: int
var campaign_state: CampaignState
var canonical_state_json: String
var issues: Array[SaveIssue]

var recovery_path: String
var recovery_campaign_setup_id: StringName
var recovery_saved_at_unix_seconds: int
var recovery_state: CampaignState
var recovery_canonical_state_json: String


func is_success() -> bool:
	return campaign_state != null and issues.is_empty()


func has_recovery_candidate() -> bool:
	return recovery_state != null and not recovery_path.is_empty()
