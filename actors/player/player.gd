extends CharacterBody2D

# 임시 이동 속도이며 최종 밸런스 값이 아닙니다.
@export var move_speed: float = 180.0

var controls_enabled: bool = true


func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
	else:
		var direction := Input.get_vector(
			"move_left", "move_right", "move_up", "move_down"
		)
		velocity = direction * move_speed

	move_and_slide()


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
