## Projects the shell without retaining a CampaignState reference.
class_name AppShellPresenter
extends RefCounted

const AppShellViewData = preload(
	"res://game/features/shared/app_shell_view_data.gd"
)


static func present(
	state,
	session_phase: StringName,
	route_id: StringName
) -> AppShellViewData:
	var view_data := AppShellViewData.new()
	view_data.route_id = route_id
	view_data.page_title_key = StringName("nav.%s" % route_id)
	view_data.session_phase = session_phase
	view_data.resolution_enabled = session_phase == &"resolution_review"
	if state == null:
		view_data.primary_action_visible = false
		return view_data
	view_data.week_index = state.week_index
	view_data.gold = state.guild.gold
	view_data.reputation = state.guild.reputation
	for message in state.message_history:
		if not message.is_read:
			view_data.unread_messages += 1
	match session_phase:
		&"planning":
			view_data.primary_action_visible = true
			view_data.primary_action_enabled = true
			view_data.primary_action_key = (
				&"toolbar.dispatch_and_end_week"
				if state.active_plan != null
				else &"toolbar.end_week"
			)
		&"resolution_review":
			view_data.primary_action_visible = true
			view_data.primary_action_enabled = true
			view_data.primary_action_key = &"toolbar.enter_next_week"
		_:
			view_data.primary_action_visible = false
			view_data.primary_action_enabled = false
	return view_data
