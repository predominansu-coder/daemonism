extends CharacterBody2D
class_name PatrolEnemy

signal encounter_requested(request: EncounterRequest)

# These are editable prototype movement values, not final game balance.
@export var encounter_definition: EncounterDefinition
@export var spawn_id: StringName = &""
@export var patrol_offset: Vector2 = Vector2(0.0, 120.0)
@export var patrol_speed: float = 48.0
@export var endpoint_pause_seconds: float = 0.5

var _start_position: Vector2
var _going_out: bool = true
var _pause_remaining: float = 0.0
var _contact_locked: bool = false
var _rearm_delay: float = 0.0


func _ready() -> void:
	_start_position = global_position
	$EncounterArea.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _contact_locked:
		# Field is suspended during combat. When restored, remain disarmed
		# until the player has moved outside the detection area.
		_rearm_delay = maxf(0.0, _rearm_delay - delta)
		if _rearm_delay <= 0.0 and not _player_is_overlapping():
			_contact_locked = false
		velocity = Vector2.ZERO
		return

	if _pause_remaining > 0.0:
		_pause_remaining = maxf(0.0, _pause_remaining - delta)
		velocity = Vector2.ZERO
		return

	var destination := _start_position
	if _going_out:
		destination += patrol_offset

	var offset_to_target := destination - global_position
	if offset_to_target.length() < 3.0:
		_going_out = not _going_out
		_pause_remaining = endpoint_pause_seconds
		velocity = Vector2.ZERO
		return

	velocity = offset_to_target.normalized() * patrol_speed
	move_and_slide()


func _on_body_entered(body: Node2D) -> void:
	if _contact_locked or not body.is_in_group("player"):
		return

	if encounter_definition == null or not encounter_definition.is_configured():
		push_error("순찰 적의 조우 정의가 비어 있거나 잘못되었습니다.")
		return

	if spawn_id == &"":
		push_error("순찰 적의 고유 배치 ID(spawn_id)가 비어 있습니다.")
		return

	_contact_locked = true
	_rearm_delay = 0.5
	encounter_requested.emit(EncounterRequest.new(encounter_definition, spawn_id))


func _player_is_overlapping() -> bool:
	for body in $EncounterArea.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false
