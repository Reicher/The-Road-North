class_name GameMap
extends Node2D

signal tile_pressed(grid_position: Vector2i)

const DIRECTIONS: Dictionary = {
	"north": Vector2i(0, -1),
	"east": Vector2i(1, 0),
	"south": Vector2i(0, 1),
	"west": Vector2i(-1, 0),
}

const OPPOSITE_DIRECTIONS: Dictionary = {
	"north": "south",
	"east": "west",
	"south": "north",
	"west": "east",
}

const LANDMARK_BERRY_BUSH := "berry_bush"
const LANDMARK_RUINS := "ruins"
const LANDMARK_CACHE := "cache"

@export_range(1, 64, 1) var playable_width := 9:
	set(value):
		playable_width = value
		queue_redraw()

@export_range(1, 64, 1) var playable_height := 9:
	set(value):
		playable_height = value
		queue_redraw()

@export_range(16.0, 256.0, 1.0) var tile_size := 96.0:
	set(value):
		tile_size = value
		queue_redraw()

var tiles: Dictionary = {}


func _ready() -> void:
	set_process_unhandled_input(true)
	queue_redraw()


func _draw() -> void:
	var padded_rect: Rect2 = get_padded_world_rect()
	draw_rect(padded_rect, Color(0.40, 0.55, 0.43), true)

	for y in playable_height:
		for x in playable_width:
			var grid_position := Vector2i(x, y)
			var tile_rect := Rect2(grid_to_world(grid_position) - Vector2.ONE * tile_size * 0.5, Vector2.ONE * tile_size).grow(-2.0)
			var tint := Color(0.69, 0.76, 0.57)
			if (x + y) % 2 == 1:
				tint = Color(0.64, 0.72, 0.53)
			draw_rect(tile_rect, tint, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_world_press(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		_handle_world_press(get_global_transform_with_canvas().affine_inverse() * event.position)


func _handle_world_press(world_position: Vector2) -> void:
	var grid_position: Vector2i = world_to_grid(world_position)
	if is_inside_playable_area(grid_position):
		print("Tile pressed: ", grid_position)
		tile_pressed.emit(grid_position)


func get_tile(grid_position: Vector2i) -> Variant:
	return tiles.get(grid_position)


func set_tile(grid_position: Vector2i, tile_data: Variant) -> bool:
	if not is_inside_playable_area(grid_position):
		return false
	tiles[grid_position] = tile_data
	return true


func clear_tile(grid_position: Vector2i) -> void:
	tiles.erase(grid_position)


func get_landmark(grid_position: Vector2i) -> Dictionary:
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary:
		var landmark: Variant = tile_data.get("landmark", {})
		if landmark is Dictionary:
			return landmark
	return {}


func consume_landmark(grid_position: Vector2i) -> Dictionary:
	var landmark := get_landmark(grid_position).duplicate(true)
	if landmark.is_empty():
		return {}
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary:
		tile_data.erase("landmark")
		tiles[grid_position] = tile_data
	queue_redraw()
	return landmark


func get_start_position() -> Vector2i:
	return Vector2i(playable_width / 2, playable_height - 1)


func get_goal_position() -> Vector2i:
	return Vector2i(playable_width / 2, 0)


func can_place_tile(grid_position: Vector2i, connections: Dictionary = {}) -> bool:
	if not is_inside_playable_area(grid_position):
		return false
	if tiles.has(grid_position):
		return false

	for direction_name in DIRECTIONS:
		var direction: Vector2i = DIRECTIONS.get(direction_name, Vector2i.ZERO) as Vector2i
		var neighbor_position: Vector2i = grid_position + direction
		var opens_to_neighbor: bool = connections.get(direction_name, false) == true

		if opens_to_neighbor and not is_inside_playable_area(neighbor_position):
			return false

		if not is_inside_playable_area(neighbor_position):
			continue

		var neighbor_tile: Variant = get_tile(neighbor_position)
		if neighbor_tile == null:
			continue

		var opposite_direction: String = OPPOSITE_DIRECTIONS[direction_name]
		var neighbor_opens_back: bool = _tile_has_opening(neighbor_tile, opposite_direction)
		if opens_to_neighbor != neighbor_opens_back:
			return false

	return true


func can_move_between(from_position: Vector2i, to_position: Vector2i) -> bool:
	var delta: Vector2i = to_position - from_position
	if abs(delta.x) + abs(delta.y) != 1:
		return false
	if not is_inside_playable_area(from_position) or not is_inside_playable_area(to_position):
		return false

	var direction_name: String = _direction_name_for_delta(delta)
	if direction_name.is_empty():
		return false

	var from_tile: Variant = get_tile(from_position)
	var to_tile: Variant = get_tile(to_position)
	if not _tile_has_opening(from_tile, direction_name):
		return false

	return _tile_has_opening(to_tile, OPPOSITE_DIRECTIONS[direction_name])


func update_enemy_data(grid_position: Vector2i, enemy_data: Dictionary) -> void:
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary:
		tile_data["enemy"] = enemy_data.duplicate(true)
		tiles[grid_position] = tile_data
	queue_redraw()


func clear_enemy(grid_position: Vector2i) -> void:
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary and tile_data.has("enemy"):
		tile_data.erase("enemy")
		tiles[grid_position] = tile_data
	queue_redraw()


func get_neighbors(grid_position: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction_name in DIRECTIONS:
		var direction: Vector2i = DIRECTIONS[direction_name]
		var neighbor: Vector2i = grid_position + direction
		if is_inside_playable_area(neighbor):
			neighbors.append(neighbor)
	return neighbors


func is_inside_playable_area(grid_position: Vector2i) -> bool:
	return grid_position.x >= 0 and grid_position.x < playable_width and grid_position.y >= 0 and grid_position.y < playable_height


func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / tile_size), floori(world_position.y / tile_size))


func grid_to_world(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position) * tile_size + Vector2.ONE * tile_size * 0.5


func get_playable_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(playable_width, playable_height) * tile_size)


func get_padded_world_rect() -> Rect2:
	return get_playable_world_rect()


func _direction_name_for_delta(delta: Vector2i) -> String:
	for direction_name in DIRECTIONS:
		if DIRECTIONS[direction_name] == delta:
			return direction_name
	return ""


func _tile_has_opening(tile_data: Variant, direction_name: String) -> bool:
	if tile_data == null:
		return false
	if tile_data is Dictionary:
		var connections: Dictionary = tile_data.get("connections", tile_data)
		return connections.get(direction_name, false) == true
	return false

