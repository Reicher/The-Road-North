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
	var remove_button := shop.find_child("RemoveButton", true, false) as Button
	var view_deck_button := shop.find_child("ViewDeckButton", true, false) as Button
	var title := shop.find_child("Title", true, false) as Label
	var cards_title := shop.find_child("CardsTitle", true, false) as Label
	var deck_section_title := shop.find_child("DeckTitle", true, false) as Label
	var inventory_slots := shop._slot_row as HBoxContainer
	var item_row := shop._item_row as HBoxContainer
	var food_row := shop._food_offer_row as HBoxContainer
	var life_row := shop._life_offer_row as HBoxContainer
	var card_row := shop.find_child("CardOffers", true, false) as HBoxContainer
	var deck_row := remove_button.get_parent() as HBoxContainer
	var summary_panel := shop.find_child("SummaryPanel", true, false) as PanelContainer
	var background := shop.get_node("Background") as Control
	_assert(shop.size.is_equal_approx(get_root().get_visible_rect().size), "Expected shop root to fill the viewport")
	_assert(background != null and not (background is TextureRect) and background.has_method("set_shelf_nodes"), "Expected the shop background to be drawn dynamically from shelf layout instead of a fixed image")
	_assert(title.get_theme_font_size("font_size") >= 44 and title.get_theme_constant("outline_size") >= 4, "Expected the shop title to stay readable on the wood background")
	_assert((shop._gold_chip.get_node("Value") as Label).get_theme_font_size("font_size") >= 31, "Expected shop resource numbers to be larger and readable")
	_assert((shop._gold_chip.get_node("Value") as Label).get_theme_constant("outline_size") >= 4, "Expected shop resource numbers to use a dark outline")
	_assert(shop_scroll.size.x > shop.size.x * 0.9 and shop_scroll.size.y > shop.size.y * 0.9, "Expected shop scroll area to use nearly the full screen")
	_assert(shop_stack.size.x > shop_scroll.size.x * 0.9, "Expected shop controls to expand across the available width")
	_assert(shop._shop_margin.get_combined_minimum_size().y <= shop_scroll.size.y, "Expected the complete shop to fit the 720x1280 Android viewport without vertical scrolling")
	_assert(play_button.global_position.y > shop.size.y * 0.75, "Expected Play next map to use the lower part of a tall screen")
	_assert(play_button.custom_minimum_size.y >= 72.0 and play_button.has_theme_stylebox_override("normal"), "Expected Play next map to remain visible as a styled bottom button")
	_assert(remove_button.custom_minimum_size.y == 56.0 and view_deck_button.custom_minimum_size.y == 56.0, "Expected deck buttons to keep a fixed normal height")
	_assert(remove_button.size_flags_vertical == Control.SIZE_SHRINK_CENTER and view_deck_button.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Expected deck buttons not to stretch vertically")
	_assert(summary_panel != null, "Expected a styled summary panel")
	_assert(inventory_slots.get_child_count() == 1, "Expected the inventory row to render only carried items so a single item can be centered")
	_assert(inventory_slots.alignment == BoxContainer.ALIGNMENT_CENTER, "Expected carried items to stay centered for one, two, or three visible items")
	_assert(_slot_button(inventory_slots, 0).custom_minimum_size.is_equal_approx(shop.SLOT_SIZE), "Expected inventory entries to use inventory-sized slots")
	_assert(_price_text(inventory_slots, 0).begins_with("+"), "Expected sellable equipment to show its sale value behind the item")
	_assert((inventory_slots.get_child(0).get_node("OverlapPrice") as Control).position.y == 70.0, "Expected equipment prices to share the item's bottom edge")
	_assert(_nested_label_index(shop_stack, "Sellable equipment") >= 0, "Expected the compact sellable equipment row label")
	_assert(_nested_label_index(shop_stack, "Item shop") >= 0, "Expected the compact item shop row label")
	for shelf_name in ["SellableRowShelf", "ItemRowShelf", "FoodRowShelf", "LifeRowShelf", "CardsSectionShelf", "DeckSectionShelf"]:
		var shelf := shop.find_child(shelf_name, true, false) as PanelContainer
		_assert(shelf != null and shelf.has_theme_stylebox_override("panel"), "Expected %s to be framed as a shelf" % shelf_name)
	_assert(inventory_slots.get_parent().size_flags_vertical == Control.SIZE_EXPAND_FILL, "Expected compact shop rows to participate in even vertical distribution")
	_assert(shop.find_child("SellBuySeparator", true, false) == null, "Expected the sellable shelf edge to replace the separate divider")
	_assert(item_row.get_child_count() == InventoryUI.SLOT_COUNT, "Expected buyable items to render in the same number of slots as the inventory")
	_assert(item_row.alignment == BoxContainer.ALIGNMENT_CENTER, "Expected one, two, or three available item offers to remain centered")
	_assert(_slot_button(item_row, 0).custom_minimum_size.is_equal_approx(shop.SLOT_SIZE), "Expected buyable items to use the same slot size as the inventory")
	_assert(_price_text(item_row, 0).is_valid_int(), "Expected buyable items to show their purchase price behind the item")
	shop._show_sell_item_popup(0)
	var item_popup := shop.get_node("ItemDetailsPopup") as Control
	var item_action := item_popup.get_node("Center/Panel/Margin/Stack/Buttons/ActionButton") as Button
	var item_discard := item_popup.get_node("Center/Panel/Margin/Stack/Buttons/DiscardButton") as Button
	_assert(item_popup.visible and item_action.text.begins_with("Sell"), "Expected a shop inventory item to open details with a sell action")
	_assert(item_discard.visible and not item_discard.disabled, "Expected a shop inventory item to also offer discard")
	item_popup.call("hide_popup")
	shop._show_buy_item_popup(0)
	_assert(item_popup.visible and item_action.text.begins_with("Buy"), "Expected a shop offer to open details with a buy action")
	_assert(not item_discard.visible, "Expected unowned shop offers not to show discard")
	item_popup.call("hide_popup")
	_assert(food_row.get_child_count() == 3, "Expected three food offers")
	_assert(life_row.get_child_count() == 2, "Expected two life offers")
	var bread_offer := food_row.get_child(0) as Button
	var bandage_offer := life_row.get_child(0) as Button
	_assert(bread_offer.custom_minimum_size.x > shop.SLOT_SIZE.x, "Expected the food click target to include the price at the item's right edge")
	_assert((bread_offer.get_node("FloatingArt") as TextureRect).texture != null, "Expected bread to use its dedicated transparent artwork")
	_assert((bread_offer.get_node("TopPrice/PriceLabel") as Label).text == "1", "Expected the food price along the offer's upper edge")
	_assert((bandage_offer.get_node("FloatingArt") as TextureRect).texture != null, "Expected bandage to use its dedicated transparent artwork")
	_assert((bandage_offer.get_node("TopPrice/PriceLabel") as Label).text == "1", "Expected the life price along the offer's upper edge")
	_assert((shop.find_child("FoodLift", true, false) as MarginContainer).get_theme_constant("margin_bottom") == 16, "Expected the complete Food row to sit higher in its shelf")
	_assert((shop.find_child("LifeLift", true, false) as MarginContainer).get_theme_constant("margin_bottom") == 26, "Expected the complete Life row to sit higher in its shelf")
	_assert((bread_offer.get_node("TopPrice") as Control).z_index > (bread_offer.get_node("FloatingArt") as Control).z_index, "Expected floating prices to stay above consumable art")
	_assert((inventory_slots.get_child(0).get_node("OverlapPrice") as Control).z_index > _slot_button(inventory_slots, 0).z_index, "Expected floating equipment prices to stay above their items")
	var legacy_potion_row := shop.find_child("PotionsRow", true, false) as Control
	_assert(legacy_potion_row != null and not legacy_potion_row.visible, "Expected potions to be hidden from the shop")
	var bottom_spacer := shop.find_child("BottomSpacer", true, false) as Control
	_assert(bottom_spacer != null and not bottom_spacer.visible, "Expected the bottom spacer not to create empty shop space")
	_assert(shop.card_offers.size() == 3, "Expected shop to roll exactly three special card offers")
	_assert(not cards_title.visible, "Expected the card shelf to rely on the cards instead of a separate Cards heading")
	_assert(cards_title.get_parent() == card_row.get_parent(), "Expected the Cards title to stay grouped with the card offers")
	_assert(deck_section_title.get_parent() == deck_row.get_parent(), "Expected the Deck title to stay grouped with the deck buttons")
	_assert(not deck_section_title.visible, "Expected the deck actions to have no separate Deck heading")
	_assert(remove_button.custom_minimum_size.x == 240.0 and view_deck_button.custom_minimum_size.x == 240.0, "Expected narrower inset deck buttons")
	_assert(deck_row.get_theme_constant("separation") == 32, "Expected more space between the two deck actions")
	_assert(cards_title.get_parent().size_flags_vertical == Control.SIZE_EXPAND_FILL, "Expected Cards section to keep its group while sharing vertical space")
	_assert(deck_section_title.get_parent().size_flags_vertical == Control.SIZE_EXPAND_FILL, "Expected Deck section to keep its group while sharing vertical space")
	_assert(_offer_types_are_unique(shop.card_offers), "Expected shop special-card offers not to contain duplicate card types")
	_assert(_catalog_has_shop_only_specials(), "Expected the requested shop-only special cards to be purchasable")
	_assert(_all_offers_are_cheaper_specials(shop.card_offers), "Expected every rolled card to come from the cheaper special-card catalog")
	_assert(card_row.get_child_count() == 3, "Expected all three rolled special cards to render in the shop")
	_assert(card_row.size.y >= shop.CARD_OFFER_SIZE.y, "Expected special cards to have the same visible size as cards in hand")
	for offer_node in card_row.get_children():
		var card := offer_node.get_node("Card") as CardView
		_assert(card != null and card.size.is_equal_approx(shop.CARD_OFFER_SIZE), "Expected shop offers to use the compact shop CardView size")
		_assert(card.hand_presentation, "Expected shop cards to use exactly the same titles and layout rules as cards in hand")
		_assert(card.category in [GameConstants.EVENT_CATEGORY, GameConstants.ROAD_CATEGORY], "Expected shop CardView to show special event or special road data")
		_assert(card.card_base_texture_path == CardView.DEFAULT_CARD_BASE_TEXTURE_PATH, "Expected shop cards to use the same painted card design as gameplay")
		_assert(offer_node.get_node_or_null("CardPrice") == null, "Expected no price symbol or number beside shop cards")
		_assert((offer_node.get_node("BuyButton") as Button).text.is_empty(), "Expected cards to use one invisible full-offer click target instead of a separate buy button")
	(card_row.get_child(0).get_node("BuyButton") as Button).pressed.emit()
	var card_popup := shop.find_child("CardOfferPopup", true, false) as Control
	_assert(card_popup != null and card_popup.visible, "Expected tapping a shop card to open its details popup")
	_assert(shop._card_offer_detail.text == str(shop.card_offers[0].get("detail", "")), "Expected the popup to explain what the special card does")
	_assert(shop._card_offer_cost.text == "Cost: %dg" % int(shop.card_offers[0]["price"]), "Expected the card price only inside the popup")
	shop.call("_hide_card_offer_popup")

	shop.call("_show_deck_overlay", true)
	var deck_overlay := shop.find_child("DeckOverlay", true, false) as DeckOverlay
	_assert(deck_overlay.z_index > 2, "Expected the deck overlay to cover every floating shop item and consumable")
	var deck_title := deck_overlay.find_child("Title", true, false) as Label
	var deck_grid := deck_overlay.find_child("Grid", true, false) as GridContainer
	_assert(deck_title.text == "REMOVE CARD", "Expected the removal overlay to use a clear, polished title")
	_assert(deck_title.get_theme_color("font_color").is_equal_approx(Color(0.2, 0.14, 0.09, 1)), "Expected the deck title to contrast with the light panel")
	_assert(deck_grid.columns == 4, "Expected the deck overview to show more than three cards per row")
	_assert(deck_grid.get_child_count() == 7, "Expected the deck overview to show one visual card per card copy")
	_assert(_overview_card_titles(deck_grid) == ["Straight Road", "Straight Road", "Corner", "Four-Way Intersection", "Dead End", "Dead End", "Idea"], "Expected individual base cards to keep the requested type order")
	var straight_overview_card := deck_grid.get_child(0).get_node("Card") as CardView
	_assert(straight_overview_card.custom_minimum_size.x < CardView.DISPLAY_CARD_SIZE.x, "Expected overview cards to be compact enough for four-card rows")
	straight_overview_card.pointer_released.emit(straight_overview_card, Vector2.ZERO)
	var confirmation_shade := deck_overlay.find_child("ConfirmationShade", true, false) as Control
	var confirmation_prompt := deck_overlay.find_child("Prompt", true, false) as Label
	_assert(straight_overview_card.focused and straight_overview_card.scale.x > 1.0, "Expected tapping a removable deck card to focus it before confirming")
	_assert(confirmation_shade.visible and confirmation_prompt.text == "Remove Straight Road from the deck for 12g?", "Expected tapping a removable card to ask for confirmation with its price")
	_assert(shop.progression.get("player_removed_base_cards", []).is_empty(), "Expected tapping a card not to remove it before confirmation")
	(deck_overlay.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	_assert(shop.progression["player_removed_base_cards"] == ["road:Straight Road"], "Expected confirming the popup to remove the selected card")

	shop.call("_confirm_buy_food", {"name": "Bread", "amount": 1, "price": 1})
	var shop_confirmation := shop.find_child("ShopConfirmation", true, false) as Control
	var shop_confirmation_prompt := shop_confirmation.find_child("Prompt", true, false) as Label
	_assert(shop_confirmation.visible, "Expected buy and sell actions to use the readable shop confirmation overlay")
	_assert(shop_confirmation_prompt.get_theme_font_size("font_size") >= 27, "Expected the shop confirmation prompt to use large readable text")
	_assert(shop_confirmation_prompt.text == "Buy Bread: +1 food for 1g?", "Expected shop confirmation to show the purchase details")
	(shop_confirmation.find_child("CancelButton", true, false) as Button).pressed.emit()
	_assert(not shop_confirmation.visible, "Expected cancel to close the shop confirmation overlay")

	_assert(shop.buy_food() and shop.progression["food"] == 7, "Expected food click purchase to add food immediately")
	_assert(shop.buy_heal() and shop.progression["health"] == 4, "Expected heal click purchase to clamp at max health")
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
	_assert(deck.deck_components[DeckBuilder.DECK_SOURCE_BASE].size() == DeckBuilder.DEFAULT_DECK_RECIPES.base_card_count() - 1, "Expected a deck modifier to remove one BaseDeck card without changing the recipe")
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


func _nested_label_index(parent: Node, text: String) -> int:
	for index in parent.get_child_count():
		var child := parent.get_child(index)
		var label := child as Label
		if label != null and label.text == text:
			return index
		var nested := _nested_label_index(child, text)
		if nested >= 0:
			return index
	return -1


func _slot_button(row: HBoxContainer, index: int) -> Button:
	for child in row.get_child(index).get_children():
		if child is Button:
			return child as Button
	return null


func _price_text(row: HBoxContainer, index: int) -> String:
	var chip := row.get_child(index).get_node_or_null("OverlapPrice") as HBoxContainer
	var label := chip.get_node_or_null("PriceLabel") as Label
	return label.text if label != null else ""


func _overview_card_titles(parent: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in parent.get_children():
		texts.append((child.get_node("Card/Title") as Label).text)
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
