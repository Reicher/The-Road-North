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
		_refresh_enemy_view()
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
		_refresh_enemy_view()
		queue_redraw()

@export var landmark_data := {}:
	set(value):
		landmark_data = value
		queue_redraw()

@export var enemy_offset := Vector2.ZERO:
	set(value):
		enemy_offset = value
		_refresh_enemy_view()
		queue_redraw()

var _enemy_view: Node2D


func _ready() -> void:
	_enemy_view = get_node_or_null("Enemy") as Node2D
	modulate = tile_tint
	_refresh_enemy_view()
	queue_redraw()


func _draw() -> void:
	var half_size := tile_size * 0.5
	var tile_rect := Rect2(Vector2.ONE * -half_size, Vector2.ONE * tile_size)
	var terrain_color := Color(0.55, 0.63, 0.45)
	if definition != null and definition.get("terrain_color") != null:
		terrain_color = definition.get("terrain_color")
	draw_rect(tile_rect.grow(-2.0), terrain_color, true)

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

	if definition.get("road_visible") != false:
		_draw_connections(openings, shoulder_width, shoulder_color)
		draw_circle(center, shoulder_width * 0.5, shoulder_color)

		_draw_connections(openings, road_width, road_color)
		draw_circle(center, road_width * 0.5, road_color)
	_draw_visual_identity(str(definition.get("visual_identity")), tile_rect)
	if not landmark_data.is_empty():
		_draw_landmark(landmark_data, tile_rect)

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


func _draw_visual_identity(identity: String, tile_rect: Rect2) -> void:
	if identity == "house":
		_draw_house(tile_rect)


func _draw_house(tile_rect: Rect2) -> void:
	var center := tile_rect.get_center() + Vector2(0.0, tile_size * 0.10)
	var house_size := Vector2(tile_size * 0.30, tile_size * 0.24)
	var house_rect := Rect2(center - Vector2(house_size.x * 0.5, house_size.y * 0.25), house_size)
	var roof := PackedVector2Array([
		Vector2(house_rect.position.x - tile_size * 0.035, house_rect.position.y),
		Vector2(house_rect.get_center().x, house_rect.position.y - tile_size * 0.15),
		Vector2(house_rect.end.x + tile_size * 0.035, house_rect.position.y),
	])
	draw_colored_polygon(roof, Color(0.42, 0.20, 0.18))
	draw_rect(house_rect, Color(0.70, 0.58, 0.42), true)
	draw_rect(house_rect, Color(0.26, 0.19, 0.14), false, 1.5)
	draw_rect(Rect2(Vector2(house_rect.get_center().x - tile_size * 0.035, house_rect.end.y - tile_size * 0.10), Vector2(tile_size * 0.07, tile_size * 0.10)), Color(0.30, 0.18, 0.10), true)


func _draw_landmark(landmark: Dictionary, tile_rect: Rect2) -> void:
	var kind := str(landmark.get("type", ""))
	var center := tile_rect.get_center()
	if kind == GameMap.LANDMARK_BERRY_BUSH:
		_draw_berry_bush(center)
	elif kind == GameMap.LANDMARK_RUINS:
		_draw_ruins(center)
	elif kind == GameMap.LANDMARK_CACHE:
		_draw_cache(center)


func _draw_berry_bush(center: Vector2) -> void:
	var leaf_color := Color(0.18, 0.44, 0.22)
	for offset in [Vector2(-0.12, 0.06), Vector2(0.0, -0.04), Vector2(0.12, 0.06)]:
		draw_circle(center + offset * tile_size, tile_size * 0.105, leaf_color)
	for offset in [Vector2(-0.05, 0.00), Vector2(0.06, -0.03), Vector2(0.08, 0.08)]:
		draw_circle(center + offset * tile_size, tile_size * 0.022, Color(0.67, 0.10, 0.18))


func _draw_ruins(center: Vector2) -> void:
	var stone := Color(0.48, 0.49, 0.45)
	var shadow := Color(0.24, 0.25, 0.23, 0.5)
	draw_rect(Rect2(center + Vector2(-0.22, -0.03) * tile_size, Vector2(0.44, 0.09) * tile_size), shadow, true)
	draw_rect(Rect2(center + Vector2(-0.20, -0.22) * tile_size, Vector2(0.10, 0.30) * tile_size), stone, true)
	draw_rect(Rect2(center + Vector2(0.09, -0.17) * tile_size, Vector2(0.10, 0.25) * tile_size), stone.lightened(0.08), true)
	draw_rect(Rect2(center + Vector2(-0.22, 0.07) * tile_size, Vector2(0.46, 0.08) * tile_size), stone.darkened(0.10), true)


func _draw_cache(center: Vector2) -> void:
	var box_rect := Rect2(center + Vector2(-0.16, -0.10) * tile_size, Vector2(0.32, 0.22) * tile_size)
	draw_rect(box_rect, Color(0.48, 0.27, 0.12), true)
	draw_rect(box_rect, Color(0.20, 0.12, 0.06), false, 2.0)
	draw_line(box_rect.position + Vector2(0.0, box_rect.size.y * 0.45), box_rect.position + Vector2(box_rect.size.x, box_rect.size.y * 0.45), Color(0.88, 0.67, 0.28), 2.0)


func _refresh_enemy_view() -> void:
	if _enemy_view == null:
		return
	_enemy_view.set("tile_size", tile_size)
	_enemy_view.set("enemy_data", enemy_data)
	_enemy_view.position = enemy_offset
