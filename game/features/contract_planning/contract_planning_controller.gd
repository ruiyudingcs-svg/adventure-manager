extends Node

const PlanningDraft = preload(
	"res://game/features/contract_planning/planning_draft.gd"
)
const PlanningPresenter = preload(
	"res://game/features/contract_planning/planning_presenter.gd"
)
const DeclineContractOfferCommand = preload(
	"res://game/domain/contracts/decline_contract_offer_command.gd"
)

@onready var view: Control = get_parent()

var _draft := PlanningDraft.new()
var _forecast_cache: Dictionary[String, Variant] = {}
var _session_override: Node
var _catalog_override: Node


func _ready() -> void:
	view.offer_selected.connect(_on_offer_selected)
	view.member_toggled.connect(_on_member_toggled)
	view.supply_toggled.connect(_on_supply_toggled)
	view.approach_selected.connect(_on_approach_selected)
	view.accept_requested.connect(_on_accept_requested)
	view.decline_requested.connect(_on_decline_requested)
	var session := _session()
	if session != null:
		session.campaign_replaced.connect(_on_campaign_replaced)
	call_deferred("_refresh")


func get_draft_for_testing() -> PlanningDraft:
	return _draft


func set_dependencies_for_testing(session: Node, catalog: Node) -> void:
	_session_override = session
	_catalog_override = catalog
	if view == null:
		view = get_parent()


func _on_offer_selected(offer_id: StringName) -> void:
	print("[UI DEBUG] planning offer selected: %s" % offer_id)
	_draft.select_offer(offer_id)
	_refresh()


func _on_member_toggled(member_id: StringName) -> void:
	var changed := _draft.toggle_member(member_id)
	print("[UI DEBUG] planning member toggled: %s -> %s" % [
		member_id,
		changed,
	])
	if not changed:
		view.call("show_inline_issue", "planning.validation.four_members")
	_refresh()


func _on_supply_toggled(supply_id: StringName) -> void:
	var changed := _draft.toggle_supply(supply_id)
	print("[UI DEBUG] planning supply toggled: %s -> %s" % [
		supply_id,
		changed,
	])
	if not changed:
		view.call("show_inline_issue", "planning.validation.two_supplies")
	_refresh()


func _on_approach_selected(approach: StringName) -> void:
	print("[UI DEBUG] planning approach selected: %s" % approach)
	_draft.set_approach(approach)
	_refresh()


func _on_accept_requested() -> void:
	var session := _session()
	print("[UI DEBUG] planning accept pressed: %s" % _draft.content_signature)
	var accepted: bool = false
	if session != null:
		accepted = session.call("accept_plan", _draft.to_command())
	print("[UI DEBUG] planning accept result: %s" % accepted)
	if accepted:
		_refresh()


func _on_decline_requested(offer_id: StringName) -> void:
	var session := _session()
	print("[UI DEBUG] planning decline pressed: %s" % offer_id)
	if session == null:
		print("[UI DEBUG] planning decline rejected: missing session")
		return
	var command = DeclineContractOfferCommand.create(offer_id)
	var declined: bool = session.call("decline_offer", command)
	print("[UI DEBUG] planning decline result: %s" % declined)
	if declined:
		if _draft.offer_instance_id == offer_id:
			_draft.reset()
		_forecast_cache.clear()
		_refresh()


func _on_campaign_replaced() -> void:
	_refresh()


func _refresh() -> void:
	var session := _session()
	var catalog := _catalog()
	if session == null or catalog == null:
		view.call("set_view_data", null)
		return
	var state = session.call("get_campaign_snapshot")
	if state == null:
		view.call("set_view_data", null)
		return
	if state.active_plan != null and _draft.offer_instance_id.is_empty():
		_draft.offer_instance_id = state.active_plan.contract_instance_id
		_draft.selected_member_ids.assign(
			state.active_plan.selected_member_ids
		)
		_draft.selected_supply_ids.assign(
			state.active_plan.selected_supply_ids
		)
		_draft.approach = state.active_plan.approach

	var contracts: Array = catalog.call("get_all_contracts")
	var factions: Array = catalog.call("get_all_factions")
	var adventurers: Array = catalog.call("get_all_adventurers")
	var supplies: Array = catalog.call("get_all_supplies")
	var clauses: Array = catalog.call("get_all_contract_clauses")
	var method_tags: Array = catalog.call("get_all_method_tags")
	var validation_issues := PackedStringArray()
	var forecast: Variant
	if not _draft.offer_instance_id.is_empty():
		var cache_key := "%s|%s" % [
			_draft.offer_instance_id,
			_draft.content_signature,
		]
		forecast = _forecast_cache.get(cache_key)
		if state.active_plan == null:
			validation_issues = session.call(
				"validate_plan",
				_draft.to_command()
			)
		if validation_issues.is_empty() and forecast == null:
			forecast = PlanningPresenter.build_forecast(
				state,
				_draft,
				contracts,
				adventurers,
				supplies,
				clauses,
				method_tags
			)
			if forecast != null and forecast.is_success():
				_forecast_cache[cache_key] = forecast.duplicate_value()
	elif state.active_plan == null:
		validation_issues.append("planning.validation.select_offer")
	view.call(
		"set_view_data",
		PlanningPresenter.present(
			state,
			_draft,
			contracts,
			factions,
			adventurers,
			supplies,
			clauses,
			forecast,
			validation_issues
		)
	)


func _session() -> Node:
	if _session_override != null:
		return _session_override
	return get_node_or_null("/root/GameSession")


func _catalog() -> Node:
	if _catalog_override != null:
		return _catalog_override
	return get_node_or_null("/root/DataCatalog")
