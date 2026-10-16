extends SceneTree

# Run with: godot --headless --path . --script res://tests/combat_patterns_test.gd
const CUSTOM_EXECUTOR = preload("res://tests/fixtures/instant_pattern.gd")
const BOUNDS := Rect2(-100, -100, 200, 200)

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_configuration()
	await _test_telegraph_emission_and_final_hazard()
	await _test_stop_and_stale_signals()
	await _test_custom_executor_contract()
	await _test_contact_callback_cleanup()
	if _failures.is_empty():
		print("PASS: CombatPatterns — %d checks" % _checks)
		quit(0)
	else:
		printerr("FAIL: CombatPatterns — %d failures / %d checks" % [_failures.size(), _checks])
		quit(1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		printerr("FAIL: " + description)


func _pattern() -> AttackPatternDefinition:
	var pattern := AttackPatternDefinition.new()
	pattern.volley_count = 2
	pattern.projectiles_per_volley = 1
	pattern.telegraph_seconds = 0.1
	pattern.volley_interval_seconds = 0.1
	pattern.projectile_speed = 20.0
	pattern.projectile_lifetime_seconds = 0.5
	return pattern


func _runner() -> AttackPatternRunner:
	var runner := AttackPatternRunner.new()
	root.add_child(runner)
	return runner


func _custom_scene(immediate: bool) -> PackedScene:
	var executor: AttackPatternExecutor = CUSTOM_EXECUTOR.new()
	executor.set("finish_immediately", immediate)
	var packed := PackedScene.new()
	_check(packed.pack(executor) == OK, "custom subclass packs into a reusable scene")
	executor.free()
	return packed


func _visible_telegraphs(executor: AttackPatternExecutor) -> int:
	var count := 0
	for child in executor.get_children():
		if child is AttackTelegraph and child.visible:
			count += 1
	return count


func _projectiles(executor: AttackPatternExecutor) -> Array[CombatProjectile]:
	var result: Array[CombatProjectile] = []
	for child in executor.get_children():
		if child is CombatProjectile and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _dispose(runner: AttackPatternRunner) -> void:
	runner.stop()
	runner.queue_free()
	await process_frame


func _test_configuration() -> void:
	var pattern := _pattern()
	_check(pattern.is_configured(), "development volley is configured")
	pattern.volley_count = 100000
	_check(pattern.is_configured(), "pattern counts have no arbitrary hard-coded cap")
	pattern.volley_count = 0
	_check(not pattern.is_configured(), "built-in volley requires at least one volley")
	pattern.executor_scene = _custom_scene(true)
	_check(pattern.is_configured(), "custom executor can define its own step count")
	pattern.projectile_speed = NAN
	_check(not pattern.is_configured(), "custom helper rejects non-finite projectile speed")
	pattern.projectile_speed = 20.0
	pattern.projectile_lifetime_seconds = 0.0
	_check(not pattern.is_configured(), "custom helper rejects nonpositive projectile lifetime")
	pattern.projectile_lifetime_seconds = 0.5
	pattern.projectile_radius = INF
	_check(not pattern.is_configured(), "custom helper rejects non-finite projectile radius")


func _test_telegraph_emission_and_final_hazard() -> void:
	var runner := _runner()
	var cycles: Array[int] = []
	runner.sequence_finished.connect(func(cycle: int) -> void: cycles.append(cycle))
	var pattern := _pattern()
	_check(runner.start_sequence(pattern, null, BOUNDS, 17), "built-in sequence starts")
	var executor: AttackPatternExecutor = runner.get_child(0)
	_check(_visible_telegraphs(executor) == 1, "attack starts with a visible warning")
	executor._physics_process(0.05)
	_check(runner.active_projectile_count() == 0, "warning precedes projectile emission")
	executor._physics_process(0.05)
	_check(runner.active_projectile_count() == 1, "first telegraph emits a visible projectile")
	_check(_visible_telegraphs(executor) == 0, "fired warning is removed")
	executor._physics_process(0.1)
	_check(_visible_telegraphs(executor) == 1, "next volley receives its own warning")
	executor._physics_process(0.1)
	_check(runner.active_projectile_count() == 2, "finite volley emits every configured shot")
	_check(cycles.is_empty(), "last emission does not prematurely finish the sequence")
	var projectiles := _projectiles(executor)
	if projectiles.size() == 2:
		_check(projectiles[0].collision_layer == 4 and projectiles[0].collision_mask == 2,
			"projectile collision boundary addresses combat-player layer 2")
		projectiles[0]._physics_process(0.5)
		executor._physics_process(0.0)
		_check(runner.active_projectile_count() == 1 and cycles.is_empty(),
			"one remaining hazard keeps sequence open")
		projectiles[1]._physics_process(0.5)
		executor._physics_process(0.0)
		_check(cycles == [17], "final hazard retirement completes the current cycle once")
		executor.sequence_finished.emit()
		_check(cycles == [17], "duplicate executor completion cannot duplicate cycle completion")
	else:
		_check(false, "two live projectiles exist before retirement")
	_check(pattern.volley_count == 2 and pattern.telegraph_seconds == 0.1,
		"execution preserves reusable resource values")
	await _dispose(runner)


func _test_stop_and_stale_signals() -> void:
	var runner := _runner()
	var cycles: Array[int] = []
	var contacts: Array[Node2D] = []
	runner.sequence_finished.connect(func(cycle: int) -> void: cycles.append(cycle))
	runner.projectile_contact.connect(func(body: Node2D) -> void: contacts.append(body))
	var pattern := _pattern()
	_check(runner.start_sequence(pattern, null, BOUNDS, 21), "stoppable sequence starts")
	var old_executor: AttackPatternExecutor = runner.get_child(0)
	old_executor._physics_process(0.1)
	old_executor._physics_process(0.1)
	var hazards := _projectiles(old_executor)
	_check(hazards.size() == 1 and _visible_telegraphs(old_executor) == 1,
		"stop fixture has both active projectile and warning")
	runner.stop()
	_check(runner.active_projectile_count() == 0, "stop immediately empties active hazards")
	_check(_visible_telegraphs(old_executor) == 0, "stop immediately hides telegraphs")
	for hazard in hazards:
		_check(not hazard.visible and not hazard.is_physics_processing(),
			"stop immediately disables visible projectile movement")
	old_executor.sequence_finished.emit()
	old_executor.projectile_contact.emit(null)
	_check(cycles.is_empty() and contacts.is_empty(), "stopped executor cannot report late signals")
	_check(runner.start_sequence(pattern, null, BOUNDS, 22), "runner restarts after cancellation")
	old_executor.sequence_finished.emit()
	old_executor.projectile_contact.emit(null)
	_check(cycles.is_empty() and contacts.is_empty(), "previous executor cannot affect a replacement")
	runner.stop()
	await process_frame
	_check(runner.get_child_count() == 0, "stop frees every executor and child object")
	await _dispose(runner)


func _test_custom_executor_contract() -> void:
	var runner := _runner()
	var cycles: Array[int] = []
	var contacts: Array[Node2D] = []
	runner.sequence_finished.connect(func(cycle: int) -> void: cycles.append(cycle))
	runner.projectile_contact.connect(func(body: Node2D) -> void: contacts.append(body))
	var pattern := _pattern()
	pattern.executor_scene = _custom_scene(true)
	_check(runner.start_sequence(pattern, null, BOUNDS, 31), "custom executor scene starts")
	_check(cycles == [31], "custom executor may complete synchronously during startup")
	_check(runner.active_projectile_count() == 0, "synchronous completion clears active executor")
	var finished_executor: AttackPatternExecutor = runner.get_child(0)
	finished_executor.projectile_contact.emit(null)
	_check(contacts.is_empty(), "completed executor cannot emit a late contact")
	pattern.executor_scene = _custom_scene(false)
	_check(runner.start_sequence(pattern, null, BOUNDS, 32), "custom projectile sequence starts")
	var executor: AttackPatternExecutor = runner.get_child(runner.get_child_count() - 1)
	_check(runner.active_projectile_count() == 1 and cycles == [31],
		"custom executor reuses projectile helper and waits for its hazard")
	var hazards := _projectiles(executor)
	if hazards.size() == 1:
		hazards[0]._physics_process(0.5)
		executor._physics_process(0.0)
		_check(cycles == [31, 32], "custom helper sequence completes after its last hazard")
	else:
		_check(false, "custom helper emitted one hazard")
	await _dispose(runner)


func _test_contact_callback_cleanup() -> void:
	var runner := _runner()
	var cycles: Array[int] = []
	var contacts: Array[Node2D] = []
	runner.sequence_finished.connect(func(cycle: int) -> void: cycles.append(cycle))
	var recipient := CharacterBody2D.new()
	recipient.collision_layer = 2
	recipient.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collider.shape = shape
	recipient.add_child(collider)
	root.add_child(recipient)
	runner.projectile_contact.connect(func(body: Node2D) -> void:
		contacts.append(body)
		runner.stop()
	)
	var pattern := _pattern()
	pattern.volley_count = 1
	pattern.telegraph_seconds = 0.0
	pattern.projectile_speed = 300.0
	pattern.projectile_lifetime_seconds = 1.0
	_check(runner.start_sequence(pattern, recipient, BOUNDS, 41), "collision sequence starts")
	var deadline := Time.get_ticks_msec() + 1500
	while contacts.is_empty() and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(contacts.size() == 1 and contacts[0] == recipient,
		"real Area2D contact supplies its future damage recipient")
	_check(cycles.is_empty() and runner.active_projectile_count() == 0,
		"contact listener can stop safely without completing a canceled attack")
	await process_frame
	_check(runner.get_child_count() == 0, "physics-callback stop frees all hazard objects")
	recipient.queue_free()
	await _dispose(runner)
