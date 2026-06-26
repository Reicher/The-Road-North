extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")
const RoadPath = preload("res://scripts/road_path.gd")


func _initialize() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var roads = ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()

	var player = PLAYER_SCENE.instantiate() as GamePlayer
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.start_position = Vector2i(4, 8)
	player.starting_food = 5
	player.move_duration = 0.0
	root.add_child(player)
	player._ready()

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 0)

	_assert(player.grid_position == Vector2i(4, 8), "Expected player to start at the requested grid position")
	_assert(player.food == 5, "Expected player to start with configured food")
	_assert(player.health == 4, "Expected player to start with default health")
	_assert(player.max_health == 4, "Expected player to start with default max health")
	map.tile_pressed.emit(Vector2i(4, 7))
	_assert(player.grid_position == Vector2i(4, 8), "Expected tapping a tile to select it without moving")
	_assert(player.get_selected_tile() == Vector2i(4, 7), "Expected tapping a tile to store the selection")
	_assert(map.get_node("MapVisuals").get("_selection_highlight") != null, "Expected the selected tile to get a visible outline")
	_assert(player.get_node("MovementSelection/Label").text == "Straight Road", "Expected the selected road type to be named")
	_assert(player.get_node("MovementSelection/ConfirmButton").visible, "Expected a reachable road selection to show movement confirmation")
	_assert(player.confirm_selected_move(), "Expected confirming a reachable road selection to start movement")
	_assert(player.grid_position == Vector2i(4, 7), "Expected confirmed selection to move the player")
	_assert(player.food == 4, "Expected confirmed movement to consume food")
	roads.set_encounter(Vector2i(4, 7), {"type": GameMap.ENCOUNTER_ENEMY, "power": 2})
	map.tile_pressed.emit(Vector2i(4, 7))
	_assert(player.get_node("MovementSelection/Label").text == "Straight Road - Enemy", "Expected enemy roads to identify both road and encounter")
	_assert(player.get_node("MovementSelection/ConfirmButton").visible, "Expected the occupied enemy road to remain confirmable")
	roads.set_encounter(Vector2i(4, 7), {"type": GameMap.ENCOUNTER_TAVERN})
	map.tile_pressed.emit(Vector2i(4, 7))
	_assert(player.get_node("MovementSelection/Label").text == "Straight Road - Tavern", "Expected permanent encounter roads to identify both road and encounter")
	_assert(player.get_node("MovementSelection/ConfirmButton").visible, "Expected a reachable permanent encounter road to offer movement")
	roads.clear_encounter(Vector2i(4, 7))
	map.tile_pressed.emit(Vector2i(0, 0))
	_assert(player.get_node("MovementSelection/Label").text == "Forest", "Expected an empty map tile to be identified")
	_assert(not player.get_node("MovementSelection/ConfirmButton").visible, "Expected a non-road tile not to offer movement")
	player.clear_tile_selection()
	player.grid_position = Vector2i(4, 8)
	player.position = RoadPath.get_world_anchor(map, player.grid_position)
	player.food = 5

	var hop_start: Vector3 = player.position
	var hop_target: Vector3 = map.grid_to_world(Vector2i(4, 7))
	player.call("_apply_hop_progress", hop_start, hop_target, (hop_target - hop_start).normalized(), 0.1)
	_assert(player.position.is_equal_approx(hop_start.lerp(hop_target, 0.1)), "Expected hop movement to advance toward the target")
	_assert(player.get_node("Visuals").position.y > 0.0, "Expected the player visuals to rise during each hop")
	player.call("_apply_hop_progress", hop_start, hop_target, (hop_target - hop_start).normalized(), 0.2)
	_assert(is_zero_approx(player.get_node("Visuals").position.y), "Expected the player visuals to land between hops")
	player.call("_reset_hop_visuals")
	_assert(player.get_node("Visuals").transform.is_equal_approx(Transform3D.IDENTITY), "Expected hop visuals to reset after movement")
	player.position = hop_start

	_assert(player.move_to(Vector2i(4, 7)), "Expected player to move north onto connected road")
	_assert(player.grid_position == Vector2i(4, 7), "Expected player grid position to update after movement")
	_assert(player.food == 4, "Expected valid movement to consume one food")
	_assert(player.health == 4, "Expected movement not to change health")
	_assert(player.move_to(Vector2i(4, 8)), "Expected player to backtrack south onto the connected start road")
	_assert(player.grid_position == Vector2i(4, 8), "Expected backtracking to update player grid position")
	_assert(player.food == 3, "Expected backtracking to consume one food")
	_assert(player.move_to(Vector2i(4, 7)), "Expected player to move north again after backtracking")
	_assert(player.food == 2, "Expected repeated valid movement to keep consuming food")

	_assert(roads.place_tile(Vector2i(4, 6), CORNER, 1, {
		"type": GameMap.ENCOUNTER_BERRY_BUSH,
		"loot": [{"kind": "food", "amount": 2}],
	}), "Expected reward encounter road card placement to succeed")
	_assert(not player.move_to(Vector2i(5, 7)), "Expected empty or disconnected tile movement to be blocked")
	_assert(player.grid_position == Vector2i(4, 7), "Expected invalid movement to leave player in place")
	_assert(player.food == 2, "Expected invalid movement not to consume food")

	_assert(player.move_to(Vector2i(4, 6)), "Expected bidirectional north/south connection to allow movement")
	var corner_anchor := RoadPath.get_world_anchor(map, Vector2i(4, 6))
	_assert(player.position.is_equal_approx(corner_anchor), "Expected player to rest on the corner's curved centerline")
	_assert(not player.position.is_equal_approx(map.grid_to_world(Vector2i(4, 6))), "Expected a corner's curved centerline not to pass through the tile center")
	_assert(player.food == 3, "Expected encounter food to be collected after movement cost")
	_assert(map.get_encounter(Vector2i(4, 6)).is_empty(), "Expected collected encounter to be removed")
	roads.force_place_tile(Vector2i(5, 6), STRAIGHT, 1)
	_assert(player.move_to(Vector2i(5, 6)), "Expected bidirectional east/west connection to allow movement")
	_assert(player.food == 2, "Expected each valid movement to consume food after encounter reward")

	_assert(roads.place_tile(Vector2i(6, 6), STRAIGHT, 1, {
		"type": GameMap.ENCOUNTER_CACHE,
		"loot": [
			{
				"kind": "item",
				"item": {
					"name": "Walking Stick",
					"effect": "+1 Power",
					"power_bonus": 1,
				},
			},
		],
	}), "Expected treasure cache road card placement to succeed")
	_assert(player.move_to(Vector2i(6, 6)), "Expected player to move onto a treasure cache")
	_assert(player.gold == 0, "Expected treasure caches not to add gold")
	_assert(map.get_encounter(Vector2i(6, 6)).is_empty(), "Expected collected treasure cache to be removed")

	player.food = 0
	_assert(not player.move_to(Vector2i(4, 6)), "Expected movement to be blocked when food is empty")
	_assert(player.grid_position == Vector2i(6, 6), "Expected no-food movement to leave player in place")

	player.set_health(4)
	_assert(player.health == 4, "Expected player health not to exceed max health")
	player.set_max_health(5)
	player.set_health(4)
	_assert(player.health == 4, "Expected player health to increase after max health is raised")
	player.set_base_power(2)
	_assert(player.get_total_power() == 2, "Expected mutable base power to contribute to total power")

	var path_map = MAP_SCENE.instantiate() as GameMap
	path_map.name = "PathMap"
	path_map.playable_width = 4
	path_map.playable_height = 3
	root.add_child(path_map)
	path_map.set_tile(Vector2i(0, 2), {"connections": {"north": true, "east": true}})
	path_map.set_tile(Vector2i(0, 1), {"connections": {"north": true, "south": true}})
	path_map.set_tile(Vector2i(0, 0), {"connections": {"east": true, "south": true}})
	path_map.set_tile(Vector2i(1, 0), {"connections": {"east": true, "south": true, "west": true}})
	path_map.set_tile(Vector2i(1, 2), {"connections": {"east": true, "west": true}})
	path_map.set_tile(Vector2i(2, 2), {"connections": {"north": true, "west": true}})
	path_map.set_tile(Vector2i(2, 1), {"connections": {"north": true, "south": true}})
	path_map.set_tile(Vector2i(2, 0), {"connections": {"south": true, "west": true}})

	var shortest_path := path_map.find_shortest_path(Vector2i(0, 2), Vector2i(1, 0))
	_assert(shortest_path == [Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0)], "Expected pathfinding to select the shortest connected route")

	var path_player = PLAYER_SCENE.instantiate() as GamePlayer
	path_player.name = "PathPlayer"
	path_player.map_path = NodePath("../PathMap")
	path_player.start_position = Vector2i(0, 2)
	path_player.starting_food = 10
	path_player.move_duration = 0.0
	root.add_child(path_player)
	path_player._ready()
	_assert(path_player.move_to(Vector2i(1, 0)), "Expected a non-adjacent connected destination to start movement")
	_assert(path_player.grid_position == Vector2i(1, 0), "Expected automatic movement to reach the selected destination")
	_assert(path_player.food == 7, "Expected automatic movement to spend one food per path step")
	_assert(path_map.get_node("MapVisuals").get("_tap_highlights").has(Vector2i(1, 0)), "Expected the selected destination tile to flash")
	var food_before_jump: int = path_player.food
	_assert(path_player.move_to(path_player.grid_position), "Expected tapping the occupied tile to trigger a jump")
	_assert(path_player.food == food_before_jump, "Expected jumping in place not to spend food")

	path_player.set("_moving", true)
	_assert(path_player.move_to(Vector2i(2, 0)), "Expected a new destination to replace the active route")
	_assert(path_player.get("_route_destination") == Vector2i(2, 0), "Expected the active route destination to update immediately")
	path_player.set("_moving", false)

	var default_food_player = PLAYER_SCENE.instantiate() as GamePlayer
	default_food_player.name = "DefaultFoodPlayer"
	default_food_player.map_path = NodePath("../Map")
	root.add_child(default_food_player)
	default_food_player._ready()
	_assert(default_food_player.food == 10, "Expected default starting food to be ten")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
