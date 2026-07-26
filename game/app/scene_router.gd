## Whitelisted feature router; it owns scenes but never CampaignState.
extends Node

const DASHBOARD_SCENE = preload(
	"res://game/features/dashboard/dashboard_view.tscn"
)
const ROSTER_SCENE = preload("res://game/features/roster/roster_view.tscn")
const CONTRACTS_SCENE = preload(
	"res://game/features/contract_planning/contract_planning_view.tscn"
)
const RESOLUTION_SCENE = preload(
	"res://game/features/resolution/resolution_view.tscn"
)
const ENDING_SCENE = preload("res://game/features/ending/ending_view.tscn")

const ROUTE_DASHBOARD: StringName = &"dashboard"
const ROUTE_CONTRACTS: StringName = &"contracts"
const ROUTE_ROSTER: StringName = &"roster"
const ROUTE_RESOLUTION: StringName = &"resolution"
const ROUTE_ENDING: StringName = &"ending"
const ROUTES: Array[StringName] = [
	ROUTE_DASHBOARD,
	ROUTE_CONTRACTS,
	ROUTE_ROSTER,
	ROUTE_RESOLUTION,
	ROUTE_ENDING,
]

signal route_changed(route_id: StringName)
signal ending_action_requested(action_id: StringName)

var _screen_container: Control
var _current_route: StringName = &""
var _session_override: Node


func bind_screen_container(container: Control) -> bool:
	if container == null:
		return false
	_screen_container = container
	_clear_container()
	_current_route = &""
	return true


## Mounts exactly one main feature scene for an allowed and enabled route.
func navigate(route_id: StringName) -> bool:
	print("[UI DEBUG] router navigate requested: %s" % route_id)
	if _screen_container == null \
			or not ROUTES.has(route_id) \
			or not is_route_enabled(route_id):
		print(
			"[UI DEBUG] router rejected: container=%s known=%s enabled=%s"
			% [
				_screen_container != null,
				ROUTES.has(route_id),
				is_route_enabled(route_id),
			]
		)
		return false
	var screen: Control
	match route_id:
		ROUTE_DASHBOARD:
			screen = DASHBOARD_SCENE.instantiate()
		ROUTE_ROSTER:
			screen = ROSTER_SCENE.instantiate()
		ROUTE_CONTRACTS:
			screen = CONTRACTS_SCENE.instantiate()
		ROUTE_RESOLUTION:
			screen = RESOLUTION_SCENE.instantiate()
		ROUTE_ENDING:
			screen = ENDING_SCENE.instantiate()
	if screen == null:
		print("[UI DEBUG] router rejected: scene instantiation returned null")
		return false
	_clear_container()
	_screen_container.add_child(screen)
	_current_route = route_id
	route_changed.emit(route_id)
	print("[UI DEBUG] router mounted: %s" % route_id)
	return true


func is_route_enabled(route_id: StringName) -> bool:
	if not ROUTES.has(route_id):
		return false
	var session := _session()
	if session != null and session.call("get_phase") == &"ended":
		return route_id == ROUTE_ENDING
	if route_id == ROUTE_ENDING:
		return false
	if route_id != ROUTE_RESOLUTION:
		return true
	return session != null and session.call("has_resolution_review")


func get_current_route() -> StringName:
	return _current_route


func get_screen_count() -> int:
	return 0 if _screen_container == null else _screen_container.get_child_count()


## Test seam; production resolves the GameSession Autoload.
func set_session_for_testing(session: Node) -> void:
	_session_override = session


func request_ending_action(action_id: StringName) -> void:
	if action_id == &"new_game" or action_id == &"title":
		ending_action_requested.emit(action_id)


func _session() -> Node:
	if _session_override != null:
		return _session_override
	return get_node_or_null("/root/GameSession")


func _clear_container() -> void:
	if _screen_container == null:
		return
	for child: Node in _screen_container.get_children():
		_screen_container.remove_child(child)
		child.free()
