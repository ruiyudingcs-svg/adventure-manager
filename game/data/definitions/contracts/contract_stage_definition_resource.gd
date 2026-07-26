## Inspector authoring Resource for one of four ordered contract stages.
class_name ContractStageDefinitionResource
extends Resource

const ContractStageDefinition = preload(
	"res://game/domain/contracts/contract_stage_definition.gd"
)
const ContractCheckDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_check_definition_resource.gd"
)

@export var id: StringName
@export var phase: StringName
@export var check: ContractCheckDefinitionResource


## Compiles one of the four fixed stage slots.
func compile() -> ContractStageDefinition:
	if check == null:
		return null
	return ContractStageDefinition.create(id, phase, check.compile())
