extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const INVENTORY_SCENE := preload("res://ui/inventory.tscn")
const LOOT_SCENE := preload("res://ui/loot.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
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

	var enemy_data := {
		"type": GameMap.ENCOUNTER_ENEMY,
		"revealed": false,
		"health": 2,
		"max_health": 2,
		"power": 1,
	}
	var strong_enemy_data := {
		"type": GameMap.ENCOUNTER_ENEMY,
		"revealed": false,
		"health": 1,
		"max_health": 1,
		"power": 10,
	}

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	_assert(roads.place_tile(Vector2i(4, 7), STRAIGHT, 0, enemy_data), "Expected enemy road card placement to succeed")
	_assert(roads.place_tile(Vector2i(3, 8), STRAIGHT, 1, strong_enemy_data), "Expected strong enemy road card placement to succeed")
	var enemy_tile: Dictionary = map.get_tile(Vector2i(4, 7))["encounter"]
	_assert(enemy_tile["revealed"] == true, "Expected placing an enemy road card to reveal the enemy")
	_assert(enemy_tile["health"] == 1, "Expected placed enemies to have one life")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).enemy_data["health"] == 1, "Expected visual enemy data to use one life")

	var health_label := Label.new()
	health_label.name = "HealthLabel"
	root.add_child(health_label)

	var inventory = INVENTORY_SCENE.instantiate() as InventoryUI
	inventory.name = "Inventory"
	root.add_child(inventory)
	inventory._ready()

	var loot_ui = LOOT_SCENE.instantiate() as LootUI
	loot_ui.name = "Loot"
	loot_ui.player_path = NodePath("../Player")
	loot_ui.inventory_path = NodePath("../Inventory")
	root.add_child(loot_ui)
	loot_ui._ready()

	var player = PLAYER_SCENE.instantiate() as GamePlayer
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.health_label_path = NodePath("../HealthLabel")
	player.inventory_path = NodePath("../Inventory")
	player.loot_ui_path = NodePath("../Loot")
	player.start_position = Vector2i(4, 8)
	player.starting_food = 3
	player.starting_health = 5
	player.starting_max_health = 5
	player.base_power = 0
	player.move_duration = 0.0
	player.combat_bump_duration = 0.0
	player.post_combat_loot_delay = 0.05
	root.add_child(player)
	player._ready()
	var rewards = player.get_node("Rewards")
	for loot_seed in range(1, 100):
		rewards.set_loot_seed(loot_seed)
		var seeded_loot: Array = rewards._make_enemy_loot(enemy_data)
		if seeded_loot.size() == 2:
			rewards.set_loot_seed(loot_seed)
			break
	player.move_started.connect(func(_target_position: Vector2i) -> void:
		player.input_enabled = false
	)
	player.moved.connect(func(_grid_position: Vector2i) -> void:
		player.input_enabled = true
	)

	_assert(player.can_move_to(Vector2i(3, 8)), "Expected dangerous enemy road tiles to remain reachable")

	var lethal_player = PLAYER_SCENE.instantiate() as GamePlayer
	lethal_player.name = "LethalPlayer"
	lethal_player.map_path = NodePath("../Map")
	lethal_player.start_position = Vector2i(4, 8)
	lethal_player.starting_food = 3
	lethal_player.starting_health = 1
	lethal_player.base_power = 0
	lethal_player.move_duration = 0.0
	lethal_player.combat_bump_duration = 0.0
	root.add_child(lethal_player)
	lethal_player._ready()
	var lethal_result := {"over": false}
	lethal_player.game_over.connect(func(reason: String) -> void:
		lethal_result["over"] = reason == "health"
	)
	_assert(lethal_player.move_to(Vector2i(3, 8)), "Expected movement into dangerous enemies to be allowed")
	_assert(lethal_result["over"], "Expected dangerous enemies to kill players with too little health")

	_assert(player.move_to(Vector2i(4, 7)), "Expected player to enter enemy road tile")
	_assert(player.is_in_combat(), "Expected combat to stay active while post-combat feedback is visible")
	_assert(not map.get_tile(Vector2i(4, 7)).has("encounter"), "Expected defeated enemy to be removed before loot opens")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).enemy_data.is_empty(), "Expected defeated enemy to disappear before loot opens")
	_assert(not loot_ui.is_open(), "Expected loot screen to wait until after post-combat feedback")
	while player.is_in_combat():
		await process_frame

	_assert(player.health == 5, "Expected player power to prevent enemy damage in this combat")
	_assert(not map.get_tile(Vector2i(4, 7)).has("encounter"), "Expected defeated enemy to be removed from tile data")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).enemy_data.is_empty(), "Expected defeated enemy to disappear from visual tile")
	_assert(loot_ui.is_open(), "Expected defeated enemies to open the loot screen")

	loot_ui.take_all()
	_assert(player.food == 2, "Expected enemy loot not to add food")
	_assert(player.gold >= 2 and player.gold <= 5, "Expected enemy gold loot to scale from enemy level")
	_assert(inventory.get_active_items().size() == 2, "Expected enemy item loot to move into one backpack slot")
	_assert(player.input_enabled, "Expected player input to resume after enemy combat movement")
	_assert(player.move_to(Vector2i(4, 8)), "Expected player to backtrack after enemy combat")
	_assert(player.grid_position == Vector2i(4, 8), "Expected enemy combat backtracking to move onto the connected start road")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
