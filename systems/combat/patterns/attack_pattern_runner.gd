extends Node2D
class_name AttackPatternRunner

signal sequence_finished(cycle: int)
signal projectile_contact(recipient: Node2D)

var _executor: AttackPatternExecutor
var _generation: int = 0


func start_sequence(pattern: AttackPatternDefinition, target: Node2D,
		bounds: Rect2, cycle: int) -> bool:
	stop()
	if pattern == null or not pattern.is_configured() \
			or not bounds.position.is_finite() or not bounds.size.is_finite() \
			or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return false
	if pattern.executor_scene != null:
		var instance := pattern.executor_scene.instantiate()
		if not instance is AttackPatternExecutor:
			instance.free()
			push_error("공격 패턴 장면은 AttackPatternExecutor를 상속해야 합니다.")
			return false
		_executor = instance as AttackPatternExecutor
	else:
		_executor = VolleyPatternExecutor.new()
	add_child(_executor)
	_executor.sequence_finished.connect(_on_sequence_finished.bind(_generation, cycle), CONNECT_ONE_SHOT)
	_executor.projectile_contact.connect(_on_projectile_contact.bind(_generation))
	_executor.start_sequence(pattern, target, bounds)
	return true


func stop() -> void:
	_generation += 1
	if is_instance_valid(_executor):
		_executor.stop()
		_executor.queue_free()
	_executor = null


func active_projectile_count() -> int:
	if not is_instance_valid(_executor):
		return 0
	return _executor.active_projectile_count()


func _on_sequence_finished(generation: int, cycle: int) -> void:
	if generation != _generation or not is_instance_valid(_executor):
		return
	var finished_executor := _executor
	_executor = null
	_generation += 1
	finished_executor.stop()
	finished_executor.queue_free()
	sequence_finished.emit(cycle)


func _on_projectile_contact(recipient: Node2D, generation: int) -> void:
	if generation == _generation and is_instance_valid(_executor):
		projectile_contact.emit(recipient)
