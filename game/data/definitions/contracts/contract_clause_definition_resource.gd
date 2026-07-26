## Inspector authoring Resource for one public contract clause.
class_name ContractClauseDefinitionResource
extends Resource

const ContractClauseDefinition = preload(
	"res://game/domain/contracts/contract_clause_definition.gd"
)
const TraceConditionResource = preload(
	"res://game/data/definitions/contracts/trace_condition_resource.gd"
)
const ContractEffectResource = preload(
	"res://game/data/definitions/contracts/contract_effect_resource.gd"
)
const IdeologyVectorResource = preload(
	"res://game/data/definitions/adventurers/ideology_vector_resource.gd"
)
const TraceCondition = preload("res://game/domain/contracts/trace_condition.gd")
const ContractEffect = preload("res://game/domain/contracts/contract_effect.gd")

@export var id: StringName
@export var display_name_key: StringName
@export var description_key: StringName
@export var category: StringName
@export var importance: StringName
@export var all_conditions: Array[TraceConditionResource] = []
@export var success_effects: Array[ContractEffectResource] = []
@export var failure_effects: Array[ContractEffectResource] = []
@export var breach_result_cap: StringName
@export var success_ideology_impact: IdeologyVectorResource
@export var failure_ideology_impact: IdeologyVectorResource
@export var success_tags: Array[StringName] = []
@export var failure_tags: Array[StringName] = []
@export var priority: int = 0


## Deep-compiles a public clause and its conditions and effects.
func compile() -> ContractClauseDefinition:
	if success_ideology_impact == null or failure_ideology_impact == null:
		return null
	var conditions: Array[TraceCondition] = []
	var successes: Array[ContractEffect] = []
	var failures: Array[ContractEffect] = []
	for condition: TraceConditionResource in all_conditions:
		if condition == null:
			return null
		conditions.append(condition.compile())
	for effect: ContractEffectResource in success_effects:
		if effect == null:
			return null
		successes.append(effect.compile())
	for effect: ContractEffectResource in failure_effects:
		if effect == null:
			return null
		failures.append(effect.compile())
	return ContractClauseDefinition.create(
		id,
		category,
		importance,
		conditions,
		successes,
		failures,
		breach_result_cap,
		success_ideology_impact.compile(),
		failure_ideology_impact.compile(),
		success_tags,
		failure_tags,
		priority,
		display_name_key,
		description_key
	)
