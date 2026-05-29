extends SceneTree

const LEVEL_001 := preload("res://levels/level_001.tscn")
const LEVEL_002 := preload("res://levels/level_002.tscn")


func _initialize() -> void:
	var level := LEVEL_001.instantiate()
	get_root().add_child(level)

	var map := level.get_node("Map") as GameMap
	var roads := level.get_node("Roads") as Roads
	var deck_controller := level.get_node("DeckController") as DeckController
	var hand := level.get_node("UI/Hand") as HandUI
	var loot := level.get_node("UI/Loot")
	var inventory := level.get_node("UI/Inventory")
	var player := level.get_node("Player") as GamePlayer

	_assert(map != null, "Expected level scene to include a GameMap")
	_assert(roads != null, "Expected level scene to include Roads")
	_assert(deck_controller != null, "Expected level scene to include DeckController")
	_assert(hand != null, "Expected level scene to include HandUI")
	_assert(loot != null, "Expected level scene to include LootUI")
	_assert(inventory != null, "Expected level scene to include InventoryUI")
	_assert(inventory.get_index() > loot.get_index(), "Expected inventory to sit above loot for backpack interaction")
	_assert(player.loot_ui_path == NodePath("../UI/Loot"), "Expected player to connect to LootUI")
	_assert(map.playable_width == 9 and map.playable_height == 9, "Expected level 001 to configure a 9x9 map")
	_assert(roads.seed_start_and_goal, "Expected level 001 to seed start and goal tiles")
	_assert(roads.start_definition.get("visual_identity") == "house", "Expected start tile to use simple house visuals")
	_assert(roads.goal_definition.get("visual_identity") == "house", "Expected goal tile to use simple house visuals")
	_assert(deck_controller.hand_size == 4, "Expected level 001 to configure a four-card hand")
	_assert(is_equal_approx(deck_controller.road_card_ratio, 0.75), "Expected level 001 to configure road card ratio")
	_assert(is_equal_approx(deck_controller.enemy_road_card_ratio, 1.0 / 3.0), "Expected level 001 to configure enemy road card ratio")
	_assert(is_equal_approx(deck_controller.reward_road_card_ratio, 0.20), "Expected level 001 to configure reward road card ratio")
	_assert(deck_controller.road_distribution["straight"] == 30.0, "Expected level 001 to configure road distribution")

	var level_002 := LEVEL_002.instantiate()
	get_root().add_child(level_002)
	var second_map := level_002.get_node("Map") as GameMap
	var second_deck_controller := level_002.get_node("DeckController") as DeckController
	_assert(second_map.playable_width == 11 and second_map.playable_height == 11, "Expected level 002 to configure an 11x11 map")
	_assert(second_deck_controller.hand_size == 4, "Expected level 002 to configure a four-card hand")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
