extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main := MAIN_SCENE.instantiate()
	get_root().add_child(main)
	await process_frame

	var start_screen := main.get_node("StartScreen") as StartScreen
	_assert(start_screen != null, "Expected the game to open on the start screen")
	_assert(main.get_node_or_null("Level") == null, "Expected level 1 to wait for Play or debug mode")
	_assert((start_screen.get_node("AuthorLabel") as Label).text == "A game by Robin Reicher", "Expected the splash credit")
	_assert((start_screen.get_node("Content/Title") as Label).text == "Road to Karlskoga", "Expected the working title")
	var intro_click := InputEventMouseButton.new()
	intro_click.button_index = MOUSE_BUTTON_LEFT
	intro_click.pressed = true
	start_screen._input(intro_click)
	_assert(not (start_screen.get_node("AuthorLabel") as Label).visible, "Expected a desktop click to skip the splash credit")
	_assert((start_screen.get_node("Content/MenuButtons/PlayButton") as Button).text == "Play", "Expected a Play button")
	_assert((start_screen.get_node("Content/MenuButtons/HowToPlayButton") as Button).text == "How to play", "Expected a How to play button")
	_assert((start_screen.get_node("Content/MenuButtons/SettingsButton") as Button).text == "Settings", "Expected a Settings button")
	_assert((start_screen.get_node("Content/MenuButtons/AboutButton") as Button).text == "About the game", "Expected an About the game button")
	var start_title := start_screen.get_node("Content/Title") as Label
	var title_position_before_information := start_title.global_position
	_assert(is_equal_approx(start_title.get_global_rect().get_center().x, start_screen.get_viewport_rect().get_center().x), "Expected the game title to be horizontally centered on the screen")
	(start_screen.get_node("Content/MenuButtons/SettingsButton") as Button).pressed.emit()
	await process_frame
	_assert(not (start_screen.get_node("Content/MenuButtons") as VBoxContainer).visible, "Expected information to replace the menu buttons")
	_assert((start_screen.get_node("Content/Information") as PanelContainer).visible, "Expected information to appear in the main layout")
	var information_heading := start_screen.get_node("Content/Information/Margin/Stack/Heading") as Label
	_assert(start_title.visible, "Expected the game title to remain visible")
	_assert(start_title.global_position.is_equal_approx(title_position_before_information), "Expected the game title to remain fixed when information content changes")
	_assert(information_heading.get_global_rect().position.y >= start_title.get_global_rect().end.y, "Expected information headings to remain below the game title: title=%s heading=%s" % [start_title.get_global_rect(), information_heading.get_global_rect()])
	(start_screen.get_node("Content/Information/Margin/Stack/BackButton") as Button).pressed.emit()
	(start_screen.get_node("Content/MenuButtons/PlayButton") as Button).pressed.emit()
	await process_frame
	var expedition_popup := main.get_node("ExpeditionNamePopup") as CanvasLayer
	_assert(expedition_popup != null, "Expected Play to ask for an expedition name")
	_assert((expedition_popup.get_node("Dimmer/Panel/Margin/Stack/NameEdit") as LineEdit).text == "Räsers", "Expected expedition name to default to Räsers")
	(expedition_popup.get_node("Dimmer/Panel/Margin/Stack/ButtonRow/BeginButton") as Button).pressed.emit()
	await process_frame
	_assert(main.get_node_or_null("StartScreen") == null, "Expected Play to leave the start screen")

	var first_level := main.get_node("Level")
	var first_map := first_level.get_node("Map") as GameMap
	var first_player := first_level.get_node("Player") as GamePlayer
	var first_screen := first_level.get_node("UI/GameOver") as GameOverUI
	var first_hand := first_level.get_node("UI/Hand") as HandUI
	_assert(first_map.playable_width == 5 and first_map.playable_height == 5, "Expected the game to start on the 5x5 level")
	var debug_label := main.get_node("DebugOverlay/DebugLabel") as Label
	_assert(debug_label != null, "Expected main scene to create a debug label")
	_assert(not debug_label.visible, "Expected debug mode to start disabled")

	_send_key(main, KEY_2)
	await process_frame
	_assert(main.get_node("Level") == first_level, "Expected level shortcuts to do nothing before debug mode is enabled")
	_send_key(main, KEY_ENTER)
	await process_frame
	_assert(not first_screen.visible, "Expected Enter to do nothing before debug mode is enabled")

	var level_before_debug := first_level
	_send_key(main, KEY_D)
	await process_frame
	first_level = main.get_node("Level")
	first_map = first_level.get_node("Map") as GameMap
	first_player = first_level.get_node("Player") as GamePlayer
	first_screen = first_level.get_node("UI/GameOver") as GameOverUI
	first_hand = first_level.get_node("UI/Hand") as HandUI
	_assert(debug_label.visible, "Expected D to enable debug mode")
	_assert(debug_label.text == "Debug", "Expected debug mode to show a clear Debug label")
	_assert(first_level != level_before_debug, "Expected entering debug mode to restart at level 1")
	_assert(first_map.playable_width == 5 and first_map.playable_height == 5, "Expected D to start level 1")

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

	_send_key(main, KEY_3)
	await process_frame
	var debug_third_level := main.get_node("Level")
	_assert((debug_third_level.get_node("Map") as GameMap).playable_width == 9, "Expected debug key 3 to load the third level")
	_send_key(main, KEY_4)
	await process_frame
	var debug_fourth_level := main.get_node("Level")
	_assert(debug_fourth_level != debug_third_level and (debug_fourth_level.get_node("Map") as GameMap).playable_width == 7, "Expected debug key 4 to load the fourth level")

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
	first_inventory.replace_item_at_slot(0, {"name": "Machete", "effect": "+4 Power", "stats": {"power": 4}, "size": "large"})
	_assert(first_inventory.add_item({"name": "Guiding Charm", "effect": "+1 Max Hand Size", "stats": {"max_hand_size": 1}, "size": "small"}), "Expected a small progression test item to fit beside the large item")

	first_player.grid_position = first_map.get_goal_position()
	_assert(first_player.check_run_won(), "Expected reaching the first goal to complete the level")
	var shop := main.find_child("Shop", true, false) as Control
	_assert(shop != null, "Expected the shop to open immediately after the first goal")
	_assert((main.get_node("TransitionLayer/ForestFade/TransitionLabel") as Label).text == "Road complete!\n+5 Gold", "Expected level completion transition to show the shop gold reward")
	_assert((shop.get_parent() as CanvasLayer).layer == 50, "Expected shop to render above all level UI")
	_assert(not (first_level.get_node("UI") as CanvasLayer).visible, "Expected resource stats and backpack UI to hide while the shop is open")
	_assert(not first_screen.is_visible_in_tree(), "Expected the shop to replace the completion prompt between levels")
	_assert(not first_hand.visible, "Expected the card hand to hide on the completion screen")
	_assert(shop.next_map_name == "Twin Crossings" and shop.next_map_size == 7, "Expected shop to describe the next map")

	(shop.find_child("PlayNextButton", true, false) as Button).pressed.emit()
	await process_frame

	var second_level := main.get_node("Level")
	var second_map := second_level.get_node("Map") as GameMap
	var second_player := second_level.get_node("Player") as GamePlayer
	var second_screen := second_level.get_node("UI/GameOver") as GameOverUI
	_assert(second_map.playable_width == 7 and second_map.playable_height == 7, "Expected Next level to load the 7x7 map")
	_assert(second_player.food == 4, "Expected food to carry into the next level without a new starting grant")
	_assert(second_player.gold == 12, "Expected shop entry bonus gold to carry into the next level")
	_assert(second_player.health == 4 and second_player.max_health == 5, "Expected current and max health to carry into the next level")
	_assert(second_player.base_power == 2 and second_player.get_total_power() == 6, "Expected base power and carried item stats to carry into the next level")
	_assert((second_level.get_node("UI/Inventory") as InventoryUI).get_carried_items().size() == 2, "Expected backpack items to carry into the next level")
	var second_stats := second_level.get_node("UI/PlayerStats") as PlayerStatsUI
	_assert(_feedback_values_are_zero(second_stats._gain_amounts), "Expected progression restore not to show resource gain or loss amounts")
	_assert(_feedback_values_are_zero(second_stats._pulse_strength), "Expected progression restore not to pulse stats at level start")

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
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/Title").text == "The Räsers Expedition", "Expected loss report title")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/Reward").text == "Collapsed in the wilderness", "Expected loss report to explain death")
	_assert(second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").text == "New Expedition", "Expected loss button to start a new expedition")
	second_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").pressed.emit()
	await process_frame

	var loss_expedition_popup := main.get_node("ExpeditionNamePopup") as CanvasLayer
	_assert(loss_expedition_popup != null, "Expected losing to ask for a fresh expedition name")
	(loss_expedition_popup.get_node("Dimmer/Panel/Margin/Stack/ButtonRow/BeginButton") as Button).pressed.emit()
	await process_frame

	second_level = main.get_node("Level")
	second_map = second_level.get_node("Map") as GameMap
	second_player = second_level.get_node("Player") as GamePlayer
	second_screen = second_level.get_node("UI/GameOver") as GameOverUI
	second_hand = second_level.get_node("UI/Hand") as HandUI
	_assert(second_map.playable_width == 5 and second_map.playable_height == 5, "Expected losing to restart from level 1")
	_assert(second_player.gold == 0 and second_player.max_health == 4 and second_player.base_power == 0, "Expected losing to reset run progression")

	second_player.grid_position = second_map.get_goal_position()
	_assert(second_player.check_run_won(), "Expected reaching the first goal after loss to complete the level")
	var second_shop := main.find_child("Shop", true, false) as Control
	_assert(second_shop != null, "Expected the shop to open before level 2")
	(second_shop.find_child("PlayNextButton", true, false) as Button).pressed.emit()
	await process_frame

	second_level = main.get_node("Level")
	second_map = second_level.get_node("Map") as GameMap
	second_player = second_level.get_node("Player") as GamePlayer
	_assert(second_map.playable_width == 7 and second_map.playable_height == 7, "Expected the first shop after loss to load the second map")
	second_player.grid_position = second_map.get_goal_position()
	_assert(second_player.check_run_won(), "Expected reaching the second goal after loss to complete the level")
	var third_shop := main.find_child("Shop", true, false) as Control
	_assert(third_shop != null, "Expected the shop to open before level 3")
	(third_shop.find_child("PlayNextButton", true, false) as Button).pressed.emit()
	await process_frame

	var third_level := main.get_node("Level")
	var third_map := third_level.get_node("Map") as GameMap
	var third_player := third_level.get_node("Player") as GamePlayer
	_assert(third_map.playable_width == 9 and third_map.playable_height == 9, "Expected the second shop to load the third map")
	third_player.grid_position = third_map.get_goal_position()
	_assert(third_player.check_run_won(), "Expected reaching the third goal to complete the level")
	_assert(main.find_child("Shop", true, false) != null, "Expected the shop to open after level 3 because the run now has ten levels")

	_send_key(main, KEY_0)
	await process_frame
	var final_level := main.get_node("Level")
	var final_map := final_level.get_node("Map") as GameMap
	var final_player := final_level.get_node("Player") as GamePlayer
	var final_screen := final_level.get_node("UI/GameOver") as GameOverUI
	var final_hand := final_level.get_node("UI/Hand") as HandUI
	_assert(final_map.playable_width == 11 and final_map.playable_height == 11, "Expected debug key 0 to load the tenth and final map")
	final_player.grid_position = final_map.get_goal_position()
	_assert(final_player.check_run_won(), "Expected reaching the final goal to complete the game")
	_assert(final_screen.visible, "Expected the final win screen to show")
	_assert(not final_hand.visible, "Expected the card hand to hide on the final win screen")
	_assert(final_screen.get_node("Prompt/ContentMargin/Stack/Title").text == "The Räsers Expedition", "Expected final win report title")
	_assert(final_screen.get_node("Prompt/ContentMargin/Stack/Reward").text == "Reached the final road", "Expected final report victory text")
	_assert(final_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").text == "New Expedition", "Expected final report to offer a fresh expedition")
	_assert(not final_screen.get_node("Prompt/ContentMargin/Stack/NewExpeditionButton").visible, "Expected final report to avoid replaying the final level")

	final_screen.get_node("Prompt/ContentMargin/Stack/RestartButton").pressed.emit()
	await process_frame
	var new_expedition_popup := main.get_node("ExpeditionNamePopup") as CanvasLayer
	_assert(new_expedition_popup != null, "Expected New Expedition to ask for a fresh expedition name")
	(new_expedition_popup.get_node("Dimmer/Panel/Margin/Stack/ButtonRow/BeginButton") as Button).pressed.emit()
	await process_frame

	var restarted_map := main.get_node("Level/Map") as GameMap
	var restarted_player := main.get_node("Level/Player") as GamePlayer
	_assert(restarted_map.playable_width == 5 and restarted_map.playable_height == 5, "Expected New Expedition to return to the first level")
	_assert(restarted_player.gold == 0 and restarted_player.max_health == 4 and restarted_player.base_power == 0, "Expected New Expedition to reset progression to initial values")

	main.queue_free()
	await process_frame
	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _feedback_values_are_zero(values: Dictionary) -> bool:
	for value in values.values():
		if absf(float(value)) > 0.001:
			return false
	return true


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
