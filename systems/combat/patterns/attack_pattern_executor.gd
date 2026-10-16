extends Node2D
class_name AttackPatternExecutor

# Custom executor scenes subclass this class, implement _begin_pattern() and
# _advance_pattern(), use the helpers below, then call finish_emission().
# Completion includes all spawned projectile lifetimes, not just emission time.
signal sequence_finished
signal projectile_contact(recipient: Node2D)

var definition: AttackPatternDefinition
var target: Node2D
var arena_bounds: Rect2
var _running: bool = false
var _emission_finished: bool = false
var _projectiles: Array[CombatProjectile] = []
var _telegraphs: Array[AttackTelegraph] = []


func _ready() -> void:
	set_physics_process(false)


func start_sequence(pattern: AttackPatternDefinition, recipient: Node2D, bounds: Rect2) -> void:
	stop()
	definition = pattern
	target = recipient
	arena_bounds = bounds
	_running = true
	_emission_finished = false
	set_physics_process(true)
	_begin_pattern()


func stop() -> void:
	_running = false
	set_physics_process(false)
	clear_telegraphs()
	# cancel() emits retired synchronously; iterate a snapshot as callbacks erase.
	for projectile in _projectiles.duplicate():
		if is_instance_valid(projectile):
			projectile.cancel()
	_projectiles.clear()
	target = null
	definition = null


func active_projectile_count() -> int:
	return _projectiles.size()


func spawn_projectile(origin: Vector2, direction: Vector2,
		speed: float = -1.0, lifetime_seconds: float = -1.0) -> CombatProjectile:
	if not _running or _emission_finished:
		return null
	var projectile := CombatProjectile.new()
	projectile.configure(origin, direction,
		definition.projectile_speed if speed < 0.0 else speed,
		definition.projectile_lifetime_seconds if lifetime_seconds < 0.0 else lifetime_seconds,
		arena_bounds, definition.projectile_radius)
	_projectiles.append(projectile)
	projectile.retired.connect(_on_projectile_retired.bind(projectile), CONNECT_ONE_SHOT)
	projectile.contact.connect(_on_projectile_contact)
	add_child(projectile)
	return projectile


func show_telegraph(origin: Vector2, directions: Array[Vector2]) -> AttackTelegraph:
	if not _running or _emission_finished:
		return null
	var telegraph := AttackTelegraph.new()
	telegraph.position = origin
	telegraph.directions = directions.duplicate()
	telegraph.ray_length = arena_bounds.size.length()
	_telegraphs.append(telegraph)
	add_child(telegraph)
	return telegraph


func clear_telegraphs() -> void:
	for telegraph in _telegraphs:
		if is_instance_valid(telegraph):
			telegraph.hide()
			telegraph.queue_free()
	_telegraphs.clear()


func finish_emission() -> void:
	_emission_finished = true
	clear_telegraphs()


func _physics_process(delta: float) -> void:
	if not _running:
		return
	if not _emission_finished:
		_advance_pattern(delta)
	if _running and _emission_finished and _projectiles.is_empty():
		_running = false
		set_physics_process(false)
		sequence_finished.emit()


func _begin_pattern() -> void:
	pass


func _advance_pattern(_delta: float) -> void:
	pass


func _on_projectile_retired(projectile: CombatProjectile) -> void:
	_projectiles.erase(projectile)


func _on_projectile_contact(recipient: Node2D) -> void:
	if _running:
		projectile_contact.emit(recipient)
