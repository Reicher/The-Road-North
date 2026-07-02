## Validates tile placement and targeting for the PlacementController.
## Extracts validation logic into a focused, testable class.
class_name PlacementValidator
extends RefCounted

const HINT_TOO_FAR := "Too far away"
const HINT_STANDING_HERE := "You're standing here"
const HINT_OCCUPIED := "Tile already occupied"
const HINT_CANT_TARGET := "Can't target this tile"
const HINT_TERRAIN_BLOCKS := "Terrain blocks placement"
const HINT_ROAD_OFF_MAP := "Road leads off map"
const HINT_CONNECT_TO_PLAYER := "Connect to your tile"
const HINT_ROAD_DOESNT_FIT := "Road doesn't fit"
const HINT_NO_TILE := "No tile to target"
const HINT_NO_ENCOUNTER := "No encounter here"
const HINT_HAS_ENCOUNTER := "Road already has an encounter"
const HINT_NO_VALID_ROTATION := "No other playable rotation"

var _map: GameMap
var _player: GamePlayer
var _sight_func: Callable


func setup(map: GameMap, player: GamePlayer, sight_func: Callable) -> void:
	_map = map
	_player = player
	_sight_func = sight_func


func get_road_placement_hint(grid_position: Vector2i, connections: Dictionary, placeable_on_river: bool = false) -> String:
	if _is_too_far_away(grid_position):
		return HINT_TOO_FAR
	if grid_position == _player.grid_position:
		return HINT_STANDING_HERE
	if _map.get_tile(grid_position) != null:
		return HINT_OCCUPIED
	if not _map.can_build_on_fixed_feature(grid_position):
		if not placeable_on_river or not _is_river_feature(grid_position):
			return HINT_TERRAIN_BLOCKS
	if _road_leads_off_map(grid_position, connections):
		return HINT_ROAD_OFF_MAP
	if _road_mismatches_player_tile(grid_position, connections):
		return HINT_CONNECT_TO_PLAYER
	if not _map.can_place_tile(grid_position, connections, placeable_on_river):
		return HINT_ROAD_DOESNT_FIT
	return ""


func get_invalid_road_connections(grid_position: Vector2i, connections: Dictionary) -> Array[String]:
	var invalid_directions: Array[String] = []
	if not _map.is_inside_playable_area(grid_position):
		return invalid_directions

	for direction_name in GameConstants.DIRECTIONS:
		var neighbor_position: Vector2i = grid_position + GameConstants.DIRECTIONS[direction_name]
		var opens_to_neighbor: bool = connections.get(direction_name, false) == true
		if not _map.is_inside_playable_area(neighbor_position):
			if opens_to_neighbor:
				invalid_directions.append(direction_name)
			continue

		var opposite: String = GameConstants.OPPOSITE_DIRECTIONS[direction_name]
		var feature_connections := _map.get_fixed_feature_connections(neighbor_position)
		if not feature_connections.is_empty():
			if opens_to_neighbor != (feature_connections.get(opposite, false) == true):
				invalid_directions.append(direction_name)
			continue

		if opens_to_neighbor and not _map.can_build_on_fixed_feature(neighbor_position):
			var feature_type := str(_map.get_fixed_feature(neighbor_position).get("type", ""))
			if feature_type != GameConstants.FEATURE_RIVER:
				invalid_directions.append(direction_name)
			continue

		var neighbor: Variant = _map.get_tile(neighbor_position)
		if neighbor is Dictionary:
			var neighbor_connections: Dictionary = neighbor.get("connections", {})
			if opens_to_neighbor != (neighbor_connections.get(opposite, false) == true):
				invalid_directions.append(direction_name)

	return invalid_directions


func get_tile_target_hint(grid_position: Vector2i, event_type: String) -> String:
	if _is_too_far_away(grid_position):
		return HINT_TOO_FAR
	if grid_position == _player.grid_position:
		return HINT_STANDING_HERE
	if grid_position == _map.get_start_position() or grid_position == _map.get_goal_position():
		return HINT_CANT_TARGET
	if _map.get_tile(grid_position) == null:
		return HINT_NO_TILE
	if event_type == GameConstants.EVENT_ROTATE_TILE and get_valid_alternative_rotations(grid_position).is_empty():
		return HINT_NO_VALID_ROTATION
	if event_type in GameConstants.ENCOUNTER_EVENT_TYPES:
		var encounter := _map.get_encounter(grid_position)
		if event_type == GameConstants.EVENT_CLEAR_PATH and encounter.is_empty():
			return HINT_NO_ENCOUNTER
		if event_type != GameConstants.EVENT_CLEAR_PATH and not encounter.is_empty():
			return HINT_HAS_ENCOUNTER
	return ""


func is_valid_destroy_target(grid_position: Vector2i) -> bool:
	if not _is_in_sight(grid_position):
		return false
	if _map.get_tile(grid_position) == null:
		return false
	if grid_position == _map.get_start_position() or grid_position == _map.get_goal_position():
		return false
	if grid_position == _player.grid_position:
		return false
	return true


