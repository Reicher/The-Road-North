extends SceneTree

const SHOP_SCENE := preload("res://ui/shop.tscn")
const DECK_CONTROLLER_SCENE := preload("res://scenes/deck_controller.tscn")
const MAP_SCENE := preload("res://scenes/map.tscn")
const HAND_SCENE := preload("res://ui/hand.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const FOUR_WAY := preload("res://data/road_four_way.tres")
const DEAD_END := preload("res://data/road_dead_end.tres")
const ItemCatalog := preload("res://scripts/item_catalog.gd")


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
		"inventory": [{"name": "Walking Stick", "effect": "+1 Power", "power_bonus": 1}, {}, {}],
	}, "2 bridges", 7, [
		{"category": "Road", "tile_definition": DEAD_END},
		{"category": "Road", "tile_definition": STRAIGHT},
		{"category": "Road", "tile_definition": DEAD_END},
		{"category": "Road", "tile_definition": STRAIGHT},
		{"category": "Road", "tile_definition": CORNER},
		{"category": "Road", "tile_definition": FOUR_WAY},
		{"category": "Event", "event_type": GameConstants.EVENT_DRAW_TWO, "title": "Idea"},
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
	_assert(_offer_types_are_unique(shop.card_offers), "Expected shop special-card offers not to contain duplicate card types")
	_assert(_catalog_has_shop_only_specials(), "Expected the requested shop-only special cards to be purchasable")
	_assert(_all_offers_are_cheaper_specials(shop.card_offers), "Expected every rolled card to come from the cheaper special-card catalog")
	_assert(card_row.get_child_count() == 3, "Expected all three rolled special cards to render in the shop")
	_assert(card_row.size.y >= shop.CARD_OFFER_SIZE.y, "Expected special cards to have the same visible size as cards in hand")
	for offer_node in card_row.get_children():
		var card := offer_node.get_node("Card") as CardView
		_assert(card != null and card.size.is_equal_approx(Vector2(174.0, 250.0)), "Expected shop offers to use the in-game CardView at hand size")
		_assert(card.category in [GameConstants.EVENT_CATEGORY, GameConstants.ROAD_CATEGORY], "Expected shop CardView to show special event or special road data")
		_assert(card.card_base_texture_path == CardView.DEFAULT_CARD_BASE_TEXTURE_PATH, "Expected shop cards to use the same painted card design as gameplay")
		_assert((offer_node.get_node("BuyButton") as Button).icon != null, "Expected special card prices to use the gold resource icon")

	shop.call("_show_deck_overlay", true)
	var deck_overlay := shop.find_child("DeckOverlay", true, false) as DeckOverlay
	var deck_title := deck_overlay.find_child("Title", true, false) as Label
	var deck_grid := deck_overlay.find_child("Grid", true, false) as GridContainer
	_assert(deck_title.text == "REMOVE CARD", "Expected the removal overlay to use a clear, polished title")
	_assert(deck_title.get_theme_color("font_color").is_equal_approx(Color(0.2, 0.14, 0.09, 1)), "Expected the deck title to contrast with the light panel")
	_assert(deck_grid.columns == 3, "Expected the deck overview to show three full-size cards per row")
	_assert(deck_grid.get_child_count() == 5, "Expected the deck overview to show one visual card per unique card type")
	_assert(_overview_card_titles(deck_grid) == ["Straight Road", "Corner", "Four-Way Intersection", "Dead End", "Idea"], "Expected grouped base cards to keep the requested type order")
	_assert(_overview_counts(deck_grid) == ["×2", "×1", "×1", "×2", "×1"], "Expected each visual card to show how many copies remain")
	var straight_overview_card := deck_grid.get_child(0).get_node("Card") as CardView
	_assert(straight_overview_card.size.is_equal_approx(CardView.BASE_CARD_SIZE), "Expected overview entries to use the card scene's original size")
	straight_overview_card.pointer_released.emit(straight_overview_card, Vector2.ZERO)
	var confirmation_shade := deck_overlay.find_child("ConfirmationShade", true, false) as Control
	var confirmation_prompt := deck_overlay.find_child("Prompt", true, false) as Label
	_assert(confirmation_shade.visible and confirmation_prompt.text == "Remove Straight Road from the deck for 12g?", "Expected tapping a removable card to ask for confirmation with its price")
	_assert(shop.progression.get("player_removed_base_cards", []).is_empty(), "Expected tapping a card not to remove it before confirmation")
	(deck_overlay.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	_assert(shop.progression["player_removed_base_cards"] == ["road:Straight Road"], "Expected confirming the popup to remove the selected card")

	_assert(shop.buy_food() and shop.progression["food"] == 7, "Expected food click purchase to add food immediately")
	_assert(shop.buy_heal() and shop.progression["health"] == 4, "Expected heal click purchase to clamp at max health")
	_assert(shop.buy_power_potion() and shop.progression["pending_power_bonus"] == 1, "Expected power potion to apply to the next map only")
	_assert(shop.buy_max_health_potion() and shop.progression["pending_max_health_bonus"] == 1, "Expected max HP potion to apply to the next map only")
	shop.item_offers.clear()
	shop.item_offers.append(ItemCatalog.get_item("Guiding Charm").merged({"price": 10, "sell_price": 5}, true))
	shop.item_offers.append(ItemCatalog.get_item("Hatchet").merged({"price": 12, "sell_price": 6}, true))
	_assert(shop.buy_item_to_slot(0, 1), "Expected dragging a small offered item to an empty slot to buy it")
	_assert(not shop.buy_item_to_slot(0, 2), "Expected each item offer to be purchasable only once")
	_assert(not shop.buy_item_to_slot(1, 1), "Expected an item purchase to reject an occupied slot")
	var gold_before_sell := int(shop.progression["gold"])
	_assert(shop.sell_inventory_slot(1), "Expected inventory items to sell through the sell zone")
	_assert(int(shop.progression["gold"]) > gold_before_sell, "Expected selling an item to increase gold")
	shop.progression["inventory"] = [
		{"name": "Goldsmith's Scale", "effect": "Gain twice as much gold.", "gold_multiplier": 2, "sell_price": 4},
		{"name": "Field Medic's Bag", "effect": "+2 Max Health", "max_health_bonus": 2, "sell_price": 4},
		{},
	]
	shop.progression["health"] = 6
	shop.progression["max_health"] = 6
	gold_before_sell = int(shop.progression["gold"])
	_assert(shop.sell_inventory_slot(1), "Expected Field Medic's Bag to be sellable")
	_assert(int(shop.progression["gold"]) == gold_before_sell + 8, "Expected Goldsmith's Scale to double gold gained from selling")
	_assert(shop.progression["health"] == 4 and shop.progression["max_health"] == 4, "Expected selling Field Medic's Bag to remove its health bonus")
	_assert(shop.buy_special_card(0) and shop.buy_special_card(1) and shop.buy_special_card(2), "Expected all three special cards to be purchasable")
	_assert(shop.progression["player_special_cards"].size() == 3, "Expected purchased cards to persist as player special cards")
	_assert(not shop.buy_special_card(0), "Expected each card offer to be purchasable only once")
	_assert(not shop.remove_base_card(0), "Expected one confirmed BaseDeck removal to use the shop's removal allowance")
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
		"category": GameConstants.EVENT_CATEGORY,
		"event_type": GameConstants.EVENT_RESTART_LEVEL,
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


func _overview_card_titles(parent: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in parent.get_children():
		texts.append((child.get_node("Card/Title") as Label).text)
	return texts


func _overview_counts(parent: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in parent.get_children():
		texts.append((child.get_node("Count") as Label).text)
	return texts


func _offer_types_are_unique(cards: Array[Dictionary]) -> bool:
	var seen := {}
	for card in cards:
		var encounter_type := str((card.get("encounter", {}) as Dictionary).get("type", ""))
		var signature := "encounter:%s" % encounter_type if not encounter_type.is_empty() else "event:%s" % str(card.get("event_type", ""))
		if seen.has(signature):
			return false
		seen[signature] = true
	return true


func _all_offers_are_cheaper_specials(cards: Array[Dictionary]) -> bool:
	for card in cards:
		if int(card.get("price", 0)) <= 0 or int(card.get("price", 0)) >= 22:
			return false
		if not _catalog_event_types().has(str(card.get("event_type", ""))):
			return false
	return true


func _catalog_has_shop_only_specials() -> bool:
	var event_types := _catalog_event_types()
	for required_type in [
		GameConstants.EVENT_CLEAR_PATH,
		GameConstants.EVENT_WILD_BERRIES,
		GameConstants.EVENT_LOST_BELONGINGS,
		GameConstants.EVENT_SLEEP,
	]:
		if not event_types.has(required_type):
			return false
	var wild_berries := _catalog_card(GameConstants.EVENT_WILD_BERRIES)
	var lost_belongings := _catalog_card(GameConstants.EVENT_LOST_BELONGINGS)
	return wild_berries.get("encounter", {}).get("type", "") == GameMap.ENCOUNTER_BERRY_BUSH \
		and lost_belongings.get("encounter", {}).get("type", "") == GameMap.ENCOUNTER_CACHE


func _catalog_event_types() -> Dictionary:
	var event_types := {}
	for card in ShopUI.SPECIAL_CARD_CATALOG:
		event_types[str(card.get("event_type", ""))] = true
	return event_types


func _catalog_card(event_type: String) -> Dictionary:
	for card in ShopUI.SPECIAL_CARD_CATALOG:
		if card.get("event_type", "") == event_type:
			return card
	return {}
