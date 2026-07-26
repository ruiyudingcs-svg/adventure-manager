## Inspector authoring Resource for one check outcome tier.
class_name CheckOutcomeDefinitionResource
extends Resource

const CheckOutcomeDefinition = preload(
	"res://game/domain/contracts/check_outcome_definition.gd"
)
const MissionContextDeltaResource = preload(
	"res://game/data/definitions/contracts/mission_context_delta_resource.gd"
)
const MemberEffectResource = preload(
	"res://game/data/definitions/contracts/member_effect_resource.gd"
)
const WorldEffectResource = preload(
	"res://game/data/definitions/contracts/world_effect_resource.gd"
)
const IdeologyVectorResource = preload(
	"res://game/data/definitions/adventurers/ideology_vector_resource.gd"
)
const MemberEffect = preload("res://game/domain/contracts/member_effect.gd")
const WorldEffect = preload("res://game/domain/contracts/world_effect.gd")

@export var context_deltas: Array[MissionContextDeltaResource] = []
@export var member_effects: Array[MemberEffectResource] = []
@export var campaign_effects: Array[WorldEffectResource] = []
@export var ideology_impact: IdeologyVectorResource
@export var outcome_tags: Array[StringName] = []


## Deep-compiles one check tier and all nested effects.
func compile() -> CheckOutcomeDefinition:
	if ideology_impact == null:
		return null
	var compiled_deltas: Array[Dictionary] = []
	var compiled_member_effects: Array[MemberEffect] = []
	var compiled_campaign_effects: Array[WorldEffect] = []
	for delta: MissionContextDeltaResource in context_deltas:
		if delta == null:
			return null
		compiled_deltas.append(delta.compile())
	for effect: MemberEffectResource in member_effects:
		if effect == null:
			return null
		compiled_member_effects.append(effect.compile())
	for effect: WorldEffectResource in campaign_effects:
		if effect == null:
			return null
		compiled_campaign_effects.append(effect.compile())
	return CheckOutcomeDefinition.create(
		compiled_deltas,
		compiled_member_effects,
		compiled_campaign_effects,
		ideology_impact.compile(),
		outcome_tags
	)
