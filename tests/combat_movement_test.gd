extends SceneTree

# Run with: godot --headless --path . --script res://tests/combat_movement_test.gd
const PLAYER_SCENE := preload("res://actors/player/combat_player.tscn")
const STEP: float = 1.0 / 60.0

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


func _make_player() -> CombatPlayer:
	var player := PLAYER_SCENE.instantiate() as CombatPlayer
	root.add_child(player)
	# The test advances the real collision motor once per physics frame.
	player.set_physics_process(false)
	player.global_position = Vector2(500, 500)
	player.configure_bounds(Rect2(0, 0, 1000, 1000))
	return player


func _advance(player: CombatPlayer, frames: int) -> void:
	for frame in frames:
		await physics_frame
		player._physics_process(STEP)


func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "combat_dash"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _run() -> void:
	_release_movement()
	await _test_directional_movement()
	await _test_dash_and_cooldown()
	await _test_disable_controls()
	await _test_arena_boundary()
	await _test_wall_collision()
	_test_settings_validation()
	_release_movement()
	print("%s: Combat movement — %d checks, %d failures" % [
		"PASS" if _failures == 0 else "FAIL", _checks, _failures
	])
	quit(0 if _failures == 0 else 1)


func _test_directional_movement() -> void:
	var player := _make_player()
	var origin := player.global_position
	Input.action_press("move_right")
	await _advance(player, 10)
	var horizontal_distance := player.global_position.distance_to(origin)
	_check(horizontal_distance > 0.0, "direction action moves combat player")
	Input.action_release("move_right")
	player.global_position = origin
	Input.action_press("move_right")
	Input.action_press("move_up")
	await _advance(player, 10)
	var diagonal_displacement := player.global_position - origin
	_check(diagonal_displacement.x > 0.0 and diagonal_displacement.y < 0.0,
		"up/right actions move on both axes")
	_check(absf(diagonal_displacement.length() - horizontal_distance) < 0.01,
		"diagonal movement has the same speed as cardinal movement")
	_release_movement()
	var before_dash := player.global_position
	_check(player.request_dash(), "idle dash uses last facing")
	await _advance(player, 1)
	var dash_displacement := player.global_position - before_dash
	_check(dash_displacement.x > 0.0 and dash_displacement.y < 0.0,
		"idle dash retains the last input direction")
	player.free()


func _test_dash_and_cooldown() -> void:
	var player := _make_player()
	var initial_layer := player.collision_layer
	var initial_mask := player.collision_mask
	var collider := player.get_node("CollisionShape2D") as CollisionShape2D
	_check(player.request_dash(Vector2.RIGHT), "ready dash is accepted")
	_check(player.is_dashing(), "accepted dash becomes active")
	_check(not player.request_dash(Vector2.LEFT), "active dash cannot restart")
	_check(player.collision_layer == initial_layer and player.collision_mask == initial_mask \
		and not collider.disabled, "starting dash preserves collision and grants no immunity")
	var before_dash := player.global_position
	await _advance(player, 9)
	_check(not player.is_dashing(), "dash ends after configured duration")
	_check(is_equal_approx(player.global_position.x - before_dash.x,
		player.motion_settings.dash_speed * player.motion_settings.dash_duration_seconds),
		"dash distance uses only remaining time on its last frame")
	_check(player.dash_cooldown_remaining > 0.0, "cooldown remains after dash ends")
	_check(not player.request_dash(Vector2.LEFT), "cooldown blocks a second dash")
	await _advance(player, 40)
	_check(is_zero_approx(player.dash_cooldown_remaining), "cooldown reaches zero")
	_check(player.request_dash(Vector2.LEFT), "dash recovers after cooldown")
	await _advance(player, 1)
	_check(player.collision_layer == initial_layer and player.collision_mask == initial_mask \
		and not collider.disabled, "collision stays enabled during dash movement")
	player.free()


func _test_disable_controls() -> void:
	var player := _make_player()
	_check(player.request_dash(Vector2.RIGHT), "dash begins before controls are disabled")
	player.set_controls_enabled(false)
	_check(not player.is_dashing() and player.velocity.is_zero_approx(),
		"disabling controls immediately cancels dash and velocity")
	_check(not player.request_dash(Vector2.RIGHT), "disabled controls reject dash")
	var origin := player.global_position
	Input.action_press("move_right")
	await _advance(player, 12)
	_check(player.global_position == origin, "disabled controls block movement input")
	_check(player.dash_cooldown_remaining > 0.0,
		"disabling controls preserves the accepted dash cooldown")
	player.set_controls_enabled(true)
	await _advance(player, 1)
	_check(player.global_position.x > origin.x, "reenabled controls resume movement")
	_release_movement()
	player.free()


func _test_arena_boundary() -> void:
	var player := _make_player()
	# Nonzero origin catches mixing local extent with absolute world bounds.
	player.configure_bounds(Rect2(100, 200, 300, 200))
	_check(player.global_position == Vector2(390, 390),
		"configuring bounds immediately clamps the entire body at a nonzero origin")
	player.global_position = Vector2(380, 300)
	_check(player.request_dash(Vector2.RIGHT), "dash toward arena edge starts")
	await _advance(player, 3)
	_check(player.global_position.x <= 390.0, "dash cannot cross arena bounds minus body radius")
	_check(not player.is_dashing(), "touching the arena clamp ends dash")
	Input.action_press("move_left")
	await _advance(player, 120)
	_check(player.global_position.x >= 110.0, "ordinary movement respects the opposite boundary")
	_release_movement()
	player.free()


func _test_wall_collision() -> void:
	var player := _make_player()
	player.global_position = Vector2(100, 150)
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 200)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector2(145, 150)
	root.add_child(wall)
	await physics_frame
	_check(player.request_dash(Vector2.RIGHT), "dash toward a collision wall starts")
	await _advance(player, 9)
	_check(player.global_position.x <= 125.1,
		"move_and_slide keeps the dashing body outside the actual static wall")
	_check(not player.is_dashing(), "wall collision ends dash")
	player.free()
	wall.free()


func _test_settings_validation() -> void:
	var settings := PlayerMotionSettings.new()
	_check(settings.is_configured(), "development motion defaults are valid")
	settings.move_speed = NAN
	_check(not settings.is_configured(), "NaN speed is rejected")
	settings.move_speed = 180.0
	settings.dash_speed = INF
	_check(not settings.is_configured(), "infinite speed is rejected")
	settings.dash_speed = 540.0
	settings.dash_duration_seconds = 0.0
	_check(not settings.is_configured(), "zero dash duration is rejected")
	settings.dash_duration_seconds = 0.14
	settings.dash_cooldown_seconds = -1.0
	_check(not settings.is_configured(), "negative cooldown is rejected")
	var player := _make_player()
	_check(not player.request_dash(Vector2(NAN, 0.0)), "nonfinite dash direction is rejected")
	player.motion_settings = settings
	_check(not player.request_dash(Vector2.RIGHT), "invalid motion resource blocks dash")
	player.free()
