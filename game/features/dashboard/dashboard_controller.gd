extends Node

const DashboardPresenter = preload(
	"res://game/features/dashboard/dashboard_presenter.gd"
)

@onready var view: Control = get_parent()


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.campaign_replaced.connect(_refresh)
		session.message_read.connect(_on_session_message_read)
	view.message_opened.connect(_on_message_opened)
	_refresh()


func _refresh() -> void:
	var session := get_node_or_null("/root/GameSession")
	var catalog := get_node_or_null("/root/DataCatalog")
	if session == null or catalog == null:
		view.call("set_view_data", null)
		return
	var state = session.call("get_campaign_snapshot")
	if state == null:
		view.call("set_view_data", null)
		return
	var situation = catalog.call(
		"get_situation",
		state.situation.definition_id
	)
	var view_data := DashboardPresenter.present(
		state,
		situation,
		catalog.call("get_all_contracts"),
		catalog.call("get_all_factions"),
		catalog.call("get_all_faction_actions"),
		catalog.call("get_all_problems")
	)
	view.call("set_view_data", view_data)


func _on_message_opened(message_id: StringName) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.call("mark_message_read", message_id)


func _on_session_message_read(_message_id: StringName) -> void:
	# GameSession emits this signal inside the clicked Button's pressed call.
	# Defer rebuilding the inbox until Godot releases that signal-call lock.
	call_deferred("_refresh")
