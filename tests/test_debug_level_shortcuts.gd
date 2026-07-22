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
	_assert((main.get_node("DebugOverlay/DebugLabel") as Label).visible, "Expected debug mode to show the Debug label")

	var first_level := main.get_node("Level")
	var first_hand := first_level.get_node("UI/Hand") as HandUI
	_send_key(main, KEY_Q)
	await process_frame
	_assert(first_hand.cards.size() == 4, "Expected debug Q to show the most likely normal-sized hand")

	_send_key(main, KEY_W)
	await process_frame
	_assert(first_hand.cards.size() == 5, "Expected debug W to show every plain road type")
	_assert(_all_cards_match(first_hand.cards, "Road", ""), "Expected debug W hand to contain plain road cards")

	_send_key(main, KEY_E)
	await process_frame
	_assert(first_hand.cards.size() == 5, "Expected debug E to show every enemy road type")
	_assert(_all_cards_match(first_hand.cards, "Road", GameConstants.ENCOUNTER_ENEMY), "Expected debug E hand to contain enemy road cards")

	_send_key(main, KEY_R)
	await process_frame
	_assert(first_hand.cards.size() == 10, "Expected debug R to ignore max hand size and show every road with both reward types")
	_assert(_count_encounters(first_hand.cards, GameConstants.ENCOUNTER_BERRY_BUSH) == 5, "Expected debug R hand to include berry roads")
	_assert(_count_encounters(first_hand.cards, GameConstants.ENCOUNTER_CACHE) == 5, "Expected debug R hand to include cache roads")

	_send_key(main, KEY_T)
	await process_frame
	_assert(first_hand.cards.size() == 8, "Expected debug T to show a full event-card debug hand")
	_assert(_all_cards_match(first_hand.cards, "Event", ""), "Expected debug T hand to contain event cards")
	_assert(_event_types(first_hand.cards).size() == 5, "Expected debug T hand to contain only generated event types")

	_send_key(main, KEY_ENTER)
	await process_frame
	_assert(main.find_child("Shop", true, false) != null, "Expected debug Enter to open the between-level shop")
	_assert((first_level.get_node("Player") as GamePlayer).grid_position == (first_level.get_node("Map") as GameMap).get_goal_position(), "Expected debug Enter to use the normal goal completion state")

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


func _all_cards_match(cards: Array[CardView], category: String, encounter_type: String) -> bool:
	for card in cards:
		if card.category != category:
			return false
		if not encounter_type.is_empty() and str(card.encounter_data.get("type", "")) != encounter_type:
			return false
		if encounter_type.is_empty() and category == "Road" and not card.encounter_data.is_empty():
			return false
	return true


func _count_encounters(cards: Array[CardView], encounter_type: String) -> int:
	var count := 0
	for card in cards:
		if str(card.encounter_data.get("type", "")) == encounter_type:
			count += 1
	return count


func _event_types(cards: Array[CardView]) -> Dictionary:
	var event_types := {}
	for card in cards:
		event_types[card.event_type] = true
	return event_types


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
