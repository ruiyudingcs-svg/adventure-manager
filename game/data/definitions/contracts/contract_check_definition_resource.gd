## Inspector authoring Resource for one fixed contract check.
class_name ContractCheckDefinitionResource
extends Resource

const ContractCheckDefinition = preload(
	"res://game/domain/contracts/contract_check_definition.gd"
)
const CapabilityWeightsResource = preload(
	"res://game/data/definitions/contracts/capability_weights_resource.gd"
)
const MissionModifierResource = preload(
	"res://game/data/definitions/contracts/mission_modifier_resource.gd"
)
const CheckOutcomeTableResource = preload(
	"res://game/data/definitions/contracts/check_outcome_table_resource.gd"
)
const MissionModifier = preload("res://game/domain/contracts/mission_modifier.gd")

@export var id: StringName
@export var check_type: StringName
@export var capability_weights: CapabilityWeightsResource
@export var difficulty: int = 0
@export var result_weight: float = 0.25
@export var failure_result_cap: StringName
@export var method_tags: Array[StringName] = []
@export var context_modifiers: Array[MissionModifierResource] = []
@export var approach_profile: StringName = &"neutral"
@export var outcome_table: CheckOutcomeTableResource


## Deep-compiles one fixed contract check.
func compile() -> ContractCheckDefinition:
	if capability_weights == null or outcome_table == null:
		return null
	var modifiers: Array[MissionModifier] = []
	for modifier: MissionModifierResource in context_modifiers:
		if modifier == null:
			return null
		modifiers.append(modifier.compile())
	return ContractCheckDefinition.create(
		id,
		check_type,
		capability_weights.compile(),
		difficulty,
		result_weight,
		failure_result_cap,
		method_tags,
		modifiers,
		approach_profile,
		outcome_table.compile()
	)