func is_valid_rotate_target(grid_position: Vector2i) -> bool:
	if not is_valid_destroy_target(grid_position):
		return false
	var tile_data: Variant = _map.get_tile(grid_position)
	return tile_data is Dictionary and tile_data.get("definition") != null and not get_valid_alternative_rotations(grid_position).is_empty()


func get_valid_alternative_rotations(grid_position: Vector2i) -> Array[int]:
	var result: Array[int] = []
	var tile_data: Variant = _map.get_tile(grid_position)
	if not (tile_data is Dictionary):
		return result
	var definition: Resource = tile_data.get("definition")
	if definition == null or not definition.has_method("get_rotated_openings"):
		return result
	var original_rotation := posmod(int(tile_data.get("rotation_steps", 0)), 4)
	var seen_connections: Dictionary = {
		_connection_signature(definition.get_rotated_openings(original_rotation)): true,
	}
	for rotation in 4:
		if rotation == original_rotation:
			continue
		var connections: Dictionary = definition.get_rotated_openings(rotation)
		var signature := _connection_signature(connections)
		if seen_connections.has(signature):
			continue
		seen_connections[signature] = true
		if _rotation_fits(grid_position, connections):
			result.append(rotation)
	return result


func _rotation_fits(grid_position: Vector2i, connections: Dictionary) -> bool:
	if _road_leads_off_map(grid_position, connections) or _road_mismatches_player_tile(grid_position, connections):
		return false
	for direction_name in GameConstants.DIRECTIONS:
		var neighbor_position: Vector2i = grid_position + GameConstants.DIRECTIONS[direction_name]
		if not _map.is_inside_playable_area(neighbor_position):
			continue
		var opens_to_neighbor: bool = connections.get(direction_name, false) == true
		var opposite: String = GameConstants.OPPOSITE_DIRECTIONS[direction_name]
		var feature_connections := _map.get_fixed_feature_connections(neighbor_position)
		if not feature_connections.is_empty():
			if opens_to_neighbor != (feature_connections.get(opposite, false) == true):
				return false
			continue
		if opens_to_neighbor and not _map.can_build_on_fixed_feature(neighbor_position):
			if str(_map.get_fixed_feature(neighbor_position).get("type", "")) != GameConstants.FEATURE_RIVER:
				return false
		var neighbor: Variant = _map.get_tile(neighbor_position)
		if neighbor is Dictionary:
			var neighbor_connections: Dictionary = neighbor.get("connections", {})
			if opens_to_neighbor != (neighbor_connections.get(opposite, false) == true):
				return false
	return true


func _connection_signature(connections: Dictionary) -> String:
	return "%s%s%s%s" % [connections.get("north", false), connections.get("east", false), connections.get("south", false), connections.get("west", false)]


func is_valid_encounter_target(grid_position: Vector2i, event_type: String) -> bool:
	if not is_valid_destroy_target(grid_position):
		return false
	var encounter := _map.get_encounter(grid_position)
	if event_type == GameConstants.EVENT_CLEAR_PATH:
		return not encounter.is_empty()
	return encounter.is_empty()


func _is_in_sight(grid_position: Vector2i) -> bool:
	var delta: Vector2i = grid_position - _player.grid_position
	var distance: int = maxi(absi(delta.x), absi(delta.y))
	return distance > 0 and distance <= _sight_func.call()


func _is_too_far_away(grid_position: Vector2i) -> bool:
	var delta: Vector2i = grid_position - _player.grid_position
	return maxi(absi(delta.x), absi(delta.y)) > _sight_func.call()


func _road_leads_off_map(grid_position: Vector2i, connections: Dictionary) -> bool:
	for direction_name in GameConstants.DIRECTIONS:
		if connections.get(direction_name, false) != true:
			continue
		var direction: Vector2i = GameConstants.DIRECTIONS[direction_name]
		if not _map.is_inside_playable_area(grid_position + direction):
			return true
	return false


func _road_mismatches_player_tile(grid_position: Vector2i, connections: Dictionary) -> bool:
	var delta: Vector2i = _player.grid_position - grid_position
	if absi(delta.x) + absi(delta.y) != 1:
		return false
	var direction_name := _direction_name_for_delta(delta)
	var opposite_direction: String = GameConstants.OPPOSITE_DIRECTIONS[direction_name]
	var player_tile: Variant = _map.get_tile(_player.grid_position)
	if not (player_tile is Dictionary):
		return false
	var player_connections: Dictionary = player_tile.get("connections", {})
	var opens_to_player: bool = connections.get(direction_name, false) == true
	var player_opens_back: bool = player_connections.get(opposite_direction, false) == true
	return opens_to_player != player_opens_back


func _is_river_feature(grid_position: Vector2i) -> bool:
	var feature := _map.get_fixed_feature(grid_position)
	return str(feature.get("type", "")) == GameConstants.FEATURE_RIVER


static func _direction_name_for_delta(delta: Vector2i) -> String:
	for direction_name in GameConstants.DIRECTIONS:
		if GameConstants.DIRECTIONS[direction_name] == delta:
			return direction_name
	return ""
