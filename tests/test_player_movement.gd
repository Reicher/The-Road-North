extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var health_label := Label.new()
	health_label.name = "HealthLabel"
	root.add_child(health_label)

	var roads = ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()

	var player = PLAYER_SCENE.instantiate() as GamePlayer
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.health_label_path = NodePath("../HealthLabel")
	player.start_position = Vector2i(4, 8)
	player.starting_food = 5
	player.move_duration = 0.0
	root.add_child(player)
	player._ready()

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 0)

	_assert(player.grid_position == Vector2i(4, 8), "Expected player to start at the requested grid position")
	_assert(player.food == 5, "Expected player to start with configured food")
	_assert(player.health == 3, "Expected player to start with default health")
	_assert(player.max_health == 3, "Expected player to start with default max health")
	_assert(health_label.text == "Health: 3/3", "Expected health label to show current and max health")

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
	_assert(player.health == 3, "Expected movement not to change health")
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
					"name": "Knife",
					"effect": "+1 Power",
					"power": 1,
				},
			},
			{"kind": "gold", "amount": 4},
		],
	}), "Expected treasure cache road card placement to succeed")
	_assert(player.move_to(Vector2i(6, 6)), "Expected player to move onto a treasure cache")
	_assert(player.gold == 4, "Expected treasure cache gold to be collected when entering its tile")
	_assert(map.get_encounter(Vector2i(6, 6)).is_empty(), "Expected collected treasure cache to be removed")

	player.food = 0
	_assert(not player.move_to(Vector2i(4, 6)), "Expected movement to be blocked when food is empty")
	_assert(player.grid_position == Vector2i(6, 6), "Expected no-food movement to leave player in place")

	player.set_health(4)
	_assert(player.health == 3, "Expected player health not to exceed max health")
	player.set_max_health(5)
	player.set_health(4)
	_assert(player.health == 4, "Expected player health to increase after max health is raised")
	_assert(health_label.text == "Health: 4/5", "Expected health label to update after health changes")
	player.set_base_power(2)
	_assert(player.get_total_power() == 2, "Expected mutable base power to contribute to total power")

	var default_food_player = PLAYER_SCENE.instantiate() as GamePlayer
	default_food_player.name = "DefaultFoodPlayer"
	default_food_player.map_path = NodePath("../Map")
	root.add_child(default_food_player)
	default_food_player._ready()
	_assert(default_food_player.food == 20, "Expected default starting food to be about a quarter of the 9x9 map area")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
