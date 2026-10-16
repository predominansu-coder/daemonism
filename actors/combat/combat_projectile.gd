extends Area2D
class_name CombatProjectile

# Contact is the future damage receiver boundary. No HP or invulnerability
# policy belongs here, so dashing never suppresses this signal.
signal contact(recipient: Node2D)
signal retired

var _velocity: Vector2 = Vector2.ZERO
var _remaining_seconds: float = 0.0
var _arena_bounds: Rect2
var _radius: float = 6.0
var _active: bool = false


func configure(origin: Vector2, direction: Vector2, speed: float,
		lifetime_seconds: float, bounds: Rect2, radius: float) -> void:
	position = origin
	_velocity = direction.normalized() * speed
	_remaining_seconds = lifetime_seconds
	_arena_bounds = bounds
	_radius = radius
	_active = true
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_recipient_entered)
	area_entered.connect(_on_recipient_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	position += _velocity * delta
	_remaining_seconds -= delta
	if _remaining_seconds <= 0.0 or not _arena_bounds.grow(_radius).has_point(position):
		cancel()


func cancel() -> void:
	if not _active:
		return
	_active = false
	hide()
	set_physics_process(false)
	# A collision receiver can stop the whole sequence during a physics callback.
	set_deferred("monitoring", false)
	retired.emit()
	queue_free()


func _on_recipient_entered(recipient: Node2D) -> void:
	if not _active:
		return
	contact.emit(recipient)
	cancel()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius + 2.0, Color(0.4, 0.08, 0.18, 0.7))
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.35, 0.46))
	draw_circle(Vector2.ZERO, maxf(1.0, _radius * 0.38), Color(1.0, 0.92, 0.7))
