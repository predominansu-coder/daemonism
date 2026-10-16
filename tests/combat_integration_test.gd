extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func wait_until(predicate: Callable, seconds: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()


func run() -> void:
	await test_player_contacts()
	var world = root.get_node("WorldState")
	var snapshot: Dictionary = world.create_snapshot()
	var definition: EncounterDefinition = load("res://data/encounters/dev_patrol.tres").duplicate(true)
	definition.combat_timing.attack_duration_seconds = 0.3
	definition.combat_timing.action_duration_seconds = 0.6
	definition.attack_pattern.telegraph_seconds = 0.02
	definition.attack_pattern.volley_count = 1
	definition.attack_pattern.projectiles_per_volley = 1
	definition.attack_pattern.projectile_lifetime_seconds = 0.12
	var game = load("res://core/game_root.tscn").instantiate()
	root.add_child(game)
	await process_frame
	expect(game.active_scene.has_signal("start_requested"), "title is active")
	game.active_scene.start_button.pressed.emit()
	await process_frame
	var field = game.active_scene
	expect(field.has_signal("encounter_requested"), "start button opens field")
	var enemy: PatrolEnemy = field.get_node("World/Enemies/DevPatrolEnemy")
	enemy.encounter_definition = definition
	# Real Area2D body_entered drives the deferred transition under physics.
	field.player.global_position = enemy.global_position
	var entered := await wait_until(func(): return game.active_scene != field)
	expect(entered, "physics encounter defers scene transition")
	if not entered:
		game.queue_free()
		quit(1)
		return
	var combat = game.active_scene
	expect(combat.arena.player != field.player, "combat owns separate player without field camera")
	expect(combat.director.phase == CombatDirector.Phase.ENEMY_ATTACK, "attack begins on encounter")
	var spawned := await wait_until(func(): return combat.arena.pattern_runner.active_projectile_count() > 0, 0.2)
	expect(spawned, "attack phase emits real projectile")
	var acted := await wait_until(func(): return combat.director.phase == CombatDirector.Phase.PLAYER_ACTION)
	expect(acted, "duration cutoff enters action")
	expect(combat.action_window_hud.visible, "top action gauge visible")
	expect(combat.time_bar.value > 0.0, "top action gauge receives remaining time")
	expect(combat.arena.pattern_runner.active_projectile_count() == 0, "action phase clears hazards")
	var remaining: float = combat.time_bar.value
	await create_timer(0.08).timeout
	expect(combat.time_bar.value < remaining, "displayed gauge decreases")
	combat.exit_button.pressed.emit()
	await process_frame
	expect(game.active_scene == field, "debug exit restores original field instance")
	expect(world.create_snapshot() == snapshot, "debug exit never applies combat result")
	# Move away long enough for contact lock to rearm, then enter again.
	field.player.global_position = enemy.global_position + Vector2(150, 0)
	await create_timer(0.65).timeout
	field.player.global_position = enemy.global_position
	var reentered := await wait_until(func(): return game.active_scene != field)
	expect(reentered, "patrol encounter rearms after leaving sensor")
	if reentered:
		game.active_scene.exit_button.pressed.emit()
		await process_frame
	game.queue_free()
	await process_frame
	# Use actual sequence mode, with final projectile retirement driving the gate.
	definition.combat_timing.attack_end_condition = CombatTiming.AttackEndCondition.SEQUENCE_FINISHED
	definition.combat_timing.attack_duration_seconds = 99.0
	var sequence_combat = load("res://scenes/combat/combat_scene.tscn").instantiate()
	root.add_child(sequence_combat)
	sequence_combat.set_encounter(EncounterRequest.new(definition, &"test.sequence"))
	expect(sequence_combat.director.phase == CombatDirector.Phase.ENEMY_ATTACK, "sequence attack begins")
	var sequence_action := await wait_until(func(): return sequence_combat.director.phase == CombatDirector.Phase.PLAYER_ACTION)
	expect(sequence_action, "final projectile retirement completes sequence without duration timer")
	expect(sequence_combat.arena.pattern_runner.active_projectile_count() == 0, "sequence action has no remaining hazards")
	sequence_combat.director.finish_encounter()
	expect(not sequence_combat.arena.player.controls_enabled, "finish disables combat controls")
	expect(sequence_combat.arena.pattern_runner.active_projectile_count() == 0, "finish cleans patterns")
	sequence_combat.queue_free()
	await process_frame
	print("PASS: %d integration checks" % checks if failures == 0 else "FAIL: %d/%d integration checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func test_player_contacts() -> void:
	var player: CombatPlayer = load("res://actors/player/combat_player.tscn").instantiate()
	root.add_child(player)
	player.configure_bounds(Rect2(-400, -220, 800, 440))
	var contacts: Array[bool] = []
	var normal := CombatProjectile.new()
	normal.configure(Vector2(0, -8), Vector2.DOWN, 1.0, 1.0, Rect2(-400, -220, 800, 440), 6.0)
	normal.contact.connect(func(recipient: Node2D):
		expect(recipient == player, "projectile identifies actual CombatPlayer")
		contacts.append(player.is_dashing())
	)
	root.add_child(normal)
	expect(await wait_until(func(): return contacts.size() == 1), "projectile contact reaches normal combat player")
	await process_frame
	player.global_position = Vector2.ZERO
	expect(player.request_dash(Vector2.RIGHT), "dash starts before contact test")
	var during_dash := CombatProjectile.new()
	during_dash.configure(Vector2(24, 0), Vector2.DOWN, 1.0, 1.0, Rect2(-400, -220, 800, 440), 6.0)
	during_dash.contact.connect(func(recipient: Node2D):
		expect(recipient == player, "dash contact identifies actual CombatPlayer")
		contacts.append(player.is_dashing())
	)
	root.add_child(during_dash)
	expect(await wait_until(func(): return contacts.size() == 2), "projectile contact reaches moving dash player")
	expect(contacts.size() == 2 and contacts[1], "contact is emitted while dash is active without immunity")
	player.queue_free()
	await process_frame
