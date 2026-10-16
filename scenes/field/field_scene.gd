extends Node2D

# The field emits requests; it does not instantiate or run combat scenes.
signal encounter_requested(request: EncounterRequest)

@export var region_id: StringName = &"dev.region_01"

@onready var player: CharacterBody2D = $World/Player
@onready var enemies: Node2D = $World/Enemies


func _ready() -> void:
	for child in enemies.get_children():
		if child is PatrolEnemy:
			child.encounter_requested.connect(_on_enemy_encounter_requested)


func _on_enemy_encounter_requested(request: EncounterRequest) -> void:
	if request == null or request.definition == null:
		push_error("필드가 유효하지 않은 조우 요청을 받았습니다.")
		return

	request.region_id = region_id
	encounter_requested.emit(request)
