extends SceneTree

const SHOP_SCENE := preload("res://ui/shop.tscn")
const DECK_CONTROLLER_SCENE := preload("res://scenes/deck_controller.tscn")
const MAP_SCENE := preload("res://scenes/map.tscn")
const HAND_SCENE := preload("res://ui/hand.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var shop := SHOP_SCENE.instantiate() as Control
	get_root().add_child(shop)
	shop.setup({
		"food": 2,
		"gold": 200,
		"health": 2,
		"max_health": 4,
		"base_power": 1,
		"inventory": [{"name": "Knife", "effect": "+1 Power", "power_bonus": 1}, {}, {}],
	}, "3 bridges", 7, [
		{"category": "Road", "tile_definition": STRAIGHT},
		{"category": "Road", "tile_definition": STRAIGHT},
		{"category": "Road", "tile_definition": CORNER},
		{"category": "Event", "event_type": DeckController.EVENT_DRAW_TWO, "title": "Idea"},
	])
	await process_frame
	var shop_scroll := shop.get_node("ShopScroll") as ScrollContainer
	var shop_stack := shop.find_child("ShopStack", true, false) as VBoxContainer
	var play_button := shop.find_child("PlayNextButton", true, false) as Button
	var inventory_title := shop.find_child("InventoryTitle", true, false) as Label
	var card_row := shop.find_child("CardOffers", true, false) as HBoxContainer
	var summary_panel := shop.find_child("SummaryPanel", true, false) as PanelContainer
	var resource_summary := shop.find_child("ResourceSummary", true, false) as HBoxContainer
	_assert(shop.size.is_equal_approx(get_root().get_visible_rect().size), "Expected shop root to fill the viewport")
	_assert(shop_scroll.size.x > shop.size.x * 0.9 and shop_scroll.size.y > shop.size.y * 0.9, "Expected shop scroll area to use nearly the full screen")
	_assert(shop_stack.size.x > shop_scroll.size.x * 0.9, "Expected shop controls to expand across the available width")
	_assert(play_button.global_position.y > shop.size.y * 0.75, "Expected Play next map to use the lower part of a tall screen")
	_assert(inventory_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Expected Inventory title to align with the right-aligned slots")
	_assert(summary_panel != null and resource_summary.get_child_count() == 3, "Expected a styled summary panel with three icon-based player resources")
	for chip in resource_summary.get_children():
		_assert((chip.get_node("Icon") as TextureRect).texture != null, "Expected each player resource summary to use its HUD icon")
	var items_index := _label_index(shop_stack, "ITEMS - DRAG TO EMPTY SLOT")
	var survival_index := _label_index(shop_stack, "SURVIVAL")
	_assert(items_index >= 0 and survival_index >= 0 and items_index < survival_index, "Expected purchasable items immediately after inventory and before survival")
	_assert(shop.card_offers.size() == 3, "Expected shop to roll exactly three special card offers")
	_assert(_all_dream_cards(shop.card_offers), "Expected all three offers to show the only available special card")
	_assert(card_row.get_child_count() == 3, "Expected all three rolled special cards to render in the shop")
	_assert(card_row.size.y >= shop.CARD_OFFER_SIZE.y, "Expected special cards to have the same visible size as cards in hand")
	for offer_node in card_row.get_children():
		var card := offer_node.get_node("Card") as CardView
		_assert(card != null and card.size.is_equal_approx(Vector2(174.0, 250.0)), "Expected shop offers to use the in-game CardView at hand size")
		_assert(card.title == "It was all a dream" and card.category == DeckController.EVENT_CATEGORY, "Expected shop CardView to show the special event data")
		_assert(card.card_base_texture_path == CardView.DEFAULT_CARD_BASE_TEXTURE_PATH, "Expected shop cards to use the same painted card design as gameplay")
		_assert((offer_node.get_node("BuyButton") as Button).icon != null, "Expected special card prices to use the gold resource icon")

	_assert(shop.buy_food() and shop.progression["food"] == 7, "Expected food click purchase to add food immediately")
	_assert(shop.buy_heal() and shop.progression["health"] == 4, "Expected heal click purchase to clamp at max health")
	_assert(shop.buy_power_potion() and shop.progression["pending_power_bonus"] == 1, "Expected power potion to apply to the next map only")
	_assert(shop.buy_max_health_potion() and shop.progression["pending_max_health_bonus"] == 1, "Expected max HP potion to apply to the next map only")
	_assert(shop.buy_item_to_slot(0, 1), "Expected dragging an offered item to an empty slot to buy it")
	_assert(not shop.buy_item_to_slot(0, 2), "Expected each item offer to be purchasable only once")
	_assert(not shop.buy_item_to_slot(1, 1), "Expected an item purchase to reject an occupied slot")
	var gold_before_sell := int(shop.progression["gold"])
	_assert(shop.sell_inventory_slot(1), "Expected inventory items to sell through the sell zone")
	_assert(int(shop.progression["gold"]) > gold_before_sell, "Expected selling an item to increase gold")
	_assert(shop.buy_special_card(0) and shop.buy_special_card(1) and shop.buy_special_card(2), "Expected all three special cards to be purchasable")
	_assert(shop.progression["player_special_cards"].size() == 3, "Expected purchased cards to persist as player special cards")
	_assert(not shop.buy_special_card(0), "Expected each card offer to be purchasable only once")
	_assert(shop.remove_base_card(0), "Expected one removable BaseDeck card to be removable")
	_assert(not shop.remove_base_card(0), "Expected at most one BaseDeck removal per shop")
	_assert(not shop._can_remove_card({"category": "Road", "tile_definition": CORNER}), "Expected the last important road-type copy to be protected")

	var root := Node.new()
	get_root().add_child(root)
	var map := MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)
	var hand := HAND_SCENE.instantiate() as HandUI
	hand.name = "Hand"
	hand.demo_cards_enabled = false
	ui.add_child(hand)
	var deck := DECK_CONTROLLER_SCENE.instantiate() as DeckController
	deck.map_path = NodePath("../Map")
	deck.hand_path = NodePath("../UI/Hand")
	deck.shuffle_seed = 12
	root.add_child(deck)
	deck.set_player_deck_modifiers(["road:Straight Road"], shop.progression["player_special_cards"])
	deck.start_run()
	_assert(deck.deck_components[DeckBuilder.DECK_SOURCE_BASE].size() == 31, "Expected a deck modifier to remove one BaseDeck card without changing the recipe")
	_assert(deck.deck_components[DeckBuilder.DECK_SOURCE_PLAYER_SPECIAL].size() == 3, "Expected special cards to be mixed into each new RunDeck")
	hand.set_cards([{
		"title": "It was all a dream",
		"detail": "Restart the current level.",
		"category": DeckController.EVENT_CATEGORY,
		"event_type": DeckController.EVENT_RESTART_LEVEL,
	}])
	var restart_result := {"count": 0}
	deck.restart_level_requested.connect(func() -> void: restart_result["count"] += 1)
	_assert(deck.play_immediate_event(hand.cards[0]), "Expected dream card to be a playable immediate event")
	_assert(restart_result["count"] == 1, "Expected dream card to request a level restart")

	shop.queue_free()
	root.queue_free()
	await process_frame
	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _label_index(parent: Node, text: String) -> int:
	for index in parent.get_child_count():
		var label := parent.get_child(index) as Label
		if label != null and label.text == text:
			return index
	return -1


func _all_dream_cards(cards: Array[Dictionary]) -> bool:
	for card in cards:
		if card.get("title", "") != "It was all a dream":
			return false
	return true
