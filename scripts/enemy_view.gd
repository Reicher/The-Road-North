class_name EnemyView
extends Node2D

@export_range(16.0, 256.0, 1.0) var tile_size := 96.0:
	set(value):
		tile_size = value
		queue_redraw()

@export var enemy_data := {}:
	set(value):
		enemy_data = value
		visible = not enemy_data.is_empty()
		queue_redraw()


func _ready() -> void:
	visible = not enemy_data.is_empty()
	queue_redraw()


func _draw() -> void:
	if enemy_data.is_empty():
		return

	var revealed: bool = enemy_data.get("revealed", false) == true
	var marker_radius := tile_size * 0.15
	draw_circle(Vector2(0.0, marker_radius * 0.18), marker_radius, Color(0.18, 0.05, 0.06, 0.48))
	draw_circle(Vector2.ZERO, marker_radius, Color(0.55, 0.10, 0.13))
	draw_circle(Vector2(-marker_radius * 0.35, -marker_radius * 0.28), marker_radius * 0.18, Color(1.0, 0.84, 0.34))
	draw_circle(Vector2(marker_radius * 0.35, -marker_radius * 0.28), marker_radius * 0.18, Color(1.0, 0.84, 0.34))

	if not revealed:
		draw_line(Vector2(0.0, -marker_radius * 0.55), Vector2(0.0, marker_radius * 0.15), Color(1.0, 0.82, 0.36), 3.0)
		draw_circle(Vector2(0.0, marker_radius * 0.55), 2.5, Color(1.0, 0.82, 0.36))
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(14, roundi(tile_size * 0.15))
	var icon_size := tile_size * 0.18
	var row_y := -tile_size * 0.31
	var text_bias := icon_size * 0.28
	_draw_enemy_stat(font, Vector2(-text_bias, row_y), int(enemy_data.get("power", 0)), icon_size, font_size)


func _draw_enemy_stat(font: Font, icon_center: Vector2, value: int, icon_size: float, font_size: int) -> void:
	StatIconPainter.draw_sword(self, icon_center, icon_size)
	var text_position := icon_center + Vector2(icon_size * 0.48, font_size * 0.42)
	draw_string(font, text_position + Vector2(1.5, 1.5), str(value), HORIZONTAL_ALIGNMENT_LEFT, icon_size, font_size, Color(0.08, 0.04, 0.03, 0.90))
	draw_string(font, text_position, str(value), HORIZONTAL_ALIGNMENT_LEFT, icon_size, font_size, Color(1.0, 0.94, 0.78))
