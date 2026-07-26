## Immutable content definition for constructing one new campaign.
class_name CampaignSetupDefinition
extends RefCounted

const StableId = preload("res://game/core/ids/stable_id.gd")
const FactionSetupDefinition = preload(
	"res://game/domain/campaign/faction_setup_definition.gd"
)

var id: StringName
var situation_definition_id: StringName
var adventurer_ids: Array[StringName]
var faction_setups: Array[FactionSetupDefinition]
var initial_active_problem_ids: Array[StringName]
var initial_gold: int
var initial_reputation: int
var initial_base_cohesion: int
var weekly_maintenance: int


static func create(
	p_id: StringName,
	p_situation_definition_id: StringName,
	p_adventurer_ids: Array[StringName],
	p_faction_setups: Array[FactionSetupDefinition],
	p_initial_active_problem_ids: Array[StringName],
	p_initial_gold: int,
	p_initial_reputation: int,
	p_initial_base_cohesion: int,
	p_weekly_maintenance: int
) -> CampaignSetupDefinition:
	var definition := CampaignSetupDefinition.new(
		p_id,
		p_situation_definition_id,
		p_adventurer_ids,
		p_faction_setups,
		p_initial_active_problem_ids,
		p_initial_gold,
		p_initial_reputation,
		p_initial_base_cohesion,
		p_weekly_maintenance
	)
	return definition if definition.validate().is_empty() else null


func _init(
	p_id: StringName,
	p_situation_definition_id: StringName,
	p_adventurer_ids: Array[StringName],
	p_faction_setups: Array[FactionSetupDefinition],
	p_initial_active_problem_ids: Array[StringName],
	p_initial_gold: int,
	p_initial_reputation: int,
	p_initial_base_cohesion: int,
	p_weekly_maintenance: int
) -> void:
	id = p_id
	situation_definition_id = p_situation_definition_id
	adventurer_ids.append_array(p_adventurer_ids)
	for setup: FactionSetupDefinition in p_faction_setups:
		faction_setups.append(
			setup.duplicate_value() if setup != null else null
		)
	initial_active_problem_ids.append_array(p_initial_active_problem_ids)
	initial_gold = p_initial_gold
	initial_reputation = p_initial_reputation
	initial_base_cohesion = p_initial_base_cohesion
	weekly_maintenance = p_weekly_maintenance


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for pair: Array in [
		[id, "id"],
		[situation_definition_id, "situation_definition_id"],
	]:
		if not StableId.is_valid(pair[0]):
			errors.append(StableId.validation_error(
				pair[0],
				"CampaignSetupDefinition.%s" % pair[1]
			))
	_append_unique_ids(errors, adventurer_ids, "adventurer_ids")
	_append_unique_ids(
		errors,
		initial_active_problem_ids,
		"initial_active_problem_ids"
	)
	var faction_ids: Dictionary[StringName, bool] = {}
	for setup: FactionSetupDefinition in faction_setups:
		if setup == null:
			errors.append("Campaign setup faction entries cannot be null.")
			continue
		errors.append_array(FactionSetupDefinition.validate_values(
			setup.faction_id,
			setup.initial_relation,
			setup.initial_influence
		))
		if faction_ids.has(setup.faction_id):
			errors.append("Campaign setup faction IDs must be unique.")
		faction_ids[setup.faction_id] = true
	if initial_gold < 0 or weekly_maintenance < 0:
		errors.append("Campaign setup gold and maintenance must be non-negative.")
	if initial_reputation < 0 or initial_reputation > 100:
		errors.append("Campaign setup reputation must be between 0 and 100.")
	if initial_base_cohesion < 0 or initial_base_cohesion > 100:
		errors.append("Campaign setup cohesion must be between 0 and 100.")
	return errors


func duplicate_value() -> CampaignSetupDefinition:
	return CampaignSetupDefinition.new(
		id,
		situation_definition_id,
		adventurer_ids,
		faction_setups,
		initial_active_problem_ids,
		initial_gold,
		initial_reputation,
		initial_base_cohesion,
		weekly_maintenance
	)


static func _append_unique_ids(
	errors: PackedStringArray,
	values: Array[StringName],
	field_name: String
) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for value: StringName in values:
		if not StableId.is_valid(value):
			errors.append(StableId.validation_error(
				value,
				"CampaignSetupDefinition.%s item" % field_name
			))
		if seen.has(value):
			errors.append(
				"CampaignSetupDefinition.%s contains duplicate %s."
				% [field_name, value]
			)
		seen[value] = true
