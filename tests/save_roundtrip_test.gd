extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var save_mode := "--save" in OS.get_cmdline_user_args()
	var scene = load("res://tests/save_smoke_test.tscn").instantiate()
	scene.test_action = "SAVE" if save_mode else "LOAD"
	root.add_child(scene)
	var world = root.get_node("WorldState")
	var valid: bool = world.get_flag("test.found_secret") \
		and world.get_counter("test.kills") == 3 \
		and world.get_outcome("test.important_enemy") == "resolved"
	valid = valid and FileAccess.file_exists("user://saves/slot_99.json")
	if not valid:
		push_error("Save roundtrip mismatch")
		quit(1)
		return
	print("PASS: cross-process save" if save_mode else "PASS: cross-process load")
	scene.queue_free()
	await process_frame
	quit(0)
