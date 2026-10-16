extends Node2D

# 위치 변화만 확인하기 위한 임시 격자입니다.
# 나중에 실제 지역/맵을 배치할 때 이 노드만 삭제하면 됩니다.
@export_range(16, 256, 1) var cell_size: int = 96
@export_range(4, 128, 1) var half_cells: int = 48


func _draw() -> void:
	var extent := float(cell_size * half_cells)
	draw_rect(
		Rect2(Vector2(-extent, -extent), Vector2(extent * 2.0, extent * 2.0)),
		Color(0.10, 0.12, 0.15)
	)

	for index in range(-half_cells, half_cells + 1):
		var coordinate := float(index * cell_size)
		draw_line(
			Vector2(coordinate, -extent), Vector2(coordinate, extent),
			Color(0.22, 0.26, 0.30), 1.0
		)
		draw_line(
			Vector2(-extent, coordinate), Vector2(extent, coordinate),
			Color(0.22, 0.26, 0.30), 1.0
		)
