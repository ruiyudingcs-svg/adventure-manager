class_name MessageState
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const MessageRequest = preload(
	"res://game/domain/messages/message_request.gd"
)

var instance_id: StringName
var week_index: int
var category: StringName
var source_type: StringName
var source_id: StringName
var title_key: StringName
var body_key: StringName
var parameters: Dictionary:
	get:
		return _parameters.duplicate(true)
	set(value):
		_parameters = value.duplicate(true)
var importance: StringName
var sort_order: int
var is_read: bool

var _parameters: Dictionary


## Constructor is intentionally not wrapped by a public create factory:
## WeeklyMessageProjector is the sole production owner of MessageState creation.
func _init(
	p_instance_id: StringName,
	p_week_index: int,
	p_category: StringName,
	p_source_type: StringName,
	p_source_id: StringName,
	p_title_key: StringName,
	p_body_key: StringName,
	p_parameters: Dictionary,
	p_importance: StringName,
	p_sort_order: int,
	p_is_read: bool = false
) -> void:
	instance_id = p_instance_id
	week_index = p_week_index
	category = p_category
	source_type = p_source_type
	source_id = p_source_id
	title_key = p_title_key
	body_key = p_body_key
	_parameters = p_parameters.duplicate(true)
	importance = p_importance
	sort_order = p_sort_order
	is_read = p_is_read


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(instance_id):
		errors.append(StableId.validation_error(instance_id, "MessageState.instance_id"))
	if week_index < 0:
		errors.append("MessageState.week_index must be non-negative.")
	if sort_order < 0:
		errors.append("MessageState.sort_order must be non-negative.")
	if not MessageRequest.ALLOWED_CATEGORIES.has(category):
		errors.append("MessageState.category is not allowed: %s." % category)
	if not MessageRequest.ALLOWED_IMPORTANCE.has(importance):
		errors.append("MessageState.importance is not allowed: %s." % importance)
	for pair: Array in [
		[source_type, "source_type"],
		[source_id, "source_id"],
		[title_key, "title_key"],
		[body_key, "body_key"],
	]:
		if not StableId.is_valid(pair[0]):
			errors.append(StableId.validation_error(
				pair[0],
				"MessageState.%s" % pair[1]
			))
	var request := MessageRequest.create(
		category,
		source_type,
		source_id,
		title_key,
		body_key,
		_parameters,
		importance,
		0
	)
	if request == null:
		errors.append("MessageState.parameters are invalid.")
	return errors


func duplicate_state() -> MessageState:
	return get_script().new(
		instance_id,
		week_index,
		category,
		source_type,
		source_id,
		title_key,
		body_key,
		_parameters,
		importance,
		sort_order,
		is_read
	)


## Content excludes read state because retry dedupe must preserve a user's
## existing read flag rather than treating it as conflicting projected content.
func content_signature() -> String:
	return "%s|%d|%s|%s|%s|%s|%s|%s|%s|%d" % [
		instance_id,
		week_index,
		category,
		source_type,
		source_id,
		title_key,
		body_key,
		MessageRequest._stable_variant_signature(_parameters),
		importance,
		sort_order,
	]


func signature() -> String:
	return "%s|%s" % [content_signature(), is_read]
