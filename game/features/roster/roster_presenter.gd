## Builds Roster data and derives recent records only from contract history.
class_name RosterPresenter
extends RefCounted

const RosterViewData = preload(
	"res://game/features/roster/roster_view_data.gd"
)
const AdventurerSnapshot = preload(
	"res://game/domain/adventurers/adventurer_snapshot.gd"
)


static func present(
	state,
	setup,
	adventurer_definitions: Array,
	contract_definitions: Array
) -> RosterViewData:
	if state == null:
		return null
	var view_data := RosterViewData.new()
	var adventurers := _index_by_id(adventurer_definitions)
	var contracts := _index_by_id(contract_definitions)
	var member_ids: Array[StringName] = []
	if setup != null:
		member_ids.append_array(setup.adventurer_ids)
	else:
		member_ids.assign(state.adventurers.keys())
		member_ids.sort()
	for member_id: StringName in member_ids:
		if not state.adventurers.has(member_id) \
				or not adventurers.has(member_id):
			continue
		var definition = adventurers[member_id]
		var snapshot := AdventurerSnapshot.create(
			definition,
			state.adventurers[member_id]
		)
		if snapshot == null:
			continue
		var item := RosterViewData.MemberItem.new()
		item.id = member_id
		item.name_key = StringName("adventurer.%s.name" % member_id)
		item.fallback_name = definition.display_name
		item.class_key = StringName("class.%s" % snapshot.class_id)
		var capabilities = snapshot.capabilities
		item.capabilities = {
			&"frontline": capabilities.frontline,
			&"offense": capabilities.offense,
			&"scouting": capabilities.scouting,
			&"support": capabilities.support,
			&"arcana": capabilities.arcana,
			&"discipline": capabilities.discipline,
		}
		item.fatigue = snapshot.fatigue
		item.morale = snapshot.morale
		item.injury_severity = snapshot.injury_severity
		item.recovery_weeks = snapshot.recovery_weeks_remaining
		item.is_available = snapshot.is_available
		for trait_id: StringName in snapshot.traits:
			item.trait_keys.append(StringName("trait.%s.name" % trait_id))
		var values = snapshot.values
		item.values = {
			&"protect_life": values.protect_life,
			&"respect_authority": values.respect_authority,
			&"seek_knowledge": values.seek_knowledge,
			&"pursue_profit": values.pursue_profit,
			&"taboo_tolerance": values.taboo_tolerance,
		}
		item.wage = snapshot.wage
		item.recent_assignment_count = snapshot.recent_assignment_count
		item.recent_neglect_count = snapshot.recent_neglect_count
		var relationship_values := snapshot.relationship_values
		var target_ids: Array[StringName] = []
		target_ids.assign(relationship_values.keys())
		target_ids.sort()
		for target_id: StringName in target_ids:
			var relationship := RosterViewData.RelationshipItem.new()
			relationship.target_id = target_id
			relationship.target_name_key = StringName(
				"adventurer.%s.name" % target_id
			)
			relationship.value = relationship_values[target_id]
			item.relationships.append(relationship)
		for entry in state.contract_history:
			if not entry.member_ids.has(member_id):
				continue
			var record := RosterViewData.RecordItem.new()
			record.week_index = entry.week_index
			record.contract_title_key = (
				contracts[entry.contract_definition_id].title_key
				if contracts.has(entry.contract_definition_id) else &""
			)
			record.terminal_status = entry.terminal_status
			record.result_tier = entry.result_tier
			item.recent_records.append(record)
		item.recent_records.sort_custom(func(left, right) -> bool:
			if left.week_index != right.week_index:
				return left.week_index > right.week_index
			return String(left.contract_title_key) \
				< String(right.contract_title_key)
		)
		view_data.members.append(item)
	return view_data


static func _index_by_id(definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions:
		if definition != null:
			result[definition.id] = definition
	return result
