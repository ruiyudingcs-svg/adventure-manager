## Inspector authoring Resource for a bounded ideology vector.
class_name IdeologyVectorResource
extends Resource

const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")

@export_range(-10, 10) var protect_life: int = 0
@export_range(-10, 10) var respect_authority: int = 0
@export_range(-10, 10) var seek_knowledge: int = 0
@export_range(-10, 10) var pursue_profit: int = 0
@export_range(-10, 10) var taboo_tolerance: int = 0
@export var task_accumulation: bool = false


## Compiles a base (-5..5) or task-accumulation (-10..10) vector as declared.
func compile() -> IdeologyVector:
	if task_accumulation:
		return IdeologyVector.create_task_accumulation(
			protect_life,
			respect_authority,
			seek_knowledge,
			pursue_profit,
			taboo_tolerance
		)
	return IdeologyVector.create_base(
		protect_life,
		respect_authority,
		seek_knowledge,
		pursue_profit,
		taboo_tolerance
	)
