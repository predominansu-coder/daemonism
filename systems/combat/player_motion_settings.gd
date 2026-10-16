extends Resource
class_name PlayerMotionSettings

# Development examples only; these are not final balance values.
@export_range(1.0, 2000.0, 1.0, "or_greater") var move_speed: float = 180.0
@export_range(1.0, 4000.0, 1.0, "or_greater") var dash_speed: float = 540.0
@export_range(0.01, 5.0, 0.01, "or_greater") var dash_duration_seconds: float = 0.14
@export_range(0.01, 30.0, 0.01, "or_greater") var dash_cooldown_seconds: float = 0.65


func is_configured() -> bool:
	return is_finite(move_speed) and move_speed > 0.0 \
		and is_finite(dash_speed) and dash_speed > 0.0 \
		and is_finite(dash_duration_seconds) and dash_duration_seconds > 0.0 \
		and is_finite(dash_cooldown_seconds) and dash_cooldown_seconds > 0.0
