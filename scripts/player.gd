class_name GamePlayer
extends Node2D

signal food_changed(food: int)
signal moved(grid_position: Vector2i)
signal move_blocked(target_position: Vector2i, reason: String)

@export var map_path: NodePath
@export var food_label_path: NodePath
@export var start_position := Vector2i(-1, -1)
@export var starting_food := -1
@export_range(0.0, 1.0, 0.01) var move_duration := 0.16
@export var pawn_color := Color(0.93, 0.56, 0.25)
@export var pawn_shadow_color := Color(0.18, 0.16, 0.14, 0.32)

var grid_position := Vector2i.ZERO
var food := 0

var _map: GameMap
var _food_label: Label
var _moving := false
var _move_target := Vector2i.ZERO


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_food_label = get_node_or_null(food_label_path) as Label

	if _map == null:
		push_warning("Player needs a GameMap at map_path.")
		return

	if start_position.x < 0 or start_position.y < 0:
		start_position = Vector2i(_map.playable_width / 2, _map.playable_height - 1)

	grid_position = start_position
	position = _map.grid_to_world(grid_position)
	food = starting_food if starting_food >= 0 else _map.playable_width * 3
	_update_food_label()

	if not _map.tile_pressed.is_connected(_on_tile_pressed):
		_map.tile_pressed.connect(_on_tile_pressed)

	queue_redraw()


func _draw() -> void:
	var tile_size := 64.0
	if _map != null:
		tile_size = _map.tile_size

	var radius := tile_size * 0.18
	draw_circle(Vector2(0.0, radius * 0.55), radius * 0.9, pawn_shadow_color)
	draw_circle(Vector2.ZERO, radius, pawn_color)
	draw_circle(Vector2(0.0, -radius * 0.38), radius * 0.42, pawn_color.lightened(0.18))


func can_move_to(target_position: Vector2i) -> bool:
	if _map == null or _moving or food <= 0:
		return false
	return _map.can_move_between(grid_position, target_position)


func move_to(target_position: Vector2i) -> bool:
	if _map == null:
		move_blocked.emit(target_position, "missing_map")
		return false
	if _moving:
		move_blocked.emit(target_position, "moving")
		return false
	if food <= 0:
		move_blocked.emit(target_position, "no_food")
		return false
	if not _map.can_move_between(grid_position, target_position):
		move_blocked.emit(target_position, "invalid_road")
		return false

	_moving = true
	food -= 1
	_update_food_label()
	food_changed.emit(food)

	var target_world_position := _map.grid_to_world(target_position)
	if move_duration <= 0.0:
		position = target_world_position
		_finish_move(target_position)
		return true

	_move_target = target_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_world_position, move_duration)
	tween.finished.connect(_on_move_tween_finished)
	return true


func is_moving() -> bool:
	return _moving


func _on_tile_pressed(target_position: Vector2i) -> void:
	move_to(target_position)


func _finish_move(target_position: Vector2i) -> void:
	grid_position = target_position
	_moving = false
	moved.emit(grid_position)


func _on_move_tween_finished() -> void:
	_finish_move(_move_target)


func _update_food_label() -> void:
	if _food_label != null:
		_food_label.text = "Food: %d" % food
