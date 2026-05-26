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


func _refresh_enemy_view() -> void:
	if _enemy_view == null:
		return
	_enemy_view.set("tile_size", tile_size)
	_enemy_view.set("enemy_data", enemy_data)
	_enemy_view.position = enemy_offset
