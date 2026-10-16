extends Node2D
class_name CombatArena

# Development layout, editable per arena. No final pixel or camera scale implied.
@export var bounds: Rect2 = Rect2(-400, -220, 800, 440)
@onready var player: CombatPlayer = $Player
@onready var pattern_runner: AttackPatternRunner = $PatternRunner
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	player.configure_bounds(bounds)
	_create_walls()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	queue_redraw()


func _fit_camera() -> void:
	var available := get_viewport_rect().size
	var framed_size := bounds.size + Vector2(80, 240)
	var scale_factor := minf(available.x / framed_size.x, available.y / framed_size.y)
	camera.zoom = Vector2.ONE * maxf(0.1, scale_factor)
	camera.position = bounds.get_center()


func _create_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "BoundaryWalls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var edges: Array[Rect2] = [
		Rect2(bounds.position - Vector2(16, 16), Vector2(bounds.size.x + 32, 16)),
		Rect2(Vector2(bounds.position.x - 16, bounds.end.y), Vector2(bounds.size.x + 32, 16)),
		Rect2(bounds.position - Vector2(16, 0), Vector2(16, bounds.size.y)),
		Rect2(Vector2(bounds.end.x, bounds.position.y), Vector2(16, bounds.size.y))
	]
	for edge in edges:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = edge.size
		collision.shape = shape
		collision.position = edge.get_center()
		body.add_child(collision)


func _draw() -> void:
	draw_rect(bounds, Color(0.07, 0.10, 0.15))
	draw_rect(bounds, Color(0.4, 0.6, 0.7), false, 3.0)
