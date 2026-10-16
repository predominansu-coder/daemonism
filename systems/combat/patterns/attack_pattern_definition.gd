extends Resource
class_name AttackPatternDefinition

# Development defaults. A custom scene can replace the built-in volley without
# teaching the phase director about enemy names or individual boss scripts.
@export var executor_scene: PackedScene
@export_range(1, 32, 1, "or_greater") var volley_count: int = 3
@export_range(1, 32, 1, "or_greater") var projectiles_per_volley: int = 3
@export_range(0.0, 5.0, 0.05, "or_greater") var telegraph_seconds: float = 0.45
@export_range(0.0, 5.0, 0.05, "or_greater") var volley_interval_seconds: float = 0.35
@export_range(1.0, 600.0, 1.0, "or_greater") var projectile_speed: float = 180.0
@export_range(0.1, 15.0, 0.1, "or_greater") var projectile_lifetime_seconds: float = 4.0
@export_range(0.0, 360.0, 1.0) var spread_degrees: float = 38.0
@export var normalized_origin: Vector2 = Vector2(0.5, 0.08)
@export_range(1.0, 24.0, 0.5, "or_greater") var projectile_radius: float = 6.0


func is_configured() -> bool:
	# Custom scenes can use the same projectile helpers, so their shared numeric
	# defaults must be valid even when the built-in volley is not selected.
	if not is_finite(projectile_speed) or projectile_speed <= 0.0 \
			or not is_finite(projectile_lifetime_seconds) or projectile_lifetime_seconds <= 0.0 \
			or not is_finite(projectile_radius) or projectile_radius <= 0.0:
		return false
	if executor_scene != null:
		return executor_scene.can_instantiate()
	return volley_count > 0 \
		and projectiles_per_volley > 0 \
		and is_finite(telegraph_seconds) and telegraph_seconds >= 0.0 \
		and is_finite(volley_interval_seconds) and volley_interval_seconds >= 0.0 \
		and is_finite(spread_degrees) and spread_degrees >= 0.0 \
		and normalized_origin.is_finite() \
		and normalized_origin.x >= 0.0 and normalized_origin.x <= 1.0 \
		and normalized_origin.y >= 0.0 and normalized_origin.y <= 1.0
