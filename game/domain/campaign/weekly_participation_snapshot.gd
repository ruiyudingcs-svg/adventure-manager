class_name WeeklyParticipationSnapshot
extends RefCounted

var week_index: int:
	get:
		return _week_index
	set(_value):
		assert(false, "WeeklyParticipationSnapshot.week_index is read-only.")
var assigned_member_ids: Array[StringName]:
	get:
		return _assigned_member_ids.duplicate()
	set(_value):
		assert(false, "WeeklyParticipationSnapshot.assigned_member_ids is read-only.")

var _week_index: int
var _assigned_member_ids: Array[StringName]


func _init(p_week_index: int, p_assigned_member_ids: Array[StringName]) -> void:
	assert(p_week_index >= 0)
	_week_index = p_week_index
	for member_id: StringName in p_assigned_member_ids:
		if not member_id.is_empty() and not _assigned_member_ids.has(member_id):
			_assigned_member_ids.append(member_id)
	_assigned_member_ids.sort()


func duplicate_value() -> WeeklyParticipationSnapshot:
	return get_script().new(_week_index, _assigned_member_ids)


func signature() -> String:
	return "%d:%s" % [_week_index, _assigned_member_ids]
