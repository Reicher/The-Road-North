extends SceneTree

const INVENTORY_SCENE := preload("res://ui/inventory.tscn")
const LOOT_SCENE := preload("res://ui/loot.tscn")
const MAP_SCENE := preload("res://scenes/map.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")


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

	loot_ui.open_loot([
		{
			"kind": "item",
			"item": {
				"name": "Machete",
				"effect": "+2 Power",
				"power": 2,
			},
		},
	])
	_assert(inventory.is_open(), "Expected opening loot to automatically open the backpack")
	var overlay := inventory.get_node("InventoryOverlay") as PanelContainer
	var loot_panel := loot_ui.get_node("LootPanel") as PanelContainer
	var inventory_frame := inventory.get_node("InventoryFrame") as PanelContainer
	var loot_panel_click := InputEventMouseButton.new()
	loot_panel_click.button_index = MOUSE_BUTTON_LEFT
	loot_panel_click.pressed = true
	loot_panel_click.position = loot_panel.get_global_rect().get_center()
	inventory._input(loot_panel_click)
	_assert(inventory.is_open(), "Expected loot screen interaction to keep the backpack open")

	var loot_item := loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootItem0") as Button
	_assert(loot_item.custom_minimum_size == inventory.get_slot_size(), "Expected loot item slots to match backpack slot size")
	_assert(loot_item.text == "", "Expected loot item slots to use icons instead of text")
	_assert(loot_item.icon != null, "Expected loot item slots to show an item image")
	_assert(loot_panel.size.x < 230.0, "Expected single-item loot panel to stay horizontally compact")
	_assert(loot_panel.size.y < 230.0, "Expected single-item loot panel to stay vertically compact")
	var inventory_frame_rect := inventory_frame.get_global_rect()
	var loot_panel_rect := loot_panel.get_global_rect()
	_assert(is_equal_approx(loot_panel_rect.position.x, inventory_frame_rect.position.x), "Expected loot panel to align with the open inventory frame")
	_assert(is_equal_approx(loot_panel_rect.position.y, inventory_frame_rect.position.y + inventory_frame_rect.size.y + 6.0), "Expected loot panel to sit directly below the open inventory frame")
	loot_ui._start_drag(0, loot_item, Vector2.ZERO)
	var drag_ghost := loot_ui.get_node("DragGhost") as TextureRect
	_assert(drag_ghost.visible, "Expected dragging loot to show an item image cursor")
	_assert(drag_ghost.texture == loot_item.icon, "Expected drag cursor to use the dragged item image")
	_assert(drag_ghost.size == inventory.get_slot_size(), "Expected drag cursor to match item slot size")
	loot_ui._finish_drag(loot_item.get_global_rect().get_center())
	var loot_tooltip := loot_ui.get_node("ItemTooltip") as PanelContainer
	var loot_tooltip_name := loot_tooltip.get_node("ContentMargin/Text/ItemName") as Label
	var loot_tooltip_effect := loot_tooltip.get_node("ContentMargin/Text/ItemEffect") as Label
	_assert(loot_tooltip.visible, "Expected tapping a loot item slot to show its tooltip")
	_assert(loot_tooltip_name.text == "Machete", "Expected loot tooltip to show the item name")
	_assert(loot_tooltip_effect.text == "+2 Power", "Expected loot tooltip to show the item effect")

	loot_ui._start_drag(0, loot_item, Vector2.ZERO)
	loot_ui._finish_drag(overlay.get_global_rect().get_center())
	_assert(not loot_ui.is_open(), "Expected dragging the only loot item into the backpack to close loot")
	_assert(inventory.get_active_items().size() == 2, "Expected dragged loot item to move into the backpack")
	_assert(inventory.get_power_bonus() == 2, "Expected only the strongest weapon to count")

	var loot := [
		{
			"kind": "food",
			"amount": 3,
		},
		{
			"kind": "gold",
			"amount": 5,
		},
		{
			"kind": "item",
			"item": {
				"name": "Sword",
				"effect": "+3 Power",
				"power": 3,
			},
		},
	]

	loot_ui.open_loot(loot)
	_assert(loot_ui.is_open(), "Expected loot screen to open with available loot")
	_assert(loot_ui.get_node("LootPanel") != null, "Expected loot screen to create a loot panel")
	_assert(player.food == 5, "Expected food loot to add when the loot screen opens")
	_assert(player.gold == 6, "Expected gold loot to add when the loot screen opens")
	_assert(loot_ui.loot.size() == 1, "Expected only item loot to remain in the loot screen")
	_assert(loot_ui.collected_resources.size() == 2, "Expected collected resource loot to remain available for popup feedback")
	_assert(loot_ui.get_node_or_null("LootPanel/ContentMargin/Stack/LootList/LootResource0") == null, "Expected resource loot to stay out of the item loot list")
	var resource_popup_layer := loot_ui.get_node("ResourcePopupLayer") as Control
	_assert(resource_popup_layer.get_child_count() == 1, "Expected collected resources to show one floating popup")
	var loot_panel_position := loot_panel.position
	_assert(loot_panel_position.x < root.size.x * 0.33, "Expected loot panel to be offset from the screen center")

	loot_ui.take_all()
	_assert(not loot_ui.is_open(), "Expected taking all loot to close when everything fits")
	_assert(not inventory.is_open(), "Expected Take All to close the inventory")
	_assert(player.food == 5, "Expected Take All not to add already collected food again")
	_assert(player.gold == 6, "Expected Take All not to add already collected gold again")
	_assert(inventory.get_active_items().size() == 3, "Expected item loot to move into a new backpack slot")
	_assert(inventory.get_active_items()[0]["name"] == "Knife", "Expected the old knife to stay in its slot")
	_assert(inventory.get_active_items()[2]["name"] == "Sword", "Expected the new sword to use another slot")
	_assert(inventory.get_power_bonus() == 3, "Expected only the strongest weapon to contribute power")
	var slots := inventory.get_node("InventoryOverlay/ContentMargin/Stack/Slots") as HBoxContainer
	_assert((slots.get_child(0) as Button).self_modulate == InventoryUI.NORMAL_SLOT_TINT, "Expected weaker sword slot not to be tinted")
	_assert((slots.get_child(1) as Button).self_modulate == InventoryUI.NORMAL_SLOT_TINT, "Expected weaker loot weapon slot not to be tinted")
	_assert((slots.get_child(2) as Button).self_modulate == InventoryUI.EQUIPPED_SLOT_TINT, "Expected strongest sword slot to be tinted")

	for index in inventory.get_free_slot_count():
		_assert(inventory.add_item({
			"name": "Filler %d" % index,
			"effect": "",
			"power": 0,
		}), "Expected filler item to occupy a free slot")
	_assert(not inventory.has_space(), "Expected inventory to report full when every slot has one item")

	loot_ui.open_loot(loot)
	_assert(player.food == 8, "Expected food loot to add immediately even when item slots are full")
	_assert(player.gold == 11, "Expected gold loot to add immediately even when item slots are full")
	_assert(loot_ui.loot.size() == 1, "Expected only item loot to remain after opening full-inventory loot")
	loot_ui.take_all()
	_assert(loot_ui.is_open(), "Expected full inventory to leave item loot behind after Take All")
	_assert(not inventory.is_open(), "Expected Take All to close the inventory even when item loot remains")
	_assert(player.food == 8, "Expected Take All not to add already collected food again")
	_assert(player.gold == 11, "Expected Take All not to add already collected gold again")
	_assert(loot_ui.loot.size() == 1, "Expected only the unclaimed item to remain")

	inventory.set_inventory_open(true)
	loot_item = loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootItem0") as Button
	slots = inventory.get_node("InventoryOverlay/ContentMargin/Stack/Slots") as HBoxContainer
	var first_backpack_slot := slots.get_child(0) as Button
	_assert(inventory.get_slot_index_at_canvas_position(first_backpack_slot.get_global_rect().get_center()) == 0, "Expected first backpack slot center to resolve to slot zero")
	loot_ui._start_drag(0, loot_item, Vector2.ZERO)
	loot_ui._finish_drag(first_backpack_slot.get_global_rect().get_center())
	_assert(inventory.get_active_items()[0]["effect"] == "+3 Power", "Expected dropping loot on an occupied backpack slot to replace it")
	_assert(loot_ui.loot[0]["item"]["effect"] == "+1 Power", "Expected replaced backpack item to move into the loot slot")

	loot_item = loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootItem0") as Button
	first_backpack_slot = slots.get_child(0) as Button
	inventory._start_item_drag(0, first_backpack_slot, Vector2.ZERO)
	inventory._finish_item_drag(loot_item.get_global_rect().get_center())
	_assert(inventory.get_active_items()[0]["effect"] == "+1 Power", "Expected dropping backpack item on occupied loot slot to replace it")
	_assert(loot_ui.loot[0]["item"]["effect"] == "+3 Power", "Expected replaced loot item to move into the backpack slot")

	loot_ui.open_loot([
		{
			"kind": "item",
			"item": {
				"name": "Dagger",
				"effect": "+1 Power",
				"power": 1,
			},
		},
		{
			"kind": "item",
			"item": {
				"name": "Katana",
				"effect": "+4 Power",
				"power": 4,
			},
		},
	])
	loot_ui._layout_loot()
	var first_loot_item := loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootItem0") as Button
	var second_loot_item := loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootItem1") as Button
	first_loot_item.position = Vector2.ZERO
	second_loot_item.position = Vector2(0.0, inventory.get_slot_size().y + inventory.get_slot_spacing())
	var second_loot_center := second_loot_item.get_global_rect().get_center()
	_assert(loot_ui.get_loot_item_index_at_canvas_position(second_loot_center) == 1, "Expected second loot slot center to resolve to loot item one")
	loot_ui._start_drag(0, first_loot_item, Vector2.ZERO)
	loot_ui._finish_drag(second_loot_center)
	_assert(loot_ui.loot[0]["item"]["name"] == "Katana", "Expected dropping loot on loot to swap the target item back to the source slot")
	_assert(loot_ui.loot[1]["item"]["name"] == "Dagger", "Expected dropping loot on loot to move the dragged item into the target slot")

	loot_ui.close_loot()
	_assert(not loot_ui.is_open(), "Expected closing loot to discard remaining loot")
	_assert(loot_ui.loot.is_empty(), "Expected closing loot to permanently remove leftovers")

	loot_ui.open_loot([
		{
			"kind": "food",
			"amount": 3,
		},
	])
	_assert(not loot_ui.is_open(), "Expected resource-only loot to avoid opening the item loot panel")
	_assert(player.food == 11, "Expected resource-only food loot to collect immediately")
	_assert(resource_popup_layer.get_child_count() >= 1, "Expected resource-only loot to show floating feedback")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
