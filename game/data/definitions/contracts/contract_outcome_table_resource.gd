## Inspector authoring Resource for all five final contract outcomes.
class_name ContractOutcomeTableResource
extends Resource

const ContractOutcomeTable = preload(
	"res://game/domain/contracts/contract_outcome_table.gd"
)
const ContractOutcomeDefinitionResource = preload(
	"res://game/data/definitions/contracts/contract_outcome_definition_resource.gd"
)

@export var exceptional: ContractOutcomeDefinitionResource
@export var success: ContractOutcomeDefinitionResource
@export var partial: ContractOutcomeDefinitionResource
@export var failure: ContractOutcomeDefinitionResource
@export var severe: ContractOutcomeDefinitionResource


## Compiles all five required contract outcomes.
func compile() -> ContractOutcomeTable:
	if exceptional == null or success == null or partial == null \
		or failure == null or severe == null:
		return null
	return ContractOutcomeTable.create(
		exceptional.compile(),
		success.compile(),
		partial.compile(),
		failure.compile(),
		severe.compile()
	)
