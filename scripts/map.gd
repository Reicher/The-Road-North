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

const ENCOUNTER_ENEMY := "enemy"
const ENCOUNTER_BERRY_BUSH := "berry_bush"
const ENCOUNTER_RUINS := "ruins"
const ENCOUNTER_CACHE := "cache"
const FEATURE_MOUNTAIN := "mountain"
const FEATURE_RIVER := "river"
const FEATURE_BRIDGE := "bridge"

@export_range(1, 64, 1) var playable_width := 9:
	set(value):
		playable_width = value
		_rebuild_fixed_feature_lookup()
		queue_redraw()

@export_range(1, 64, 1) var playable_height := 9:
	set(value):
		playable_height = value
		_rebuild_fixed_feature_lookup()
		queue_redraw()

@export_range(16.0, 256.0, 1.0) var tile_size := 96.0:
	set(value):
		tile_size = value
		queue_redraw()

@export var fixed_features: Array[Dictionary] = []:
	set(value):
		fixed_features = value
		_rebuild_fixed_feature_lookup()
		queue_redraw()

var tiles: Dictionary = {}
var _fixed_features_by_position: Dictionary = {}


func _ready() -> void:
	set_process_unhandled_input(true)
	_rebuild_fixed_feature_lookup()
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

	for feature in fixed_features:
		_draw_fixed_feature(feature)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_world_press(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		_handle_world_press(get_global_transform_with_canvas().affine_inverse() * event.position)


func _handle_world_press(world_position: Vector2) -> void:
	var grid_position: Vector2i = world_to_grid(world_position)
	if is_inside_playable_area(grid_position):
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


func get_fixed_feature(grid_position: Vector2i) -> Dictionary:
	var feature: Variant = _fixed_features_by_position.get(grid_position, {})
	if feature is Dictionary:
		return feature
	return {}


func can_build_on_fixed_feature(grid_position: Vector2i) -> bool:
	return get_fixed_feature(grid_position).is_empty()


func get_encounter(grid_position: Vector2i) -> Dictionary:
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary:
		var encounter: Variant = tile_data.get("encounter", {})
		if encounter is Dictionary:
			return encounter
	return {}


func consume_encounter(grid_position: Vector2i) -> Dictionary:
	var encounter := get_encounter(grid_position).duplicate(true)
	if encounter.is_empty():
		return {}
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary:
		tile_data.erase("encounter")
		tiles[grid_position] = tile_data
	queue_redraw()
	return encounter


func get_start_position() -> Vector2i:
	return Vector2i(playable_width / 2, playable_height - 1)


func get_goal_position() -> Vector2i:
	return Vector2i(playable_width / 2, 0)


func can_place_tile(grid_position: Vector2i, connections: Dictionary = {}) -> bool:
	if not is_inside_playable_area(grid_position):
		return false
	if tiles.has(grid_position):
		return false
	if not can_build_on_fixed_feature(grid_position):
		return false

	for direction_name in DIRECTIONS:
		var direction: Vector2i = DIRECTIONS.get(direction_name, Vector2i.ZERO) as Vector2i
		var neighbor_position: Vector2i = grid_position + direction
		var opens_to_neighbor: bool = connections.get(direction_name, false) == true

		if opens_to_neighbor and not is_inside_playable_area(neighbor_position):
			return false

		if not is_inside_playable_area(neighbor_position):
			continue

		var neighbor_feature_connections := get_fixed_feature_connections(neighbor_position)
		if not neighbor_feature_connections.is_empty():
			var opposite_direction: String = OPPOSITE_DIRECTIONS[direction_name]
			var feature_opens_back: bool = neighbor_feature_connections.get(opposite_direction, false) == true
			if opens_to_neighbor != feature_opens_back:
				return false
			continue

		if opens_to_neighbor and not can_build_on_fixed_feature(neighbor_position):
			return false

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

	if not _position_has_opening(from_position, direction_name):
		return false

	return _position_has_opening(to_position, OPPOSITE_DIRECTIONS[direction_name])


func update_encounter_data(grid_position: Vector2i, encounter_data: Dictionary) -> void:
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary:
		tile_data["encounter"] = encounter_data.duplicate(true)
		tiles[grid_position] = tile_data
	queue_redraw()


func clear_encounter(grid_position: Vector2i) -> void:
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary and tile_data.has("encounter"):
		tile_data.erase("encounter")
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


func _position_has_opening(grid_position: Vector2i, direction_name: String) -> bool:
	var tile_data: Variant = get_tile(grid_position)
	if tile_data != null:
		return _tile_has_opening(tile_data, direction_name)

	var feature_connections := get_fixed_feature_connections(grid_position)
	return feature_connections.get(direction_name, false) == true


func get_fixed_feature_connections(grid_position: Vector2i) -> Dictionary:
	var feature := get_fixed_feature(grid_position)
	if feature.is_empty() or str(feature.get("type", "")) != FEATURE_BRIDGE:
		return {}
	var custom_connections: Variant = feature.get("connections", null)
	if custom_connections is Dictionary:
		return custom_connections

	var horizontal_river := posmod(int(feature.get("rotation_steps", 0)), 2) == 0
	if horizontal_river:
		return {
			"north": true,
			"east": false,
			"south": true,
			"west": false,
		}
	return {
		"north": false,
		"east": true,
		"south": false,
		"west": true,
	}


func _rebuild_fixed_feature_lookup() -> void:
	_fixed_features_by_position.clear()
	for feature in fixed_features:
		var grid_position: Vector2i = feature.get("position", Vector2i(-1, -1))
		if is_inside_playable_area(grid_position):
			_fixed_features_by_position[grid_position] = feature


func _draw_fixed_feature(feature: Dictionary) -> void:
	var grid_position: Vector2i = feature.get("position", Vector2i(-1, -1))
	if not is_inside_playable_area(grid_position):
		return

	var feature_type := str(feature.get("type", ""))
	var tile_rect := Rect2(grid_to_world(grid_position) - Vector2.ONE * tile_size * 0.5, Vector2.ONE * tile_size).grow(-2.0)
	if feature_type == FEATURE_MOUNTAIN:
		_draw_mountain_feature(tile_rect)
	elif feature_type == FEATURE_RIVER:
		_draw_river_feature(tile_rect, int(feature.get("rotation_steps", 0)))
	elif feature_type == FEATURE_BRIDGE:
		_draw_river_feature(tile_rect, int(feature.get("rotation_steps", 0)))
		_draw_bridge_feature(tile_rect, int(feature.get("rotation_steps", 0)))


func _draw_mountain_feature(tile_rect: Rect2) -> void:
	var base_y := tile_rect.position.y + tile_rect.size.y * 0.78
	var peak := Vector2(tile_rect.get_center().x, tile_rect.position.y + tile_rect.size.y * 0.16)
	var left := Vector2(tile_rect.position.x + tile_rect.size.x * 0.14, base_y)
	var right := Vector2(tile_rect.end.x - tile_rect.size.x * 0.12, base_y)
	draw_colored_polygon(PackedVector2Array([left, peak, right]), Color(0.42, 0.43, 0.39))
	draw_colored_polygon(PackedVector2Array([
		peak,
		Vector2(tile_rect.get_center().x - tile_rect.size.x * 0.10, tile_rect.position.y + tile_rect.size.y * 0.38),
		Vector2(tile_rect.get_center().x + tile_rect.size.x * 0.10, tile_rect.position.y + tile_rect.size.y * 0.38),
	]), Color(0.82, 0.84, 0.78))
	draw_line(left, peak, Color(0.25, 0.26, 0.24), 2.0)
	draw_line(peak, right, Color(0.25, 0.26, 0.24), 2.0)


func _draw_river_feature(tile_rect: Rect2, rotation_steps: int) -> void:
	var horizontal := posmod(rotation_steps, 2) == 0
	var water_color := Color(0.23, 0.48, 0.68)
	var light_color := Color(0.52, 0.73, 0.83, 0.75)
	if horizontal:
		var river_rect := Rect2(Vector2(tile_rect.position.x, tile_rect.get_center().y - tile_rect.size.y * 0.18), Vector2(tile_rect.size.x, tile_rect.size.y * 0.36))
		draw_rect(river_rect, water_color, true)
		draw_line(river_rect.position + Vector2(0.0, river_rect.size.y * 0.32), river_rect.position + Vector2(river_rect.size.x, river_rect.size.y * 0.18), light_color, 2.0)
	else:
		var river_rect := Rect2(Vector2(tile_rect.get_center().x - tile_rect.size.x * 0.18, tile_rect.position.y), Vector2(tile_rect.size.x * 0.36, tile_rect.size.y))
		draw_rect(river_rect, water_color, true)
		draw_line(river_rect.position + Vector2(river_rect.size.x * 0.30, 0.0), river_rect.position + Vector2(river_rect.size.x * 0.18, river_rect.size.y), light_color, 2.0)


func _draw_bridge_feature(tile_rect: Rect2, rotation_steps: int) -> void:
	var horizontal_river := posmod(rotation_steps, 2) == 0
	var plank_color := Color(0.55, 0.36, 0.18)
	var edge_color := Color(0.27, 0.17, 0.08)
	if horizontal_river:
		var bridge_rect := Rect2(Vector2(tile_rect.get_center().x - tile_rect.size.x * 0.18, tile_rect.position.y + tile_rect.size.y * 0.12), Vector2(tile_rect.size.x * 0.36, tile_rect.size.y * 0.76))
		draw_rect(bridge_rect, plank_color, true)
		draw_rect(bridge_rect, edge_color, false, 2.0)
		draw_line(Vector2(bridge_rect.position.x, bridge_rect.get_center().y), Vector2(bridge_rect.end.x, bridge_rect.get_center().y), edge_color, 1.5)
	else:
		var bridge_rect := Rect2(Vector2(tile_rect.position.x + tile_rect.size.x * 0.12, tile_rect.get_center().y - tile_rect.size.y * 0.18), Vector2(tile_rect.size.x * 0.76, tile_rect.size.y * 0.36))
		draw_rect(bridge_rect, plank_color, true)
		draw_rect(bridge_rect, edge_color, false, 2.0)
		draw_line(Vector2(bridge_rect.get_center().x, bridge_rect.position.y), Vector2(bridge_rect.get_center().x, bridge_rect.end.y), edge_color, 1.5)
