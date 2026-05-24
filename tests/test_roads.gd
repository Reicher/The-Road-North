extends SceneTree

const MAP_SCRIPT := preload("res://scripts/map.gd")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCRIPT.new()
	map.name = "Map"
	root.add_child(map)
	_assert(map.get_padded_world_rect() == map.get_playable_world_rect(), "Expected map bounds to exclude visual padding")

	var roads = ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()

	_assert(roads.place_tile(Vector2i(4, 4), STRAIGHT, 0), "Expected first straight road to place")
	_assert(map.get_tile(Vector2i(4, 4)) != null, "Expected map to store logical tile data")
	_assert(roads.get_visual_tile(Vector2i(4, 4)) != null, "Expected roads to spawn visual tile")
	_assert(roads.get_visual_tile(Vector2i(4, 4)).position == map.grid_to_world(Vector2i(4, 4)), "Expected visual tile to align to grid center")

	_assert(roads.place_tile(Vector2i(4, 3), STRAIGHT, 0), "Expected matching north/south connection to place")
	_assert(not roads.place_tile(Vector2i(5, 4), STRAIGHT, 1), "Expected invalid east/west mismatch to be rejected")
	_assert(not roads.place_tile(Vector2i(0, 0), STRAIGHT, 0), "Expected road opening outside map to be rejected")
	_assert(not roads.place_tile(Vector2i(4, 4), CORNER, 0), "Expected occupied tile placement to be rejected")

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 0), T_JUNCTION, 2)
	var start_connections: Dictionary = map.get_tile(Vector2i(4, 8))["connections"]
	var goal_connections: Dictionary = map.get_tile(Vector2i(4, 0))["connections"]
	_assert(start_connections["north"] == true and start_connections["south"] == false, "Expected start opening to face inward")
	_assert(goal_connections["south"] == true and goal_connections["north"] == false, "Expected goal opening to face inward")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
