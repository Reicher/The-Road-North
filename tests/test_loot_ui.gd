extends SceneTree

const INVENTORY_SCENE := preload("res://ui/inventory.tscn")
const LOOT_SCENE := preload("res://ui/loot.tscn")
const MAP_SCENE := preload("res://scenes/map.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ItemCatalog := preload("res://scripts/item_catalog.gd")


func _initialize() -> void:
	var root := Control.new()
	root.size = Vector2(360.0, 640.0)
	get_root().add_child(root)

	var map = MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var player = PLAYER_SCENE.instantiate() as GamePlayer
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.starting_food = 2
	player.starting_gold = 1
	root.add_child(player)
	player._ready()

	var inventory = INVENTORY_SCENE.instantiate() as InventoryUI
	inventory.name = "Inventory"
	root.add_child(inventory)
	inventory._ready()

	var loot_ui = LOOT_SCENE.instantiate() as LootUI
	loot_ui.name = "Loot"
	loot_ui.player_path = NodePath("../Player")
	loot_ui.inventory_path = NodePath("../Inventory")
	root.add_child(loot_ui)
	loot_ui._ready()
	(player.get_node("Rewards") as PlayerRewards).setup(player, inventory, loot_ui, map)

	var item_popup := inventory.get_node("ItemDetailsPopup") as ItemDetailsPopup
	var popup_name := item_popup.get_node("Center/Panel/Margin/Stack/Header/Heading/ItemName") as Label
	var popup_meta := item_popup.get_node("Center/Panel/Margin/Stack/Header/Heading/Meta") as Label
	var popup_close := item_popup.get_node("Center/Panel/Margin/Stack/Buttons/CloseButton") as Button
	var popup_action := item_popup.get_node("Center/Panel/Margin/Stack/Buttons/ActionButton") as Button
	var popup_discard := item_popup.get_node("Center/Panel/Margin/Stack/Buttons/DiscardButton") as Button
	var popup_shade := item_popup.get_node("Shade") as ColorRect
	var loot_panel := loot_ui.get_node("LootPanel") as PanelContainer

	loot_ui.open_loot([
		{
			"kind": "item",
			"item": ItemCatalog.get_item("Binoculars"),
		},
	])
	await process_frame
	_assert(loot_ui.is_open(), "Expected item loot to keep the loot flow open")
	_assert(inventory.is_open(), "Expected item loot to open the backpack for pickup choices")
	_assert(not loot_panel.visible, "Expected item loot to use the item details popup instead of a separate loot panel")
	_assert(item_popup.visible, "Expected found item loot to open the shared item details popup")
	_assert(popup_name.text == "Binoculars", "Expected the found item popup to show the item name")
	_assert(popup_meta.text.contains("Found item"), "Expected found item popup to say the item was found")
	_assert(popup_close.text == "Ignore", "Expected found item popup to offer ignoring the item")
	_assert(popup_action.text == "Take" and not popup_action.disabled, "Expected found item popup to offer taking the item when it fits")
	_assert(not popup_discard.visible, "Expected unowned found item details not to show discard")
	_assert(loot_ui.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Expected active loot flow not to block inventory input behind the found item popup")
	_assert(item_popup.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Expected found item popup root not to block inventory input outside its panel")
	_assert(not popup_shade.visible and popup_shade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Expected found item popup not to block inventory clicks behind it")
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(8.0, 8.0)
	item_popup.call("_on_shade_input", outside_click)
	_assert(loot_ui.is_open() and item_popup.visible, "Expected outside clicks not to ignore or lose found loot")
	popup_action.pressed.emit()
	_assert(not loot_ui.is_open(), "Expected taking the only found item to close the loot flow")
	_assert(inventory.get_carried_items().size() == 2, "Expected Take to add the found item to the backpack")
	_assert(inventory.get_sight_bonus() == 1, "Expected the taken item to apply its stats")

	loot_ui.open_loot([
		{
			"kind": "item",
			"item": ItemCatalog.get_item("Dagger"),
		},
	])
	await process_frame
	_assert(item_popup.visible and popup_name.text == "Dagger", "Expected a new found item popup to appear")
	popup_close.pressed.emit()
	_assert(not loot_ui.is_open(), "Expected Ignore to close when it discards the only found item")
	_assert(inventory.get_carried_items().size() == 2, "Expected Ignore not to add the found item")

	inventory.set_items([
		ItemCatalog.get_item("Walking Stick"),
		ItemCatalog.get_item("Binoculars"),
		ItemCatalog.get_item("Dagger"),
	])
	loot_ui.open_loot([
		{
			"kind": "item",
			"item": ItemCatalog.get_item("Guiding Charm"),
		},
	])
	await process_frame
	_assert(item_popup.visible and popup_name.text == "Guiding Charm", "Expected full-backpack loot to show the found item")
	_assert(popup_action.text == "Take" and popup_action.disabled, "Expected Take to be disabled when a small item has no free slot")
	var slots := inventory.get_node("InventoryReveal/InventoryOverlay/ContentMargin/Stack/Slots") as HBoxContainer
	var second_slot := slots.get_child(1) as Button
	inventory._on_item_pressed(1, second_slot)
	_assert(item_popup.visible and popup_name.text == "Binoculars", "Expected tapping inventory while loot is open to inspect carried items")
	_assert(popup_discard.visible, "Expected carried inventory item details to offer discard")
	popup_discard.pressed.emit()
	await process_frame
	_assert(item_popup.visible and popup_name.text == "Guiding Charm", "Expected found item details to return after discarding space")
	_assert(popup_action.text == "Take" and not popup_action.disabled, "Expected Take to enable after discarding space")
	popup_action.pressed.emit()
	_assert(not loot_ui.is_open(), "Expected taking the item after making space to close loot")
	_assert(inventory.get_minimum_hand_size_bonus() == 1, "Expected the taken Guiding Charm to apply its hand-size bonus")

	inventory.set_items([
		ItemCatalog.get_item("Walking Stick"),
		{},
		{},
	])
	loot_ui.open_loot([
		{
			"kind": "item",
			"item": ItemCatalog.get_item("Machete"),
		},
	])
	await process_frame
	_assert(item_popup.visible and popup_name.text == "Machete", "Expected large found item details to appear")
	_assert(popup_action.text == "Replace" and not popup_action.disabled, "Expected a found big item to offer Replace when a big item is already carried")
	popup_action.pressed.emit()
	_assert(not loot_ui.is_open(), "Expected replacing the only found item to close loot")
	_assert(inventory.get_items()[0]["name"] == "Machete", "Expected Replace to swap the carried big item for the found big item")

	loot_ui.open_loot([
		{
			"kind": "food",
			"amount": 3,
		},
		{
			"kind": "gold",
			"amount": 5,
		},
	])
	_assert(not loot_ui.is_open(), "Expected resource-only loot to avoid opening item details")
	_assert(player.food == 5, "Expected resource-only food loot to collect immediately")
	_assert(player.gold == 6, "Expected resource-only gold loot to collect immediately")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
