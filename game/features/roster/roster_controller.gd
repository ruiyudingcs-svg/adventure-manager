extends Node

const RosterPresenter = preload(
	"res://game/features/roster/roster_presenter.gd"
)

@onready var view: Control = get_parent()


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.campaign_replaced.connect(_refresh)
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
	var setups: Array = catalog.call("get_all_campaign_setups")
	var setup = setups[0] if setups.size() == 1 else null
	view.call("set_view_data", RosterPresenter.present(
		state,
		setup,
		catalog.call("get_all_adventurers"),
		catalog.call("get_all_contracts")
	))
