extends SceneTree

const SHOP_SCENE := preload("res://ui/shop.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const DEAD_END := preload("res://data/road_dead_end.tres")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var shop := SHOP_SCENE.instantiate() as ShopUI
	get_root().add_child(shop)
	shop.setup({
		"gold": 11,
		"player_special_cards": [
			{"category": "Event", "event_type": GameConstants.EVENT_SLEEP, "title": "Sleep"},
			{"category": "Event", "event_type": GameConstants.EVENT_SLEEP, "title": "Sleep"},
		],
	}, "Next", 7, [
		{"category": "Road", "tile_definition": STRAIGHT},
		{"category": "Road", "tile_definition": STRAIGHT},
		{"category": "Road", "tile_definition": DEAD_END},
	])
	await process_frame
	var remove_button := shop.find_child("RemoveButton", true, false) as Button
	_assert(remove_button.text == "Remove card / 12g" and remove_button.disabled, "Expected card removal to be unavailable without enough gold")
	shop.debug_add_gold(1)
	_assert(not remove_button.disabled, "Expected card removal to unlock when the player can afford it")
	shop.call("_show_deck_overlay", true)
	var overlay := shop.find_child("DeckOverlay", true, false) as DeckOverlay
	var grid := overlay.get_card_grid()
	_assert((overlay.find_child("Title", true, false) as Label).text == "REMOVE CARD", "Expected the removal menu to include all removable cards")
	_assert(_titles(grid) == ["Straight Road", "Dead End", "Sleep"], "Expected special cards in the removal menu")
	_assert((grid.get_child(2).get_node("Count") as Label).text == "×2", "Expected duplicate special cards to be grouped")
	var dead_end_card := grid.get_child(1).get_node("Card") as CardView
	var sleep_card := grid.get_child(2).get_node("Card") as CardView
	sleep_card.pointer_released.emit(sleep_card, Vector2.ZERO)
	_assert((overlay.find_child("Prompt", true, false) as Label).text == "Remove Sleep from the deck for 12g?", "Expected the popup to identify the selected card and price")
	for entry in grid.get_children():
		_assert((entry.get_node("Card/TouchButton") as Button).disabled, "Expected the popup to lock all card interactions")
	dead_end_card.pointer_released.emit(dead_end_card, Vector2.ZERO)
	_assert((overlay.find_child("Prompt", true, false) as Label).text == "Remove Sleep from the deck for 12g?", "Expected later card taps not to replace the active confirmation")
	(overlay.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	_assert(shop.progression["player_special_cards"].size() == 1, "Expected confirmation to remove one special-card copy")
	_assert(shop.progression["player_removed_card_count"] == 1, "Expected special-card removal to increase future removal prices")
	_assert(remove_button.text == "Remove card / 18g" and remove_button.disabled, "Expected the shop to allow only one removal and show the next price")
	grid = overlay.get_card_grid()
	var disabled_card := grid.get_child(0).get_node("Card") as CardView
	disabled_card.pointer_released.emit(disabled_card, Vector2.ZERO)
	_assert(not (overlay.find_child("ConfirmationShade", true, false) as Control).visible, "Expected disabled cards not to reopen the removal popup")
	shop.progression.erase("removed_base_card_this_shop")
	shop.progression["gold"] = 18
	shop.call("_refresh")
	shop.call("_show_deck_overlay", false)
	_assert(_titles(grid) == ["Straight Road", "Dead End", "Sleep"], "Expected special cards in deck overview")
	_assert(overlay.find_child("Footer", true, false) == null, "Expected deck overview not to show the level-card footer")
	var scroll_hint := overlay.find_child("ScrollHint", true, false) as Label
	for index in 12:
		overlay.add_card({"category": "Event", "event_type": "test_%d" % index, "title": "Test %d" % index}, 1, true)
	await process_frame
	_assert(scroll_hint.visible, "Expected overflowing mobile deck views to show a swipe hint")
	var scroll := overlay.find_child("Scroll", true, false) as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await process_frame
	_assert(not scroll_hint.visible, "Expected the swipe hint to disappear at the bottom of the deck")
	shop.queue_free()
	await process_frame
	quit()


func _titles(grid: GridContainer) -> Array[String]:
	var titles: Array[String] = []
	for entry in grid.get_children():
		titles.append((entry.get_node("Card/Title") as Label).text)
	return titles


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
