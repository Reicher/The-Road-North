extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main := MAIN_SCENE.instantiate()
	get_root().add_child(main)
	await process_frame

	_send_key(main, KEY_D)
	await process_frame
	_assert((main.get_node("Level/Map") as GameMap).playable_width == 5, "Expected debug mode to start on level 1")
	_assert_debug_intro_skipped(main.get_node("Level"))

	_send_key(main, KEY_3)
	await process_frame
	var third_level := main.get_node("Level")
	_assert((third_level.get_node("Map") as GameMap).playable_width == 9, "Expected key 3 to load level 3")
	_assert_debug_intro_skipped(third_level)

	_send_key(main, KEY_4)
	await process_frame
	var fourth_level := main.get_node("Level")
	_assert(fourth_level != third_level and (fourth_level.get_node("Map") as GameMap).playable_width == 7, "Expected key 4 to load level 4")

	_send_key(main, KEY_0)
	await process_frame
	_assert((main.get_node("Level/Map") as GameMap).playable_width == 11, "Expected key 0 to load level 10")

	var physical_key_event := InputEventKey.new()
	physical_key_event.physical_keycode = KEY_2
	physical_key_event.pressed = true
	main.call("_input", physical_key_event)
	await process_frame
	_assert((main.get_node("Level/Map") as GameMap).playable_width == 7, "Expected physical number keys to select configured levels")

	quit()


func _send_key(target: Node, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	target.call("_input", event)


func _assert_debug_intro_skipped(level: Node) -> void:
	var player := level.get_node("Player") as GamePlayer
	var hand := level.get_node("UI/Hand") as HandUI
	var camera := level.get_node("Camera3D") as Camera3D
	_assert(not bool(level.get("play_intro_sequence")), "Expected debug levels to disable the UI intro")
	_assert(player.visible, "Expected the player to be visible immediately in debug mode")
	_assert(hand.visible and hand.interaction_enabled, "Expected cards to be playable immediately in debug mode")
	_assert(not bool(camera.get("play_start_zoom_sequence")), "Expected debug levels to skip the map zoom intro")
	_assert(camera.get("_start_zoom_tween") == null, "Expected no start zoom tween in debug mode")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
