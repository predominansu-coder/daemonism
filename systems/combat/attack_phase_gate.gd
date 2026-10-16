extends Node
class_name AttackPhaseGate

# Decides WHEN an attack phase ends. It does not create projectiles,
# telegraphs or damage. A future pattern player will call
# report_sequence_finished() when its final step ends.
signal attack_phase_finished

var _running: bool = false
var _end_condition: int = CombatTiming.AttackEndCondition.DURATION
var _remaining: float = 0.0


func begin(timing: CombatTiming) -> void:
	stop()
	if timing == null or not timing.is_configured():
		push_error("공격 단계 설정이 유효하지 않습니다.")
		return

	_end_condition = timing.attack_end_condition
	_remaining = timing.attack_duration_seconds
	_running = true
	set_process(true)


func stop() -> void:
	_running = false
	_remaining = 0.0
	set_process(false)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _running:
		return

	if _end_condition != CombatTiming.AttackEndCondition.DURATION:
		return

	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		_finish()


func report_sequence_finished() -> void:
	if _running and _end_condition == CombatTiming.AttackEndCondition.SEQUENCE_FINISHED:
		_finish()


func _finish() -> void:
	if not _running:
		return
	stop()
	attack_phase_finished.emit()
