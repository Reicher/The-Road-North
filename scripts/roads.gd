class_name Roads
extends Node2D

@export var map_path: NodePath
@export var tile_scene: PackedScene = preload("res://scenes/tile.tscn")
@export var start_definition: Resource = preload("res://data/start_camp.tres")
@export var goal_definition: Resource = preload("res://data/goal_town.tres")
@export var seed_start_and_goal := true
@export var initial_tiles: Array[Dictionary] = []

var _map: GameMap
var _visual_tiles: Dictionary = {}


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	if _map == null:
		push_warning("Roads needs a GameMap at map_path.")
		return

	if seed_start_and_goal:
		seed_run_endpoints()
	seed_initial_tiles()


func seed_run_endpoints() -> void:
	force_place_tile(_map.get_start_position(), start_definition, 0)
	force_place_tile(_map.get_goal_position(), goal_definition, 2)


func seed_initial_tiles() -> void:
	for tile_entry in initial_tiles:
		var definition: Resource = tile_entry.get("definition")
		if definition == null:
			continue
		var grid_position: Vector2i = tile_entry.get("position", Vector2i(-1, -1))
		if seed_start_and_goal and (grid_position == _map.get_start_position() or grid_position == _map.get_goal_position()):
			continue
		var rotation_steps: int = int(tile_entry.get("rotation_steps", 0))
		force_place_tile(grid_position, definition, rotation_steps)


func place_tile(grid_position: Vector2i, definition: Resource, rotation_steps: int = 0, enemy_data: Dictionary = {}, landmark_data: Dictionary = {}) -> bool:
	var tile_data := make_tile_data(definition, rotation_steps, enemy_data, landmark_data)
	var connections: Dictionary = tile_data.get("connections", {})
	if not _map.can_place_tile(grid_position, connections):
		return false

	return _store_and_spawn_tile(grid_position, tile_data)


func force_place_tile(grid_position: Vector2i, definition: Resource, rotation_steps: int = 0) -> bool:
	if not _map.is_inside_playable_area(grid_position):
		return false
	if _map.get_tile(grid_position) != null:
		remove_tile(grid_position)

	return _store_and_spawn_tile(grid_position, make_tile_data(definition, rotation_steps))


func remove_tile(grid_position: Vector2i) -> void:
	var visual_tile: Node = _visual_tiles.get(grid_position)
	if visual_tile != null:
		visual_tile.queue_free()
	_visual_tiles.erase(grid_position)
	_map.clear_tile(grid_position)


func get_visual_tile(grid_position: Vector2i) -> RoadTile:
	return _visual_tiles.get(grid_position) as RoadTile


func make_tile_data(definition: Resource, rotation_steps: int = 0, enemy_data: Dictionary = {}, landmark_data: Dictionary = {}) -> Dictionary:
	var normalized_rotation := posmod(rotation_steps, 4)
	var tile_data := {
		"definition": definition,
		"rotation_steps": normalized_rotation,
		"connections": definition.get_rotated_openings(normalized_rotation),
	}
	if not enemy_data.is_empty():
		var revealed_enemy := enemy_data.duplicate(true)
		revealed_enemy["revealed"] = true
		revealed_enemy["health"] = 1
		revealed_enemy["max_health"] = 1
		tile_data["enemy"] = revealed_enemy
	if not landmark_data.is_empty():
		tile_data["landmark"] = landmark_data.duplicate(true)
	return tile_data


func _store_and_spawn_tile(grid_position: Vector2i, tile_data: Dictionary) -> bool:
	if not _map.set_tile(grid_position, tile_data):
		return false

	var visual_tile := tile_scene.instantiate() as RoadTile
	visual_tile.definition = tile_data["definition"]
	visual_tile.rotation_steps = tile_data["rotation_steps"]
	visual_tile.tile_size = _map.tile_size
	if tile_data.has("enemy"):
		visual_tile.enemy_data = tile_data["enemy"]
	if tile_data.has("landmark"):
		visual_tile.landmark_data = tile_data["landmark"]
	visual_tile.position = _map.grid_to_world(grid_position)
	add_child(visual_tile)
	_visual_tiles[grid_position] = visual_tile
	return true
