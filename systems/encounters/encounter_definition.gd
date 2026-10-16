extends Resource
class_name EncounterDefinition

# Stable content ID + roster, separate from the live combat state.
@export var encounter_id: StringName = &""
@export var enemy_ids: PackedStringArray = PackedStringArray()
@export var combat_timing: CombatTiming


func is_configured() -> bool:
	if encounter_id == &"" or enemy_ids.is_empty():
		return false

	for enemy_id in enemy_ids:
		if enemy_id.is_empty():
			return false

	return combat_timing != null and combat_timing.is_configured()
