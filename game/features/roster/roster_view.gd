## Renders RosterViewData; member selection never touches CampaignState.
extends Control

const UiText = preload("res://game/features/shared/ui_text.gd")
const RosterViewData = preload(
	"res://game/features/roster/roster_view_data.gd"
)

@onready var empty_label: Label = %EmptyLabel
@onready var content: HSplitContainer = %Content
@onready var member_list: VBoxContainer = %MemberList
@onready var tabs: TabContainer = %Tabs
@onready var member_details: VBoxContainer = %MemberDetails
@onready var relationships_list: VBoxContainer = %RelationshipsList
@onready var records_list: VBoxContainer = %RecordsList

var _view_data: RosterViewData
var _selected_member_id: StringName


func _ready() -> void:
	tabs.tab_changed.connect(func(tab_index: int) -> void:
		print("[UI DEBUG] roster tab pressed: %d" % tab_index)
	)
	tabs.set_tab_title(0, UiText.get_text(&"tab.roster.members"))
	tabs.set_tab_title(1, UiText.get_text(&"tab.roster.relationships"))
	tabs.set_tab_title(2, UiText.get_text(&"tab.roster.records"))
	_render()


func set_view_data(value: RosterViewData) -> void:
	_view_data = value
	if _view_data != null \
			and not _view_data.members.is_empty() \
			and not _has_member(_selected_member_id):
		_selected_member_id = _view_data.members[0].id
	if is_node_ready():
		_render()


func _render() -> void:
	var has_data := _view_data != null and not _view_data.members.is_empty()
	empty_label.visible = not has_data
	content.visible = has_data
	if not has_data:
		return
	_render_member_list()
	_render_selected()


func _render_member_list() -> void:
	_clear(member_list)
	for item: RosterViewData.MemberItem in _view_data.members:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = item.id == _selected_member_id
		button.text = "%s\n%s · %s %d" % [
			UiText.get_text(item.name_key, item.fallback_name),
			UiText.get_text(item.class_key),
			UiText.get_text(&"label.fatigue"),
			item.fatigue,
		]
		button.pressed.connect(_select_member.bind(item.id))
		member_list.add_child(button)


func _render_selected() -> void:
	var item := _selected()
	if item == null:
		return
	_clear(member_details)
	_clear(relationships_list)
	_clear(records_list)
	var heading := Label.new()
	heading.text = "%s · %s" % [
		UiText.get_text(item.name_key, item.fallback_name),
		UiText.get_text(item.class_key),
	]
	heading.add_theme_font_size_override("font_size", 24)
	member_details.add_child(heading)
	member_details.add_child(_line("%s %d   %s %d   %s %d" % [
		UiText.get_text(&"label.fatigue"),
		item.fatigue,
		UiText.get_text(&"label.morale"),
		item.morale,
		UiText.get_text(&"label.injury"),
		item.injury_severity,
	]))
	member_details.add_child(_line("%s %d   %s %s   %s %d" % [
		UiText.get_text(&"label.recovery_weeks"),
		item.recovery_weeks,
		UiText.get_text(&"label.availability"),
		UiText.get_text(
			&"status.available" if item.is_available else &"status.unavailable"
		),
		UiText.get_text(&"label.wage"),
		item.wage,
	]))
	member_details.add_child(_section_heading(
		UiText.get_text(&"roster.capabilities")
	))
	for capability_id: StringName in item.capabilities:
		member_details.add_child(_line("%s：%d" % [
			UiText.get_text(StringName("capability.%s" % capability_id)),
			item.capabilities[capability_id],
		]))
	member_details.add_child(_section_heading(
		UiText.get_text(&"roster.traits")
	))
	var trait_names := PackedStringArray()
	for trait_key: StringName in item.trait_keys:
		trait_names.append(UiText.get_text(trait_key))
	member_details.add_child(_line("、".join(trait_names)))
	member_details.add_child(_section_heading(
		UiText.get_text(&"roster.values")
	))
	for value_id: StringName in item.values:
		member_details.add_child(_line("%s：%+d" % [
			UiText.get_text(StringName("value.%s" % value_id)),
			item.values[value_id],
		]))
	member_details.add_child(_line("%s %d · %s %d" % [
		UiText.get_text(&"label.recent_assignments"),
		item.recent_assignment_count,
		UiText.get_text(&"label.recent_neglect"),
		item.recent_neglect_count,
	]))
	if item.relationships.is_empty():
		relationships_list.add_child(_line(
			UiText.get_text(&"roster.no_relationships")
		))
	for relationship: RosterViewData.RelationshipItem in item.relationships:
		relationships_list.add_child(_line("%s：%+d" % [
			UiText.get_text(relationship.target_name_key),
			relationship.value,
		]))
	if item.recent_records.is_empty():
		records_list.add_child(_line(
			UiText.get_text(&"roster.no_records")
		))
	for record: RosterViewData.RecordItem in item.recent_records:
		records_list.add_child(_line("%s %d · %s · %s" % [
			UiText.get_text(&"label.week"),
			record.week_index,
			UiText.get_text(record.contract_title_key),
			UiText.get_text(StringName("tier.%s" % record.result_tier)),
		]))


func _select_member(member_id: StringName) -> void:
	print("[UI DEBUG] roster member pressed: %s" % member_id)
	_selected_member_id = member_id
	_render()


func _selected() -> RosterViewData.MemberItem:
	if _view_data == null:
		return null
	for item: RosterViewData.MemberItem in _view_data.members:
		if item.id == _selected_member_id:
			return item
	return null


func _has_member(member_id: StringName) -> bool:
	if _view_data == null:
		return false
	for item: RosterViewData.MemberItem in _view_data.members:
		if item.id == member_id:
			return true
	return false


func _section_heading(text: String) -> Label:
	var label := _line(text)
	label.add_theme_font_size_override("font_size", 18)
	label.modulate = Color(0.92, 0.82, 0.56)
	return label


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		# Member selection rebuilds this list from the selected Button's own
		# pressed signal, so destruction must wait until Godot unlocks the call.
		child.queue_free()
