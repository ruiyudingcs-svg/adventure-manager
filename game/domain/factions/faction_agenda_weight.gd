## One static faction agenda tag weight.
class_name FactionAgendaWeight
extends RefCounted

var tag: StringName
var weight: int


static func create(p_tag: StringName, p_weight: int) -> FactionAgendaWeight:
	return FactionAgendaWeight.new(p_tag, p_weight)


func _init(p_tag: StringName, p_weight: int) -> void:
	tag = p_tag
	weight = p_weight


func duplicate_value() -> FactionAgendaWeight:
	return FactionAgendaWeight.new(tag, weight)
