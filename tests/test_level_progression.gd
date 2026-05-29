extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main := MAIN_SCENE.instantiate()
	get_root().add_child(main)
	await process_frame

	var first_level := main.get_node("Level")
	var first_map := first_level.get_node("Map") as GameMap
	var first_player := first_level.get_node("Player") as GamePlayer
	var first_screen := first_level.get_node("UI/GameOver") as GameOverUI
	var first_hand := first_level.get_node("UI/Hand") as HandUI
	_assert(first_map.playable_width == 9 and first_map.playable_height == 9, "Expected the game to start on the 9x9 level")

	first_player.grid_position = first_map.get_goal_position()
	_assert(first_player.call("_check_run_won"), "Expected reaching the first goal to complete the level")
	_assert(first_screen.visible, "Expected the completion screen to show after the first goal")
	_assert(not first_hand.visible, "Expected the card hand to hide on the completion screen")
	_assert(first_screen.get_node("Prompt/ContentMargin/Stack/Title").text == "Level completed", "Expected first completion text")
	_assert(first_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").text == "Next level", "Expected first completion button to advance")

	first_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").pressed.emit()
	await process_frame

	var second_level := main.get_node("Level")
	var second_map := second_level.get_node("Map") as GameMap
	var second_player := second_level.get_node("Player") as GamePlayer
	var second_screen := second_level.get_node("UI/GameOver") as GameOverUI
	_assert(second_map.playable_width == 11 and second_map.playable_height == 11, "Expected Next level to load the 11x11 map")

	second_player.set_health(0)
	_assert(second_screen.visible, "Expected loss screen to show on the current level")
	_assert(not (second_level.get_node("UI/Hand") as HandUI).visible, "Expected the card hand to hide on the loss screen")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/Title").text == "You loose", "Expected loss text")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").text == "Restart level", "Expected loss button to restart the current level")
	second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").pressed.emit()
	await process_frame

	second_level = main.get_node("Level")
	second_map = second_level.get_node("Map") as GameMap
	second_player = second_level.get_node("Player") as GamePlayer
	second_screen = second_level.get_node("UI/GameOver") as GameOverUI
	var second_hand := second_level.get_node("UI/Hand") as HandUI
	_assert(second_map.playable_width == 11 and second_map.playable_height == 11, "Expected Restart level to reload the current 11x11 level")

	second_player.grid_position = second_map.get_goal_position()
	_assert(second_player.call("_check_run_won"), "Expected reaching the final goal to complete the game")
	_assert(second_screen.visible, "Expected the final win screen to show")
	_assert(not second_hand.visible, "Expected the card hand to hide on the final win screen")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/Title").text == "You won", "Expected final win text")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").text == "Restart game", "Expected final button to restart the game")

	second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").pressed.emit()
	await process_frame

	var restarted_map := main.get_node("Level/Map") as GameMap
	_assert(restarted_map.playable_width == 9 and restarted_map.playable_height == 9, "Expected Restart game to return to the first level")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
