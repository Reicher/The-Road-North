extends SceneTree

const MAP_SCRIPT := preload("res://scripts/map.gd")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const GAME_OVER_SCENE := preload("res://ui/game_over.tscn")
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
	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 0)

	var player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.start_position = Vector2i(4, 8)
	player.starting_food = 1
	player.move_duration = 0.0
	root.add_child(player)
	player._ready()

	var overlay = GAME_OVER_SCENE.instantiate() as GameOverUI
	overlay.name = "GameOver"
	overlay.player_path = NodePath("../Player")
	root.add_child(overlay)
	overlay._ready()

	_assert(not overlay.visible, "Expected game-over overlay to start hidden")
	_assert(player.move_to(Vector2i(4, 7)), "Expected final food movement to succeed")
	await process_frame
	_assert(overlay.visible, "Expected running out of food to show game over")
	_assert(not player.input_enabled, "Expected game over to disable player input")
	_assert(overlay.get_node("Prompt/ContentMargin/Stack/Title").text == "You loose", "Expected loss overlay to use loss copy")
	_assert(overlay.get_node("Prompt/ContentMargin/Stack/RestartButton").text == "Restart level", "Expected loss overlay to restart the level")
	_assert(overlay.get_node("Prompt/ContentMargin/Stack/RestartButton") != null, "Expected restart button under game-over prompt")

	var second_player = PLAYER_SCRIPT.new()
	second_player.name = "HealthPlayer"
	second_player.map_path = NodePath("../Map")
	second_player.starting_health = 1
	root.add_child(second_player)
	second_player._ready()
	var health_result := {"over": false}
	second_player.game_over.connect(func(reason: String) -> void:
		health_result["over"] = reason == "health"
	)
	second_player.set_health(0)
	_assert(health_result["over"], "Expected zero health to emit health game over")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
