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

var _map: GameMap
var _player: GamePlayer
var _target_range_func: Callable


func setup(map: GameMap, player: GamePlayer, target_range_func: Callable) -> void:
	_map = map
	_player = player
	_target_range_func = target_range_func


func get_road_placement_hint(grid_position: Vector2i, connections: Dictionary) -> String:
	if _is_too_far_away(grid_position):
		return HINT_TOO_FAR
	if grid_position == _player.grid_position:
		return HINT_STANDING_HERE
	if _map.get_tile(grid_position) != null:
		return HINT_OCCUPIED
	if not _map.can_build_on_fixed_feature(grid_position):
		return HINT_TERRAIN_BLOCKS
	if _road_leads_off_map(grid_position, connections):
		return HINT_ROAD_OFF_MAP
	if _road_mismatches_player_tile(grid_position, connections):
		return HINT_CONNECT_TO_PLAYER
	if not _map.can_place_tile(grid_position, connections):
		return HINT_ROAD_DOESNT_FIT
	return ""


func get_tile_target_hint(grid_position: Vector2i, event_type: String) -> String:
	if _is_too_far_away(grid_position):
		return HINT_TOO_FAR
	if grid_position == _player.grid_position:
		return HINT_STANDING_HERE
	if grid_position == _map.get_start_position() or grid_position == _map.get_goal_position():
		return HINT_CANT_TARGET
	if _map.get_tile(grid_position) == null:
		return HINT_NO_TILE
	if event_type in GameConstants.ENCOUNTER_EVENT_TYPES:
		var encounter := _map.get_encounter(grid_position)
		if event_type == GameConstants.EVENT_CLEAR_PATH and encounter.is_empty():
			return HINT_NO_ENCOUNTER
		if event_type != GameConstants.EVENT_CLEAR_PATH and not encounter.is_empty():
			return HINT_HAS_ENCOUNTER
	return ""


func is_valid_destroy_target(grid_position: Vector2i) -> bool:
	if not _is_in_target_range(grid_position):
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
	return tile_data is Dictionary and tile_data.get("definition") != null


func is_valid_encounter_target(grid_position: Vector2i, event_type: String) -> bool:
	if not is_valid_destroy_target(grid_position):
		return false
	var encounter := _map.get_encounter(grid_position)
	if event_type == GameConstants.EVENT_CLEAR_PATH:
		return not encounter.is_empty()
	return encounter.is_empty()


func _is_in_target_range(grid_position: Vector2i) -> bool:
	var delta: Vector2i = grid_position - _player.grid_position
	var distance: int = absi(delta.x) + absi(delta.y)
	return distance > 0 and distance <= _target_range_func.call()


func _is_too_far_away(grid_position: Vector2i) -> bool:
	var delta: Vector2i = grid_position - _player.grid_position
	return absi(delta.x) + absi(delta.y) > _target_range_func.call()


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


static func _direction_name_for_delta(delta: Vector2i) -> String:
	for direction_name in GameConstants.DIRECTIONS:
		if GameConstants.DIRECTIONS[direction_name] == delta:
			return direction_name
	return ""
