class_name AdventurerFixtures
extends RefCounted

const CapabilityBlock = preload("res://game/domain/adventurers/capability_block.gd")
const IdeologyVector = preload("res://game/domain/adventurers/ideology_vector.gd")
const RelationshipDefinition = preload("res://game/domain/adventurers/relationship_definition.gd")
const AdventurerDefinition = preload("res://game/domain/adventurers/adventurer_definition.gd")
const AdventurerState = preload("res://game/domain/adventurers/adventurer_state.gd")
const AdventurerSnapshot = preload("res://game/domain/adventurers/adventurer_snapshot.gd")


static func create_member_bundle(
	member_id: StringName,
	capabilities: CapabilityBlock,
	fatigue: int = 10,
	morale: int = 60,
	injury_severity: int = 0
) -> Dictionary:
	var relationship := RelationshipDefinition.create(&"fixture_contact", 4)
	var relationships: Array[RelationshipDefinition] = [relationship]
	var traits: Array[StringName] = [&"cautious"]
	var definition := AdventurerDefinition.create(
		member_id,
		String(member_id),
		&"fixture_class",
		capabilities,
		IdeologyVector.create_base(2, -1, 1, 0, -2),
		traits,
		relationships,
		12,
		&"fixture_bio"
	)
	var relationship_deltas: Dictionary[StringName, int] = {
		&"fixture_contact": 3,
	}
	var state := AdventurerState.create(
		member_id,
		fatigue,
		morale,
		injury_severity,
		0,
		0,
		true,
		relationship_deltas,
		1,
		0
	)
	var snapshot := AdventurerSnapshot.create(definition, state)
	return {
		"definition": definition,
		"state": state,
		"snapshot": snapshot,
	}


static func create_standard_team_bundles() -> Array[Dictionary]:
	var bundles: Array[Dictionary] = []
	bundles.append(create_member_bundle(
		&"member_alpha",
		CapabilityBlock.create(100, 20, 80, 40, 60, 90)
	))
	bundles.append(create_member_bundle(
		&"member_bravo",
		CapabilityBlock.create(80, 40, 60, 100, 20, 70)
	))
	bundles.append(create_member_bundle(
		&"member_charlie",
		CapabilityBlock.create(40, 100, 20, 60, 80, 50)
	))
	bundles.append(create_member_bundle(
		&"member_delta",
		CapabilityBlock.create(20, 60, 100, 80, 40, 30)
	))
	return bundles


static func snapshots_from_bundles(
	bundles: Array[Dictionary]
) -> Array[AdventurerSnapshot]:
	var snapshots: Array[AdventurerSnapshot] = []
	for bundle: Dictionary in bundles:
		snapshots.append(bundle["snapshot"] as AdventurerSnapshot)
	return snapshots
