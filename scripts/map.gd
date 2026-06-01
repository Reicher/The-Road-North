class_name GameMap
extends Node3D

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
const ENCOUNTER_CACHE := "cache"
const FEATURE_MOUNTAIN := "mountain"
const FEATURE_RIVER := "river"
const FEATURE_BRIDGE := "bridge"

@export_range(1, 64, 1) var playable_width := 9:
	set(value):
		playable_width = value
		_rebuild_fixed_feature_lookup()
		_rebuild_visuals()

@export_range(1, 64, 1) var playable_height := 9:
	set(value):
		playable_height = value
		_rebuild_fixed_feature_lookup()
		_rebuild_visuals()

@export_range(16.0, 256.0, 1.0) var tile_size := 96.0:
	set(value):
		tile_size = value
		_rebuild_visuals()

@export var fixed_features: Array[Dictionary] = []:
	set(value):
		fixed_features = value
		_rebuild_fixed_feature_lookup()
		_rebuild_visuals()

var tiles: Dictionary = {}
var _fixed_features_by_position: Dictionary = {}
var _visuals: Node


func _ready() -> void:
	set_process_unhandled_input(true)
	_resolve_visuals()
	_rebuild_fixed_feature_lookup()
	_rebuild_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_screen_press(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_screen_press(event.position)


func _handle_screen_press(screen_position: Vector2) -> void:
	var grid_position := screen_to_grid(screen_position)
	if is_inside_playable_area(grid_position):
		tile_pressed.emit(grid_position)


func screen_to_grid(screen_position: Vector2) -> Vector2i:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2i(-1, -1)
	var camera := viewport.get_camera_3d()
	if camera == null:
		return Vector2i(-1, -1)
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return Vector2i(-1, -1)
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return Vector2i(-1, -1)
	return world_to_grid(origin + direction * distance)


func grid_to_screen_position(grid_position: Vector2i) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return grid_to_world_2d(grid_position)
	var camera := viewport.get_camera_3d()
	if camera == null:
		return grid_to_world_2d(grid_position)
	return camera.unproject_position(grid_to_world(grid_position))


func get_tile(grid_position: Vector2i) -> Variant:
	return tiles.get(grid_position)


func set_tile(grid_position: Vector2i, tile_data: Variant) -> bool:
	if not is_inside_playable_area(grid_position):
		return false
	tiles[grid_position] = tile_data
	_rebuild_cell_visual(grid_position)
	return true


func clear_tile(grid_position: Vector2i) -> void:
	tiles.erase(grid_position)
	_rebuild_cell_visual(grid_position)


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


func clear_encounter(grid_position: Vector2i) -> void:
	var tile_data: Variant = get_tile(grid_position)
	if tile_data is Dictionary and tile_data.has("encounter"):
		tile_data.erase("encounter")
		tiles[grid_position] = tile_data


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


func world_to_grid(world_position: Variant) -> Vector2i:
	if world_position is Vector3:
		return Vector2i(floori(world_position.x / tile_size), floori(world_position.z / tile_size))
	if world_position is Vector2:
		return Vector2i(floori(world_position.x / tile_size), floori(world_position.y / tile_size))
	return Vector2i(-1, -1)


func grid_to_world(grid_position: Vector2i) -> Vector3:
	return Vector3(float(grid_position.x) + 0.5, 0.0, float(grid_position.y) + 0.5) * tile_size


func grid_to_world_2d(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position) * tile_size + Vector2.ONE * tile_size * 0.5


func get_playable_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(playable_width, playable_height) * tile_size)


func get_padded_world_rect() -> Rect2:
	return get_playable_world_rect()


func get_fixed_feature_connections(grid_position: Vector2i) -> Dictionary:
	var feature := get_fixed_feature(grid_position)
	if feature.is_empty() or str(feature.get("type", "")) != FEATURE_BRIDGE:
		return {}
	var custom_connections: Variant = feature.get("connections", null)
	if custom_connections is Dictionary:
		return custom_connections

	var horizontal_river := posmod(int(feature.get("rotation_steps", 0)), 2) == 0
	if horizontal_river:
		return {"north": true, "east": false, "south": true, "west": false}
	return {"north": false, "east": true, "south": false, "west": true}


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


func _rebuild_fixed_feature_lookup() -> void:
	_fixed_features_by_position.clear()
	for feature in fixed_features:
		var grid_position: Vector2i = feature.get("position", Vector2i(-1, -1))
		if is_inside_playable_area(grid_position):
			_fixed_features_by_position[grid_position] = feature


func _rebuild_visuals() -> void:
	if not is_inside_tree():
		return
	if not _resolve_visuals():
		return
	_visuals.rebuild_all(self)


func _rebuild_cell_visual(grid_position: Vector2i) -> void:
	if not is_inside_tree():
		return
	if not _resolve_visuals():
		return
	_visuals.rebuild_cell(self, grid_position)


func _resolve_visuals() -> bool:
	_visuals = get_node_or_null("MapVisuals")
	if _visuals == null:
		push_warning("GameMap needs a MapVisuals child.")
		return false
	return true
