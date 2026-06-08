class_name Roads
extends Node3D

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


func place_tile(grid_position: Vector2i, definition: Resource, rotation_steps: int = 0, encounter_data: Dictionary = {}) -> bool:
	var tile_data := make_tile_data(definition, rotation_steps, encounter_data)
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


func set_encounter(grid_position: Vector2i, encounter_data: Dictionary) -> bool:
	if _map.get_tile(grid_position) == null:
		return false
	var stored_encounter := _prepare_encounter(encounter_data)
	_map.update_encounter_data(grid_position, stored_encounter)
	var visual_tile := get_visual_tile(grid_position)
	if visual_tile != null:
		visual_tile.set_encounter_data(stored_encounter)
	return true


func clear_encounter(grid_position: Vector2i) -> bool:
	if _map.get_encounter(grid_position).is_empty():
		return false
	_map.clear_encounter(grid_position)
	var visual_tile := get_visual_tile(grid_position)
	if visual_tile != null:
		visual_tile.set_encounter_data({})
	return true


func get_visual_tile(grid_position: Vector2i) -> RoadTile:
	return _visual_tiles.get(grid_position) as RoadTile


func make_tile_data(definition: Resource, rotation_steps: int = 0, encounter_data: Dictionary = {}) -> Dictionary:
	var normalized_rotation := posmod(rotation_steps, 4)
	var tile_data := {
		"definition": definition,
		"rotation_steps": normalized_rotation,
		"connections": definition.get_rotated_openings(normalized_rotation),
	}
	if not encounter_data.is_empty():
		tile_data["encounter"] = _prepare_encounter(encounter_data)
	return tile_data


func _prepare_encounter(encounter_data: Dictionary) -> Dictionary:
	var encounter := encounter_data.duplicate(true)
	if not encounter.has("type") and encounter.has("power"):
		encounter["type"] = GameMap.ENCOUNTER_ENEMY
	if str(encounter.get("type", "")) == GameMap.ENCOUNTER_ENEMY:
		encounter["revealed"] = true
		encounter["health"] = 1
		encounter["max_health"] = 1
	return encounter


func _store_and_spawn_tile(grid_position: Vector2i, tile_data: Dictionary) -> bool:
	if not _map.set_tile(grid_position, tile_data):
		return false

	var visual_tile := tile_scene.instantiate() as RoadTile
	visual_tile.definition = tile_data["definition"]
	visual_tile.rotation_steps = tile_data["rotation_steps"]
	visual_tile.tile_size = _map.tile_size
	if tile_data.has("encounter"):
		visual_tile.encounter_data = tile_data["encounter"]
	visual_tile.position = _map.grid_to_world(grid_position)
	add_child(visual_tile)
	_visual_tiles[grid_position] = visual_tile
	return true
