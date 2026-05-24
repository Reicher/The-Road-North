class_name RoadTile
extends Node2D

@export var definition: Resource:
	set(value):
		definition = value
		queue_redraw()

@export_range(0, 3, 1) var rotation_steps := 0:
	set(value):
		rotation_steps = posmod(value, 4)
		queue_redraw()

@export_range(16.0, 256.0, 1.0) var tile_size := 96.0:
	set(value):
		tile_size = value
		queue_redraw()

@export var tile_tint := Color.WHITE:
	set(value):
		tile_tint = value
		modulate = tile_tint

@export var highlight_enabled := false:
	set(value):
		highlight_enabled = value
		queue_redraw()

@export var highlight_color := Color(0.25, 0.85, 0.35, 0.38):
	set(value):
		highlight_color = value
		queue_redraw()

@export var enemy_data := {}:
	set(value):
		enemy_data = value
		queue_redraw()

@export var enemy_offset := Vector2.ZERO:
	set(value):
		enemy_offset = value
		queue_redraw()


func _ready() -> void:
	modulate = tile_tint
	queue_redraw()


func _draw() -> void:
	var half_size := tile_size * 0.5
	var tile_rect := Rect2(Vector2.ONE * -half_size, Vector2.ONE * tile_size)
	draw_rect(tile_rect.grow(-2.0), Color(0.55, 0.63, 0.45), true)

	if definition == null:
		if highlight_enabled:
			draw_rect(tile_rect.grow(-3.0), highlight_color, false, 5.0)
		return

	var openings := get_openings()
	var shoulder_width := tile_size * 0.42
	var road_width := tile_size * 0.28
	var shoulder_color: Color = definition.get("shoulder_color")
	var road_color: Color = definition.get("road_color")
	var center := Vector2.ZERO

	_draw_connections(openings, shoulder_width, shoulder_color)
	draw_circle(center, shoulder_width * 0.5, shoulder_color)

	_draw_connections(openings, road_width, road_color)
	draw_circle(center, road_width * 0.5, road_color)

	_draw_enemy()

	if highlight_enabled:
		draw_rect(tile_rect.grow(-3.0), highlight_color, false, 5.0)


func rotate_clockwise() -> void:
	rotation_steps += 1


func set_highlight(enabled: bool, color: Color = highlight_color) -> void:
	highlight_color = color
	highlight_enabled = enabled


func get_openings() -> Dictionary:
	if definition == null or not definition.has_method("get_rotated_openings"):
		return {}
	return definition.get_rotated_openings(rotation_steps)


func set_enemy_data(value: Dictionary) -> void:
	enemy_data = value


func _draw_connections(openings: Dictionary, width: float, color: Color) -> void:
	var half_size := tile_size * 0.5
	var half_width := width * 0.5

	if openings.get("north", false) == true:
		draw_rect(Rect2(Vector2(-half_width, -half_size), Vector2(width, half_size)), color, true)
	if openings.get("east", false) == true:
		draw_rect(Rect2(Vector2.ZERO - Vector2(0.0, half_width), Vector2(half_size, width)), color, true)
	if openings.get("south", false) == true:
		draw_rect(Rect2(Vector2(-half_width, 0.0), Vector2(width, half_size)), color, true)
	if openings.get("west", false) == true:
		draw_rect(Rect2(Vector2(-half_size, -half_width), Vector2(half_size, width)), color, true)


func _draw_enemy() -> void:
	if enemy_data.is_empty():
		return

	var revealed: bool = enemy_data.get("revealed", false) == true
	var marker_radius := tile_size * 0.15
	var marker_center := enemy_offset
	draw_circle(marker_center + Vector2(0.0, marker_radius * 0.18), marker_radius, Color(0.18, 0.05, 0.06, 0.48))
	draw_circle(marker_center, marker_radius, Color(0.55, 0.10, 0.13))
	draw_circle(marker_center + Vector2(-marker_radius * 0.35, -marker_radius * 0.28), marker_radius * 0.18, Color(1.0, 0.84, 0.34))
	draw_circle(marker_center + Vector2(marker_radius * 0.35, -marker_radius * 0.28), marker_radius * 0.18, Color(1.0, 0.84, 0.34))

	if not revealed:
		draw_line(marker_center + Vector2(0.0, -marker_radius * 0.55), marker_center + Vector2(0.0, marker_radius * 0.15), Color(1.0, 0.82, 0.36), 3.0)
		draw_circle(marker_center + Vector2(0.0, marker_radius * 0.55), 2.5, Color(1.0, 0.82, 0.36))
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(14, roundi(tile_size * 0.15))
	var icon_size := tile_size * 0.18
	var row_y := marker_center.y - tile_size * 0.31
	_draw_enemy_stat(font, Vector2(marker_center.x - tile_size * 0.32, row_y), "health", int(enemy_data.get("health", 0)), icon_size, font_size)
	_draw_enemy_stat(font, Vector2(marker_center.x - tile_size * 0.02, row_y), "attack", int(enemy_data.get("attack", 0)), icon_size, font_size)
	_draw_enemy_stat(font, Vector2(marker_center.x + tile_size * 0.28, row_y), "armor", int(enemy_data.get("armor", 0)), icon_size, font_size)


func _draw_enemy_stat(font: Font, icon_center: Vector2, stat_name: String, value: int, icon_size: float, font_size: int) -> void:
	if stat_name == "health":
		StatIconPainter.draw_heart(self, icon_center, icon_size)
	elif stat_name == "attack":
		StatIconPainter.draw_sword(self, icon_center, icon_size)
	elif stat_name == "armor":
		StatIconPainter.draw_shield(self, icon_center, icon_size)
	var text_position := icon_center + Vector2(icon_size * 0.48, font_size * 0.42)
	draw_string(font, text_position + Vector2(1.5, 1.5), str(value), HORIZONTAL_ALIGNMENT_LEFT, icon_size, font_size, Color(0.08, 0.04, 0.03, 0.90))
	draw_string(font, text_position, str(value), HORIZONTAL_ALIGNMENT_LEFT, icon_size, font_size, Color(1.0, 0.94, 0.78))
