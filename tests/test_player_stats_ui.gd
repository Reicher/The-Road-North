extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_STATS_SCENE := preload("res://ui/player_stats.tscn")
const MAP_SCENE := preload("res://scenes/map.tscn")


func _initialize() -> void:
	var root := Node.new()
	get_root().add_child(root)

	var map := MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var player := PLAYER_SCENE.instantiate() as GamePlayer
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.starting_food = 5
	player.starting_gold = 2
	root.add_child(player)
	player._ready()

	var stats := PLAYER_STATS_SCENE.instantiate() as PlayerStatsUI
	stats.name = "PlayerStats"
	stats.player_path = NodePath("../Player")
	root.add_child(stats)
	stats._ready()

	var deck_controller := DeckController.new()
	deck_controller.deck.append({"category": "Road"})
	deck_controller.deck.append({"category": "Road"})
	deck_controller.starting_deck.append({"category": "Road"})
	deck_controller.starting_deck.append({"category": "Road"})
	deck_controller.starting_deck.append({"category": "Road"})
	stats._deck_controller = deck_controller
	deck_controller.deck_count_changed.connect(stats._on_deck_count_changed)

	_assert(is_equal_approx(stats.gain_pulse_duration, 2.0), "Expected resource gain feedback to remain visible for two seconds")
	_assert(is_equal_approx(stats.icon_size, PlayerStatsUI.STAT_ICON_SIZE), "Expected every resource icon to use the shared larger stat size")
	_assert(is_equal_approx(stats.row_height, PlayerStatsUI.STAT_ROW_HEIGHT), "Expected larger resources to retain enough vertical spacing")
	_assert(PlayerStatsUI.STAT_VALUE_FONT_SIZE == 32, "Expected every resource value to use the compact readable HUD font size")
	_assert((stats.get_node("PowerRow") as StatRow).alignment == BoxContainer.ALIGNMENT_END, "Expected power content to align with the right HUD margin")
	for stat_name in ["food", "gold", "health", "deck", "power"]:
		_assert(stats._get_stat_icon(stat_name) != null, "Expected exported stat texture to load for %s" % stat_name)
	_assert(stats._get_stat_icon("health") == load("res://assets/images/stats/stat_health.png"), "Expected health to use the health icon")
	_assert(stats._get_stat_icon("power") == load("res://assets/images/stats/stat_power.png"), "Expected power to use the power icon")
	_assert(stats._get_health_display() == "4/4", "Expected stats HUD to show full starting health")
	_assert(stats._get_deck_display() == "2/3", "Expected stats HUD to show remaining cards out of the level deck total")

	deck_controller.draw_card()
	_assert(stats._get_deck_display() == "1/3", "Expected stats HUD deck count to update after drawing a card")

	player.add_food(3)
	_assert(stats._gain_amounts.get("food", 0) == 3, "Expected food gains to show their amount in the stats HUD")
	_assert(stats._pulse_sign.get("food", 0) == 1, "Expected food gains to use a positive pulse")
	_assert(stats._get_stat_glow_color("food", 1) == Color(0.32, 1.0, 0.38), "Expected resource gains to flash green")
	player.add_food(2)
	_assert(stats._gain_amounts.get("food", 0) == 5, "Expected consecutive food gains to combine in the stats HUD")

	player.add_gold(4)
	_assert(stats._gain_amounts.get("gold", 0) == 4, "Expected gold gains to show their amount in the stats HUD")
	_assert(stats._pulse_strength.get("food", 0.0) > 0.0, "Expected simultaneous resource gains to keep the food pulse visible")
	_assert(stats._pulse_strength.get("gold", 0.0) > 0.0, "Expected simultaneous resource gains to show the gold pulse")

	player.food -= 1
	player.food_changed.emit(player.food)
	_assert(stats._gain_amounts.get("food", 0) == -1, "Expected spending food to show the amount lost")
	_assert(stats._pulse_sign.get("food", 0) == -1, "Expected spending food to retain negative feedback")
	_assert(stats._get_stat_glow_color("food", -1) == Color(1.0, 0.32, 0.22), "Expected resource losses to flash red")

	player.set_health(2)
	_assert(stats._gain_amounts.get("health", 0) == -2, "Expected lost health to show the amount lost")
	_assert(stats._pulse_sign.get("health", 0) == -1, "Expected lost health to use negative feedback")
	_assert(stats._pulse_strength.get("health", 0.0) > 0.0, "Expected lost health feedback to remain visible")

	player.set_health(3)
	_assert(stats._gain_amounts.get("health", 0) == 1, "Expected gained health to show the amount gained")
	_assert(stats._pulse_sign.get("health", 0) == 1, "Expected gained health to use positive feedback")

	deck_controller.free()
	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
