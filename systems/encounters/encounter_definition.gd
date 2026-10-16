extends Resource
class_name EncounterDefinition

# Stable content ID + roster, separate from the live combat state.
@export var encounter_id: StringName = &""
@export var enemy_ids: PackedStringArray = PackedStringArray()
@export var combat_timing: CombatTiming
@export var attack_pattern: AttackPatternDefinition


func is_configured() -> bool:
	if encounter_id == &"" or enemy_ids.is_empty():
		return false

	for enemy_id in enemy_ids:
		if enemy_id.is_empty():
			return false

	if combat_timing == null or not combat_timing.is_configured():
		return false
	# Old duration-only content may still omit a pattern. Sequence mode cannot.
	if attack_pattern == null:
		return combat_timing.attack_end_condition == CombatTiming.AttackEndCondition.DURATION
	return attack_pattern.is_configured()
