extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const HAND_SCENE := preload("res://ui/hand.tscn")
const INVENTORY_SCENE := preload("res://ui/inventory.tscn")
const DECK_CONTROLLER_SCENE := preload("res://scenes/deck_controller.tscn")
const ItemCatalog := preload("res://scripts/item_catalog.gd")
const ItemIconLibrary := preload("res://scripts/item_icon_library.gd")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
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

	var inventory := INVENTORY_SCENE.instantiate() as InventoryUI
	inventory.name = "Inventory"
	ui.add_child(inventory)

	var deck := DECK_CONTROLLER_SCENE.instantiate() as DeckController
	deck.name = "DeckController"
	deck.map_path = NodePath("../Map")
	deck.hand_path = NodePath("../UI/Hand")
	deck.inventory_path = NodePath("../UI/Inventory")
	deck.shuffle_seed = 6122026
	root.add_child(deck)
	await process_frame
	deck.start_run()

	var guiding_charm := ItemCatalog.get_item("Guiding Charm")
	_assert(not guiding_charm.is_empty(), "Expected Guiding Charm to be available as item loot")
	_assert(ItemIconLibrary.get_icon(guiding_charm) != null, "Expected Guiding Charm to have an item icon")
	_assert(hand.cards.size() == 4, "Expected the normal opening hand to contain four cards")
	_assert(inventory.add_item(guiding_charm), "Expected adding Guiding Charm to an empty slot to succeed")
	_assert(deck.get_minimum_hand_size() == 5, "Expected Guiding Charm to increase minimum hand size by one")
	_assert(hand.cards.size() == 5, "Expected acquiring Guiding Charm to immediately refill the hand")
	inventory.replace_item_at_slot(1, {})
	_assert(deck.get_minimum_hand_size() == 4, "Expected removing Guiding Charm to restore normal minimum hand size")
	_assert(hand.cards.size() == 5, "Expected removing Guiding Charm not to discard an extra held card")

	var shop := ShopUI.new()
	var charm_seen := false
	for _roll in 100:
		shop._roll_item_offers()
		_assert(shop.item_offers.size() == ShopUI.ITEM_OFFER_COUNT, "Expected the shop to keep exactly two item offers")
		for offer in shop.item_offers:
			if offer.get("name", "") == "Guiding Charm":
				charm_seen = true
	_assert(charm_seen, "Expected Guiding Charm to be obtainable from random shop item offers")
	shop.free()

	var purchase_shop := ShopUI.new()
	purchase_shop.progression = {"gold": 20, "inventory": [{}, {}, {}]}
	purchase_shop.item_offers = [ShopUI.ITEM_OFFER_CATALOG[2].duplicate(true)]
	_assert(purchase_shop.buy_item_to_slot(0, 0), "Expected Guiding Charm to be purchasable from a shop offer")
	_assert(purchase_shop.progression["inventory"][0].get("name", "") == "Guiding Charm", "Expected a purchased Guiding Charm to enter the backpack")
	purchase_shop.free()

	root.queue_free()
	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
