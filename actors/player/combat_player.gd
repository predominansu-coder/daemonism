extends CharacterBody2D
class_name CombatPlayer

signal dash_state_changed(active: bool)

const BODY_RADIUS: float = 10.0

@export var motion_settings: PlayerMotionSettings = preload("res://data/combat/dev_player_motion.tres")

var controls_enabled: bool = true
var dash_cooldown_remaining: float:
	get:
		return _dash_cooldown_remaining

var _last_facing: Vector2 = Vector2.UP
var _dash_direction: Vector2 = Vector2.UP
var _dash_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _arena_bounds: Rect2
var _has_arena_bounds: bool = false


func _physics_process(delta: float) -> void:
	_dash_cooldown_remaining = maxf(0.0, _dash_cooldown_remaining - delta)
	if not controls_enabled or motion_settings == null or not motion_settings.is_configured():
		_finish_dash()
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not direction.is_zero_approx():
		_last_facing = direction.normalized()
	if InputMap.has_action("combat_dash") and Input.is_action_just_pressed("combat_dash"):
		request_dash(direction)

	if is_dashing():
		# Use only the remaining dash time on its final physics frame.
		var frame_fraction := minf(_dash_remaining / delta, 1.0) if delta > 0.0 else 0.0
		velocity = _dash_direction * motion_settings.dash_speed * frame_fraction
	else:
		velocity = direction * motion_settings.move_speed

	move_and_slide()
	var touched_boundary := _clamp_to_arena()
	if is_dashing():
		_dash_remaining = maxf(0.0, _dash_remaining - delta)
		if _dash_remaining <= 0.0 or touched_boundary or get_slide_collision_count() > 0:
			_finish_dash(true)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		_finish_dash()
		velocity = Vector2.ZERO


# Bounds and player position are world coordinates. The arena owns its camera.
func configure_bounds(bounds: Rect2) -> void:
	if not bounds.position.is_finite() or not bounds.size.is_finite() \
	or bounds.size.x < BODY_RADIUS * 2.0 or bounds.size.y < BODY_RADIUS * 2.0:
		push_error("CombatPlayer requires finite arena bounds at least one body diameter wide and tall.")
		return
	_arena_bounds = bounds
	_has_arena_bounds = true
	_clamp_to_arena()


# Cooldown starts when accepted. Dash keeps normal collision and grants no invulnerability.
func request_dash(direction: Vector2 = Vector2.ZERO) -> bool:
	if not controls_enabled or is_dashing() or _dash_cooldown_remaining > 0.0 \
	or motion_settings == null or not motion_settings.is_configured() or not direction.is_finite():
		return false
	_dash_direction = _last_facing if direction.is_zero_approx() else direction.normalized()
	_last_facing = _dash_direction
	_dash_remaining = motion_settings.dash_duration_seconds
	_dash_cooldown_remaining = motion_settings.dash_cooldown_seconds
	dash_state_changed.emit(true)
	return true


func is_dashing() -> bool:
	return _dash_remaining > 0.0


func _finish_dash(was_dashing: bool = false) -> void:
	var changed := was_dashing or is_dashing()
	_dash_remaining = 0.0
	if changed:
		velocity = Vector2.ZERO
		dash_state_changed.emit(false)


func _clamp_to_arena() -> bool:
	if not _has_arena_bounds:
		return false
	var minimum := _arena_bounds.position + Vector2.ONE * BODY_RADIUS
	var maximum := _arena_bounds.end - Vector2.ONE * BODY_RADIUS
	var bounded_position := Vector2(
		clampf(global_position.x, minimum.x, maximum.x),
		clampf(global_position.y, minimum.y, maximum.y)
	)
	var touched_boundary := bounded_position != global_position
	global_position = bounded_position
	return touched_boundary
