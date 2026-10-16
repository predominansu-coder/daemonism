extends Resource
class_name CombatTiming

# Only phase timing and phase-end policy live here.
# These values are development examples, not final balance.
enum AttackEndCondition {
	DURATION,
	SEQUENCE_FINISHED
}

@export var attack_end_condition: AttackEndCondition = AttackEndCondition.DURATION
@export_range(0.1, 120.0, 0.1, "or_greater") var attack_duration_seconds: float = 3.5
@export_range(0.1, 120.0, 0.1, "or_greater") var action_duration_seconds: float = 6.0


func is_configured() -> bool:
	return is_finite(attack_duration_seconds) \
		and attack_duration_seconds > 0.0 \
		and is_finite(action_duration_seconds) \
		and action_duration_seconds > 0.0
