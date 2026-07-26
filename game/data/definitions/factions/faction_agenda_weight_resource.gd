## Inspector authoring Resource for one faction agenda weight.
class_name FactionAgendaWeightResource
extends Resource

const FactionAgendaWeight = preload(
	"res://game/domain/factions/faction_agenda_weight.gd"
)

@export var tag: StringName
@export_range(-10, 10) var weight: int = 0


## Compiles one agenda weight record.
func compile() -> FactionAgendaWeight:
	return FactionAgendaWeight.create(tag, weight)
