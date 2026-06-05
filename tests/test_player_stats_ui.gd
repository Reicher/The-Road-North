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
	_assert(is_equal_approx(stats.gain_pulse_duration, 2.0), "Expected resource gain feedback to remain visible for two seconds")

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
	_assert(stats._gain_amounts.get("food", -1) == 0, "Expected spending food not to show a positive gain amount")
	_assert(stats._pulse_sign.get("food", 0) == -1, "Expected spending food to retain negative feedback")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
