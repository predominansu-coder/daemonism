extends RefCounted
class_name EncounterRequest

# Runtime context for a single encounter. It is NOT a save file.
# EncounterDefinition is shared content; this object identifies its source.
var definition: EncounterDefinition
var region_id: StringName = &""
var spawn_id: StringName = &""


func _init(
	p_definition: EncounterDefinition = null,
	p_spawn_id: StringName = &""
) -> void:
	definition = p_definition
	spawn_id = p_spawn_id
