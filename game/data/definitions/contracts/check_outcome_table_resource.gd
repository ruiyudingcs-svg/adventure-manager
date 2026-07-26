## Inspector authoring Resource for all five check outcome tiers.
class_name CheckOutcomeTableResource
extends Resource

const CheckOutcomeTable = preload(
	"res://game/domain/contracts/check_outcome_table.gd"
)
const CheckOutcomeDefinitionResource = preload(
	"res://game/data/definitions/contracts/check_outcome_definition_resource.gd"
)

@export var exceptional: CheckOutcomeDefinitionResource
@export var success: CheckOutcomeDefinitionResource
@export var partial: CheckOutcomeDefinitionResource
@export var failure: CheckOutcomeDefinitionResource
@export var severe: CheckOutcomeDefinitionResource


## Compiles all five required check outcomes as one independent table.
func compile() -> CheckOutcomeTable:
	if exceptional == null or success == null or partial == null \
		or failure == null or severe == null:
		return null
	return CheckOutcomeTable.create(
		exceptional.compile(),
		success.compile(),
		partial.compile(),
		failure.compile(),
		severe.compile()
	)
