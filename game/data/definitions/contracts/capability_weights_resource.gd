## Inspector authoring Resource for normalized check capability weights.
class_name CapabilityWeightsResource
extends Resource

const CapabilityWeights = preload(
	"res://game/domain/contracts/capability_weights.gd"
)

@export_range(0.0, 1.0, 0.01) var frontline: float = 0.0
@export_range(0.0, 1.0, 0.01) var offense: float = 0.0
@export_range(0.0, 1.0, 0.01) var scouting: float = 0.0
@export_range(0.0, 1.0, 0.01) var support: float = 0.0
@export_range(0.0, 1.0, 0.01) var arcana: float = 0.0
@export_range(0.0, 1.0, 0.01) var discipline: float = 0.0


## Compiles the six normalized weights into a runtime value.
func compile() -> CapabilityWeights:
	return CapabilityWeights.create(
		frontline,
		offense,
		scouting,
		support,
		arcana,
		discipline
	)
