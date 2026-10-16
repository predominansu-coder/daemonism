extends Node2D
class_name AttackTelegraph

var directions: Array[Vector2] = []
var ray_length: float = 300.0


func _draw() -> void:
	for direction in directions:
		draw_line(Vector2.ZERO, direction * ray_length, Color(1.0, 0.64, 0.2, 0.38), 2.0)
	draw_circle(Vector2.ZERO, 12.0, Color(0.45, 0.19, 0.06, 0.8))
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 32, Color(1.0, 0.74, 0.3), 2.0)
