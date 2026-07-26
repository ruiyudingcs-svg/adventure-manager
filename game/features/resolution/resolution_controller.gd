extends Node

const ResolutionPresenter = preload(
	"res://game/features/resolution/resolution_presenter.gd"
)

@onready var view: Control = get_parent()


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.campaign_replaced.connect(_refresh)
	call_deferred("_refresh")


func _refresh() -> void:
	var session := get_node_or_null("/root/GameSession")
	var catalog := get_node_or_null("/root/DataCatalog")
	if session == null or catalog == null:
		view.call("set_view_data", null)
		return
	view.call(
		"set_view_data",
		ResolutionPresenter.present(
			session.call("get_resolution_review_snapshot"),
			catalog.call("get_all_contracts"),
			catalog.call("get_all_factions"),
			catalog.call("get_all_adventurers"),
			catalog.call("get_all_contract_clauses"),
			catalog.call("get_all_faction_actions")
		)
	)
