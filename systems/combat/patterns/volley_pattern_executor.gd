extends AttackPatternExecutor
class_name VolleyPatternExecutor

enum Step { TELEGRAPH, INTERVAL }

var _step: Step = Step.TELEGRAPH
var _remaining_seconds: float = 0.0
var _volleys_emitted: int = 0
var _origin: Vector2
var _directions: Array[Vector2] = []


func _begin_pattern() -> void:
	_volleys_emitted = 0
	_origin = arena_bounds.position + arena_bounds.size * definition.normalized_origin
	_prepare_volley()


func _advance_pattern(delta: float) -> void:
	_remaining_seconds = maxf(0.0, _remaining_seconds - delta)
	if _remaining_seconds > 0.0:
		return
	if _step == Step.INTERVAL:
		_prepare_volley()
		return

	clear_telegraphs()
	for direction in _directions:
		spawn_projectile(_origin, direction)
	_volleys_emitted += 1
	if _volleys_emitted >= definition.volley_count:
		finish_emission()
	else:
		_step = Step.INTERVAL
		_remaining_seconds = definition.volley_interval_seconds


func _prepare_volley() -> void:
	# The warning locks the direction before firing, so movement can evade it.
	var aim_direction := Vector2.DOWN
	if is_instance_valid(target):
		var toward_target := to_local(target.global_position) - _origin
		if not toward_target.is_zero_approx():
			aim_direction = toward_target.normalized()
	_directions.clear()
	var spread := deg_to_rad(definition.spread_degrees)
	for index in range(definition.projectiles_per_volley):
		var offset := 0.0
		if definition.projectiles_per_volley > 1:
			offset = spread * (float(index) / float(definition.projectiles_per_volley - 1) - 0.5)
		_directions.append(aim_direction.rotated(offset))
	show_telegraph(_origin, _directions)
	_step = Step.TELEGRAPH
	_remaining_seconds = definition.telegraph_seconds
