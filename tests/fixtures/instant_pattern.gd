extends AttackPatternExecutor

# A test executor proves both an immediate boss-script completion and reuse of
# the shared projectile helper from a custom scene.
@export var finish_immediately: bool = true


func _begin_pattern() -> void:
	if finish_immediately:
		sequence_finished.emit()
	else:
		spawn_projectile(arena_bounds.get_center(), Vector2.RIGHT)
		finish_emission()
