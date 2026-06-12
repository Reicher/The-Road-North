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
	_assert(first_map.playable_width == 5 and first_map.playable_height == 5, "Expected the game to start on the 5x5 level")
	var debug_label := main.get_node("DebugOverlay/DebugLabel") as Label
	_assert(debug_label != null, "Expected main scene to create a debug label")
	_assert(not debug_label.visible, "Expected debug label to start hidden")

	_send_key(main, KEY_2)
	await process_frame
	_assert((main.get_node("Level/Map") as GameMap).playable_width == 5, "Expected level shortcuts to do nothing before debug mode is enabled")
	_send_key(main, KEY_ENTER)
	await process_frame
	_assert(not first_screen.visible, "Expected Enter to do nothing before debug mode is enabled")

	_send_key(main, KEY_D)
	await process_frame
	_assert(debug_label.visible, "Expected D to enable debug mode")
	_assert(debug_label.text == "Debug", "Expected debug mode to show a clear Debug label")

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
	_assert(_all_cards_match(first_hand.cards, "Road", GameMap.ENCOUNTER_ENEMY), "Expected debug E hand to contain enemy road cards")

	_send_key(main, KEY_R)
	await process_frame
	_assert(first_hand.cards.size() == 10, "Expected debug R to ignore max hand size and show every road with both reward types")
	_assert(_count_encounters(first_hand.cards, GameMap.ENCOUNTER_BERRY_BUSH) == 5, "Expected debug R hand to include berry roads")
	_assert(_count_encounters(first_hand.cards, GameMap.ENCOUNTER_CACHE) == 5, "Expected debug R hand to include cache roads")

	_send_key(main, KEY_T)
	await process_frame
	_assert(first_hand.cards.size() == 8, "Expected debug T to show a full event-card debug hand")
	_assert(_all_cards_match(first_hand.cards, "Event", ""), "Expected debug T hand to contain event cards")
	_assert(_event_types(first_hand.cards).size() == 5, "Expected debug T hand to contain only generated event types")
	_send_key(main, KEY_ENTER)
	await process_frame
	_assert(main.find_child("Shop", true, false) != null, "Expected debug Enter to open the between-level shop")
	_assert(first_player.grid_position == first_map.get_goal_position(), "Expected debug Enter to use the normal goal completion state")

	_send_key(main, KEY_2)
	await process_frame
	var debug_second_level := main.get_node("Level")
	_assert((debug_second_level.get_node("Map") as GameMap).playable_width == 7, "Expected debug key 2 to load the second level")
	_send_key(main, KEY_2)
	await process_frame
	_assert(main.get_node("Level") != debug_second_level, "Expected debug key 2 to reload the second level when already active")

	_send_key(main, KEY_1)
	await process_frame
	first_level = main.get_node("Level")
	first_map = first_level.get_node("Map") as GameMap
	first_player = first_level.get_node("Player") as GamePlayer
	first_screen = first_level.get_node("UI/GameOver") as GameOverUI
	first_hand = first_level.get_node("UI/Hand") as HandUI
	_assert(first_map.playable_width == 5 and first_map.playable_height == 5, "Expected debug key 1 to load the first level")

	first_player.food = 4
	first_player.gold = 7
	first_player.set_max_health(5)
	first_player.set_health(4)
	first_player.set_base_power(2)
	var first_inventory := first_level.get_node("UI/Inventory") as InventoryUI
	_assert(first_inventory.add_item({"name": "Machete", "effect": "+4 Power", "power_bonus": 4}), "Expected progression test item to fit in backpack")

	first_player.grid_position = first_map.get_goal_position()
	_assert(first_player.check_run_won(), "Expected reaching the first goal to complete the level")
	var shop := main.find_child("Shop", true, false) as Control
	_assert(shop != null, "Expected the shop to open immediately after the first goal")
	_assert((shop.get_parent() as CanvasLayer).layer == 50, "Expected shop to render above all level UI")
	_assert(not (first_level.get_node("UI") as CanvasLayer).visible, "Expected resource stats and backpack UI to hide while the shop is open")
	_assert(not first_screen.is_visible_in_tree(), "Expected the shop to replace the completion prompt between levels")
	_assert(not first_hand.visible, "Expected the card hand to hide on the completion screen")
	_assert(shop.next_map_name == "2 bridges" and shop.next_map_size == 7, "Expected shop to describe the next map")

	(shop.find_child("PlayNextButton", true, false) as Button).pressed.emit()
	await process_frame

	var second_level := main.get_node("Level")
	var second_map := second_level.get_node("Map") as GameMap
	var second_player := second_level.get_node("Player") as GamePlayer
	var second_screen := second_level.get_node("UI/GameOver") as GameOverUI
	_assert(second_map.playable_width == 7 and second_map.playable_height == 7, "Expected Next level to load the 7x7 map")
	_assert(second_player.food == 4, "Expected food to carry into the next level without a new starting grant")
	_assert(second_player.gold == 7, "Expected gold to carry into the next level")
	_assert(second_player.health == 4 and second_player.max_health == 5, "Expected current and max health to carry into the next level")
	_assert(second_player.base_power == 2 and second_player.get_total_power() == 6, "Expected base power and strongest weapon bonus to carry into the next level")
	_assert((second_level.get_node("UI/Inventory") as InventoryUI).get_active_items().size() == 2, "Expected backpack items to carry into the next level")
	var second_stats := second_level.get_node("UI/PlayerStats") as PlayerStatsUI
	_assert(second_stats._gain_amounts.is_empty(), "Expected progression restore not to show resource gain or loss amounts")
	_assert(second_stats._pulse_strength.is_empty(), "Expected progression restore not to pulse stats at level start")

	second_player.food = 1
	var second_deck := second_level.get_node("DeckController") as DeckController
	var second_hand := second_level.get_node("UI/Hand") as HandUI
	second_hand.set_cards([{
		"title": "It was all a dream",
		"detail": "Restart the current level.",
		"category": GameConstants.EVENT_CATEGORY,
		"event_type": GameConstants.EVENT_RESTART_LEVEL,
	}])
	_assert(second_deck.play_immediate_event(second_hand.cards[0]), "Expected dream special card to request a level restart")
	await process_frame
	await process_frame
	var dreamed_level := main.get_node("Level")
	_assert(dreamed_level != second_level, "Expected dream special card to replace the current level instance")
	second_level = dreamed_level
	second_map = second_level.get_node("Map") as GameMap
	second_player = second_level.get_node("Player") as GamePlayer
	second_screen = second_level.get_node("UI/GameOver") as GameOverUI
	_assert(second_player.food == 4, "Expected dream special card to restore the saved level-start resources")

	second_player.set_health(0)
	_assert(second_screen.visible, "Expected loss screen to show on the current level")
	_assert(not (second_level.get_node("UI/Hand") as HandUI).visible, "Expected the card hand to hide on the loss screen")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/Title").text == "You lose", "Expected loss text")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").text == "Restart level", "Expected loss button to restart the current level")
	second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").pressed.emit()
	await process_frame

	second_level = main.get_node("Level")
	second_map = second_level.get_node("Map") as GameMap
	second_player = second_level.get_node("Player") as GamePlayer
	second_screen = second_level.get_node("UI/GameOver") as GameOverUI
	second_hand = second_level.get_node("UI/Hand") as HandUI
	_assert(second_map.playable_width == 7 and second_map.playable_height == 7, "Expected Restart level to reload the current 7x7 level")
	_assert(second_player.food == 4 and second_player.health == 4, "Expected Restart level to restore the resources held at level start")
	_assert((second_level.get_node("UI/Inventory") as InventoryUI).get_active_items().size() == 2, "Expected Restart level to restore the backpack held at level start")

	second_player.grid_position = second_map.get_goal_position()
	_assert(second_player.check_run_won(), "Expected reaching the final goal to complete the game")
	_assert(second_screen.visible, "Expected the final win screen to show")
	_assert(not second_hand.visible, "Expected the card hand to hide on the final win screen")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/Title").text == "You won", "Expected final win text")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").text == "Restart game", "Expected final button to restart the game")

	second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").pressed.emit()
	await process_frame

	var restarted_map := main.get_node("Level/Map") as GameMap
	var restarted_player := main.get_node("Level/Player") as GamePlayer
	_assert(restarted_map.playable_width == 5 and restarted_map.playable_height == 5, "Expected Restart game to return to the first level")
	_assert(restarted_player.gold == 0 and restarted_player.max_health == 4 and restarted_player.base_power == 1, "Expected Restart game to reset progression to initial values")

	main.queue_free()
	await process_frame
	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


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


func _send_key(target: Node, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	target.call("_input", event)
