extends Node

const EndingPresenter = preload(
	"res://game/features/ending/ending_presenter.gd"
)

@onready var view: Control = get_parent()


func _ready() -> void:
	view.new_game_requested.connect(_on_new_game_requested)
	view.title_requested.connect(_on_title_requested)
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
	view.call("set_view_data", EndingPresenter.present(
		state,
		catalog.call("get_situation", state.situation.definition_id),
		catalog.call("get_all_endings"),
		catalog.call("get_all_problems"),
		catalog.call("get_all_contracts"),
		catalog.call("get_all_factions"),
		catalog.call("get_all_adventurers")
	))


func _on_new_game_requested() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router != null:
		router.call("request_ending_action", &"new_game")


func _on_title_requested() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router != null:
		router.call("request_ending_action", &"title")
