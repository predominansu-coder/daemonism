extends SceneTree

# Run with: godot --headless --path . --script res://tests/combat_director_test.gd
const DIRECTOR_SCRIPT = preload("res://systems/combat/combat_director.gd")
const GATE_SCRIPT = preload("res://systems/combat/attack_phase_gate.gd")
const TIMING_SCRIPT = preload("res://systems/combat/combat_timing.gd")
const PHASE_TIMEOUT_MSEC := 2000

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_timing_validation()
	await _test_duration_flow_and_one_action()
	await _test_synchronous_sequence_completion()
	await _test_sequence_cycles_and_stop()
	await _test_timeout_finish_reentrancy()
	await _test_timeout_stop_reentrancy()

	if _failures.is_empty():
		print("PASS: CombatDirector — %d checks" % _checks)
		quit(0)
	else:
		printerr("FAIL: CombatDirector — %d failures / %d checks" % [
			_failures.size(), _checks
		])
		quit(1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		printerr("FAIL: " + description)


func _create_director() -> CombatDirector:
	var director: CombatDirector = DIRECTOR_SCRIPT.new()
	var gate: AttackPhaseGate = GATE_SCRIPT.new()
	gate.name = "AttackPhaseGate"
	director.add_child(gate)
	root.add_child(director)
	return director


func _timing(sequence: bool = false) -> CombatTiming:
	var timing: CombatTiming = TIMING_SCRIPT.new()
	timing.attack_end_condition = (
		CombatTiming.AttackEndCondition.SEQUENCE_FINISHED
		if sequence else CombatTiming.AttackEndCondition.DURATION
	)
	timing.attack_duration_seconds = 0.1
	timing.action_duration_seconds = 0.5
	return timing


func _wait_for_phase(director: CombatDirector, expected: int) -> bool:
	var deadline := Time.get_ticks_msec() + PHASE_TIMEOUT_MSEC
	while director.phase != expected and Time.get_ticks_msec() < deadline:
		await process_frame
	return director.phase == expected


func _dispose(director: CombatDirector) -> void:
	director.stop()
	director.queue_free()
	await process_frame


func _test_timing_validation() -> void:
	var timing := _timing()
	_check(timing.is_configured(), "valid duration timing is configured")
	timing.attack_end_condition = CombatTiming.AttackEndCondition.SEQUENCE_FINISHED
	_check(timing.is_configured(), "valid sequence timing is configured")
	timing.set("attack_end_condition", 99)
	_check(not timing.is_configured(), "unknown attack-end enum is rejected")
	timing.attack_end_condition = CombatTiming.AttackEndCondition.DURATION
	timing.action_duration_seconds = 0.0
	_check(not timing.is_configured(), "zero action duration is rejected")
	timing.action_duration_seconds = NAN
	_check(not timing.is_configured(), "non-finite action duration is rejected")


func _test_duration_flow_and_one_action() -> void:
	var director := _create_director()
	var readings: Array[Vector2] = []
	director.action_time_changed.connect(func(remaining: float, total: float) -> void:
		readings.append(Vector2(remaining, total))
	)
	_check(director.begin(_timing()), "duration encounter begins")
	_check(director.phase == CombatDirector.Phase.ENEMY_ATTACK,
		"duration encounter starts in enemy attack")
	_check(not director.notify_player_action_applied(),
		"player action is rejected during enemy attack")
	_check(not director.report_attack_sequence_finished(director.attack_cycle),
		"sequence completion cannot shorten a duration attack")
	var cycle := director.attack_cycle
	_check(await _wait_for_phase(director, CombatDirector.Phase.PLAYER_ACTION),
		"elapsed attack duration opens shared action phase")
	_check(not readings.is_empty(), "action timer emits UI data")
	if not readings.is_empty():
		_check(readings[0].x > 0.0 and readings[0].x <= readings[0].y,
			"action timer starts with positive bounded remaining time")
		director._process(0.125)
		_check(readings.back().x < readings[0].x,
			"action timer emits decreasing remaining time")
	_check(director.can_accept_player_action(), "action window accepts an action")
	_check(director.notify_player_action_applied(), "first completed action is accepted")
	_check(director.phase == CombatDirector.Phase.ENEMY_ATTACK,
		"completed action starts next attack")
	_check(director.attack_cycle > cycle, "next attack has a fresh cycle")
	_check(not director.notify_player_action_applied(),
		"same action window cannot consume a second action")
	director.attack_gate._process(100.0)
	_check(director.phase == CombatDirector.Phase.PLAYER_ACTION,
		"next duration attack opens another action window")
	cycle = director.attack_cycle
	director._process(100.0)
	_check(director.phase == CombatDirector.Phase.ENEMY_ATTACK and director.attack_cycle > cycle,
		"unconsumed action window expires into next attack")
	await _dispose(director)


func _test_synchronous_sequence_completion() -> void:
	var director := _create_director()
	var accepted: Array[bool] = []
	director.phase_changed.connect(func(next_phase: int) -> void:
		if next_phase == CombatDirector.Phase.ENEMY_ATTACK:
			accepted.append(director.report_attack_sequence_finished(director.attack_cycle))
	)
	_check(director.begin(_timing(true)), "synchronous sequence encounter begins")
	_check(accepted.size() == 1 and accepted[0],
		"sequence can finish synchronously from attack-start signal")
	_check(director.phase == CombatDirector.Phase.PLAYER_ACTION,
		"synchronous sequence completion opens action phase")
	_check(not director.attack_gate.is_processing(),
		"completed synchronous sequence leaves gate stopped")
	await _dispose(director)


func _test_sequence_cycles_and_stop() -> void:
	var director := _create_director()
	_check(director.begin(_timing(true)), "sequence encounter begins")
	var first_cycle := director.attack_cycle
	director.attack_gate._process(100.0)
	_check(director.phase == CombatDirector.Phase.ENEMY_ATTACK,
		"sequence attack does not finish from elapsed duration")
	_check(director.report_attack_sequence_finished(first_cycle),
		"current sequence completion is accepted")
	_check(not director.report_attack_sequence_finished(first_cycle),
		"duplicate completion is rejected outside attack phase")
	_check(director.notify_player_action_applied(), "sequence action starts next cycle")
	var second_cycle := director.attack_cycle
	_check(second_cycle > first_cycle, "sequence attack cycle increases")
	_check(not director.report_attack_sequence_finished(first_cycle),
		"late completion from previous attack is rejected")
	_check(director.phase == CombatDirector.Phase.ENEMY_ATTACK,
		"stale completion leaves current attack running")
	director.stop()
	var stopped_cycle := director.attack_cycle
	_check(stopped_cycle > second_cycle, "stop invalidates the current attack cycle")
	_check(director.phase == CombatDirector.Phase.IDLE,
		"stop returns director to idle")
	_check(not director.is_processing() and not director.attack_gate.is_processing(),
		"stop disables both phase timer and attack gate")
	_check(not director.report_attack_sequence_finished(second_cycle),
		"stopped sequence cannot complete")
	director.attack_gate.report_sequence_finished()
	director.attack_gate._process(100.0)
	director._process(100.0)
	_check(director.phase == CombatDirector.Phase.IDLE,
		"stopped gate and director ignore queued work")
	_check(director.begin(_timing(true)), "stopped director can start another encounter")
	_check(director.attack_cycle > stopped_cycle, "restart obtains a new attack cycle")
	_check(not director.report_attack_sequence_finished(second_cycle),
		"completion from previous encounter is rejected after restart")
	_check(director.phase == CombatDirector.Phase.ENEMY_ATTACK,
		"old encounter completion does not advance restarted encounter")
	director.attack_gate.report_sequence_finished()
	_check(director.phase == CombatDirector.Phase.PLAYER_ACTION,
		"retained direct gate completion interface still works")
	await _dispose(director)


func _test_timeout_finish_reentrancy() -> void:
	var director := _create_director()
	var expirations: Array[int] = []
	director.action_window_expired.connect(func() -> void:
		expirations.append(1)
		director.finish_encounter()
	)
	_check(director.begin(_timing()), "finish-on-timeout encounter begins")
	director.attack_gate._process(100.0)
	_check(director.phase == CombatDirector.Phase.PLAYER_ACTION,
		"finish-on-timeout fixture reaches action phase")
	director._process(100.0)
	_check(expirations.size() == 1, "timeout emits exactly one expiration")
	_check(director.phase == CombatDirector.Phase.FINISHED,
		"timeout listener can finish without restarting attack")
	_check(not director.is_processing() and not director.attack_gate.is_processing(),
		"timeout finish leaves all phase clocks stopped")
	_check(not director.report_attack_sequence_finished(director.attack_cycle),
		"finished encounter rejects sequence completion")
	director._process(100.0)
	_check(expirations.size() == 1 and director.phase == CombatDirector.Phase.FINISHED,
		"finished encounter remains terminal on later frames")
	await _dispose(director)


func _test_timeout_stop_reentrancy() -> void:
	var director := _create_director()
	director.action_window_expired.connect(func() -> void:
		director.stop()
	)
	_check(director.begin(_timing()), "stop-on-timeout encounter begins")
	director.attack_gate._process(100.0)
	director._process(100.0)
	_check(director.phase == CombatDirector.Phase.IDLE,
		"timeout listener can stop without restarting attack")
	_check(not director.is_processing() and not director.attack_gate.is_processing(),
		"timeout stop leaves all phase clocks stopped")
	await _dispose(director)
