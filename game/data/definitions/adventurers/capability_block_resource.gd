## Inspector authoring Resource for six base capabilities.
class_name CapabilityBlockResource
extends Resource

const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")

@export_range(0, 100) var frontline: int = 0
@export_range(0, 100) var offense: int = 0
@export_range(0, 100) var scouting: int = 0
@export_range(0, 100) var support: int = 0
@export_range(0, 100) var arcana: int = 0
@export_range(0, 100) var discipline: int = 0


## Compiles Inspector-authored values into an independent runtime value object.
func compile() -> CapabilityBlock:
	return CapabilityBlock.create(
		frontline,
		offense,
		scouting,
		support,
		arcana,
		discipline
	)
