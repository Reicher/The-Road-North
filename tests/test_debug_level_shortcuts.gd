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

	_send_key(main, KEY_3)
	await process_frame
	var third_level := main.get_node("Level")
	_assert((third_level.get_node("Map") as GameMap).playable_width == 9, "Expected key 3 to load level 3")

	_send_key(main, KEY_4)
	await process_frame
	_assert(main.get_node("Level") == third_level, "Expected an unconfigured level key to leave the current level unchanged")

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


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
