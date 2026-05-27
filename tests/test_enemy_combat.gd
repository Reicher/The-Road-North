extends SceneTree

const MAP_SCRIPT := preload("res://scripts/map.gd")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const INVENTORY_SCRIPT := preload("res://scripts/inventory_ui.gd")
const LOOT_SCRIPT := preload("res://scripts/loot_ui.gd")
const STRAIGHT := preload("res://data/road_straight.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
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

	var enemy_data := {
		"revealed": false,
		"health": 2,
		"max_health": 2,
		"attack": 1,
		"armor": 1,
	}
	var armored_enemy_data := {
		"revealed": false,
		"health": 1,
		"max_health": 1,
		"attack": 1,
		"armor": 3,
	}

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	_assert(roads.place_tile(Vector2i(4, 7), STRAIGHT, 0, enemy_data), "Expected enemy road card placement to succeed")
	_assert(roads.place_tile(Vector2i(3, 8), STRAIGHT, 1, armored_enemy_data), "Expected armored enemy road card placement to succeed")
	var enemy_tile: Dictionary = map.get_tile(Vector2i(4, 7))["enemy"]
	_assert(enemy_tile["revealed"] == true, "Expected placing an enemy road card to reveal the enemy")
	_assert(enemy_tile["health"] == 1, "Expected placed enemies to have one life")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).enemy_data["health"] == 1, "Expected visual enemy data to use one life")

	var health_label := Label.new()
	health_label.name = "HealthLabel"
	root.add_child(health_label)

	var inventory = INVENTORY_SCRIPT.new()
	inventory.name = "Inventory"
	root.add_child(inventory)
	inventory._ready()

	var loot_ui = LOOT_SCRIPT.new()
	loot_ui.name = "Loot"
	loot_ui.player_path = NodePath("../Player")
	loot_ui.inventory_path = NodePath("../Inventory")
	root.add_child(loot_ui)
	loot_ui._ready()

	var player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.health_label_path = NodePath("../HealthLabel")
	player.inventory_path = NodePath("../Inventory")
	player.loot_ui_path = NodePath("../Loot")
	player.start_position = Vector2i(4, 8)
	player.starting_food = 3
	player.starting_health = 5
	player.attack = 0
	player.armor = 1
	player.move_duration = 0.0
	player.combat_bump_duration = 0.0
	player.post_combat_loot_delay = 0.05
	root.add_child(player)
	player._ready()

	var blocked_result := {"blocked": false}
	player.move_blocked.connect(func(_target_position: Vector2i, reason: String) -> void:
		blocked_result["blocked"] = true
	)
	_assert(not player.can_move_to(Vector2i(3, 8)), "Expected enemy armor to make the tile unreachable")
	map.tile_pressed.emit(Vector2i(3, 8))
	_assert(not blocked_result["blocked"], "Expected tapping armored enemy tiles to be ignored before movement")
	_assert(player.grid_position == Vector2i(4, 8), "Expected ignored armored enemy tap to keep player position")
	_assert(player.food == 3, "Expected ignored armored enemy tap not to spend food")
	_assert(not player.move_to(Vector2i(3, 8)), "Expected movement into armored enemy to be blocked")
	_assert(player.grid_position == Vector2i(4, 8), "Expected blocked enemy movement to keep player position")
	_assert(player.food == 3, "Expected blocked enemy movement not to spend food")
	_assert(map.get_tile(Vector2i(3, 8)).has("enemy"), "Expected blocked enemy movement to keep the enemy on the tile")

	_assert(player.move_to(Vector2i(4, 7)), "Expected player to enter enemy road tile")
	_assert(player.is_in_combat(), "Expected combat to stay active while post-combat feedback is visible")
	_assert(not map.get_tile(Vector2i(4, 7)).has("enemy"), "Expected defeated enemy to be removed before loot opens")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).enemy_data.is_empty(), "Expected defeated enemy to disappear before loot opens")
	_assert(not loot_ui.is_open(), "Expected loot screen to wait until after post-combat feedback")
	while player.is_in_combat():
		await process_frame

	_assert(player.health == 5, "Expected armor to prevent enemy damage in this combat")
	_assert(not map.get_tile(Vector2i(4, 7)).has("enemy"), "Expected defeated enemy to be removed from tile data")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).enemy_data.is_empty(), "Expected defeated enemy to disappear from visual tile")
	_assert(loot_ui.is_open(), "Expected defeated enemies to open the loot screen")

	loot_ui.take_all()
	_assert(player.food == 3, "Expected enemy food loot to add a small amount after movement food is spent")
	_assert(player.gold == 1, "Expected enemy gold loot to add a small amount to the gold counter")
	_assert(inventory.get_active_items().size() == 3, "Expected enemy item loot to move into one backpack slot")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
