extends SceneTree

const MAP_SCRIPT := preload("res://scripts/map.gd")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCRIPT.new()
	map.name = "Map"
	root.add_child(map)

	var roads = ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()

	var player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.start_position = Vector2i(4, 8)
	player.starting_food = 3
	player.move_duration = 0.0
	root.add_child(player)
	player._ready()

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 0)
	roads.force_place_tile(Vector2i(4, 6), CORNER, 1)
	roads.force_place_tile(Vector2i(5, 6), STRAIGHT, 1)

	_assert(player.grid_position == Vector2i(4, 8), "Expected player to start at the requested grid position")
	_assert(player.food == 3, "Expected player to start with configured food")

	_assert(player.move_to(Vector2i(4, 7)), "Expected player to move north onto connected road")
	_assert(player.grid_position == Vector2i(4, 7), "Expected player grid position to update after movement")
	_assert(player.food == 2, "Expected valid movement to consume one food")

	_assert(not player.move_to(Vector2i(5, 7)), "Expected empty or disconnected tile movement to be blocked")
	_assert(player.grid_position == Vector2i(4, 7), "Expected invalid movement to leave player in place")
	_assert(player.food == 2, "Expected invalid movement not to consume food")

	_assert(player.move_to(Vector2i(4, 6)), "Expected bidirectional north/south connection to allow movement")
	_assert(player.move_to(Vector2i(5, 6)), "Expected bidirectional east/west connection to allow movement")
	_assert(player.food == 0, "Expected each valid movement to consume food")

	_assert(not player.move_to(Vector2i(4, 6)), "Expected movement to be blocked when food is empty")
	_assert(player.grid_position == Vector2i(5, 6), "Expected no-food movement to leave player in place")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
