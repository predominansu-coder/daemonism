extends Node
class_name CombatDirector

# Owns only the shared encounter phase loop.
# Damage, targets, Q/E menus, deaths and outcomes belong to other systems.
enum Phase {
	IDLE,
	ENEMY_ATTACK,
	PLAYER_ACTION,
	FINISHED
}

signal phase_changed(phase_id: int)
signal action_time_changed(remaining_seconds: float, total_seconds: float)
signal action_window_expired

@onready var attack_gate: AttackPhaseGate = $AttackPhaseGate

var phase: Phase = Phase.IDLE
var _timing: CombatTiming
var _remaining_action_seconds: float = 0.0


func _ready() -> void:
	set_process(false)
	attack_gate.attack_phase_finished.connect(_on_attack_phase_finished)


func begin(timing: CombatTiming) -> bool:
	if timing == null or not timing.is_configured():
		push_error("전투 시간 설정이 없습니다.")
		return false

	stop()
	_timing = timing
	_begin_enemy_attack()
	return true


func stop() -> void:
	if is_instance_valid(attack_gate):
		attack_gate.stop()
	set_process(false)
	_remaining_action_seconds = 0.0
	_timing = null
	phase = Phase.IDLE


func can_accept_player_action() -> bool:
	return phase == Phase.PLAYER_ACTION and _remaining_action_seconds > 0.0


# Call only AFTER an action system successfully applies exactly one Q or E.
# Merely opening an E menu must not call this method.
func notify_player_action_applied() -> bool:
	if not can_accept_player_action():
		return false
	_begin_enemy_attack()
	return true


func finish_encounter() -> void:
	if phase == Phase.FINISHED:
		return
	if is_instance_valid(attack_gate):
		attack_gate.stop()
	set_process(false)
	_remaining_action_seconds = 0.0
	phase = Phase.FINISHED
	phase_changed.emit(phase)


func _begin_enemy_attack() -> void:
	set_process(false)
	_remaining_action_seconds = 0.0
	phase = Phase.ENEMY_ATTACK
	phase_changed.emit(phase)
	attack_gate.begin(_timing)


func _on_attack_phase_finished() -> void:
	if phase != Phase.ENEMY_ATTACK or _timing == null:
		return

	_remaining_action_seconds = _timing.action_duration_seconds
	phase = Phase.PLAYER_ACTION
	phase_changed.emit(phase)
	action_time_changed.emit(_remaining_action_seconds, _timing.action_duration_seconds)
	set_process(true)


func _process(delta: float) -> void:
	if phase != Phase.PLAYER_ACTION or _timing == null:
		return

	_remaining_action_seconds = maxf(0.0, _remaining_action_seconds - delta)
	action_time_changed.emit(_remaining_action_seconds, _timing.action_duration_seconds)

	if _remaining_action_seconds <= 0.0:
		action_window_expired.emit()
		_begin_enemy_attack()
