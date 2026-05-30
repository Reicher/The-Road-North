extends SceneTree

const INVENTORY_SCENE := preload("res://ui/inventory.tscn")
const LOOT_SCENE := preload("res://ui/loot.tscn")
const MAP_SCRIPT := preload("res://scripts/map.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")


func _initialize() -> void:
	var root := Control.new()
	root.size = Vector2(360.0, 640.0)
	get_root().add_child(root)

	var map = MAP_SCRIPT.new()
	map.name = "Map"
	root.add_child(map)

	var player = PLAYER_SCRIPT.new()
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
				"name": "Helmet",
				"effect": "+2 Armor",
				"attack": 0,
				"armor": 2,
			},
		},
	])
	_assert(inventory.is_open(), "Expected opening loot to automatically open the backpack")
	var overlay := inventory.get_node("InventoryOverlay") as PanelContainer
	var loot_panel := loot_ui.get_node("LootPanel") as PanelContainer
	var loot_panel_click := InputEventMouseButton.new()
	loot_panel_click.button_index = MOUSE_BUTTON_LEFT
	loot_panel_click.pressed = true
	loot_panel_click.position = loot_panel.get_global_rect().get_center()
	inventory._input(loot_panel_click)
	_assert(inventory.is_open(), "Expected loot screen interaction to keep the backpack open")

	var loot_item := loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootItem0") as Button
	_assert(loot_item.custom_minimum_size == inventory.get_slot_size(), "Expected loot item slots to match backpack slot size")
	_assert(loot_item.text == "Helmet", "Expected loot item slots to show only the item name")
	loot_ui._start_drag(0, loot_item, Vector2.ZERO)
	loot_ui._finish_drag(loot_item.get_global_rect().get_center())
	var loot_tooltip := loot_ui.get_node("ItemTooltip") as PanelContainer
	var loot_tooltip_name := loot_tooltip.get_node("ContentMargin/Text/ItemName") as Label
	var loot_tooltip_effect := loot_tooltip.get_node("ContentMargin/Text/ItemEffect") as Label
	_assert(loot_tooltip.visible, "Expected tapping a loot item slot to show its tooltip")
	_assert(loot_tooltip_name.text == "Helmet", "Expected loot tooltip to show the item name")
	_assert(loot_tooltip_effect.text == "+2 Armor", "Expected loot tooltip to show the item effect")

	loot_ui._start_drag(0, loot_item, Vector2.ZERO)
	loot_ui._finish_drag(overlay.get_global_rect().get_center())
	_assert(not loot_ui.is_open(), "Expected dragging the only loot item into the backpack to close loot")
	_assert(inventory.get_active_items().size() == 3, "Expected dragged loot item to move into the backpack")
	_assert(inventory.get_armor_bonus() == 2, "Expected only the strongest armor item to count")

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
				"effect": "+3 Attack",
				"attack": 3,
				"armor": 0,
			},
		},
	]

	loot_ui.open_loot(loot)
	_assert(loot_ui.is_open(), "Expected loot screen to open with available loot")
	_assert(loot_ui.get_node("LootPanel") != null, "Expected loot screen to create a centered panel")
	_assert(player.food == 5, "Expected food loot to add when the loot screen opens")
	_assert(player.gold == 6, "Expected gold loot to add when the loot screen opens")
	_assert(loot_ui.loot.size() == 1, "Expected only item loot to remain in the loot screen")
	_assert(loot_ui.collected_resources.size() == 2, "Expected collected resource loot to remain visible in the loot screen")
	_assert(loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootResource0") is Control, "Expected food loot to show an icon row")
	_assert(loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootResource1") is Control, "Expected gold loot to show an icon row")

	loot_ui.take_all()
	_assert(not loot_ui.is_open(), "Expected taking all loot to close when everything fits")
	_assert(player.food == 5, "Expected Take All not to add already collected food again")
	_assert(player.gold == 6, "Expected Take All not to add already collected gold again")
	_assert(inventory.get_active_items().size() == 4, "Expected item loot to move into a new backpack slot")
	_assert(inventory.get_active_items()[0]["name"] == "Sword", "Expected the old sword to stay in its slot")
	_assert(inventory.get_active_items()[3]["name"] == "Sword", "Expected the new sword to use another slot")
	_assert(inventory.get_attack_bonus() == 3, "Expected only the strongest sword to contribute attack")
	var slots := inventory.get_node("InventoryOverlay/ContentMargin/Slots") as HBoxContainer
	_assert((slots.get_child(0) as Button).self_modulate == InventoryUI.NORMAL_SLOT_TINT, "Expected weaker sword slot not to be tinted")
	_assert((slots.get_child(1) as Button).self_modulate == InventoryUI.EQUIPPED_SLOT_TINT, "Expected strongest shield slot to stay tinted")
	_assert((slots.get_child(2) as Button).self_modulate == InventoryUI.NORMAL_SLOT_TINT, "Expected tied armor slot not to be tinted")
	_assert((slots.get_child(3) as Button).self_modulate == InventoryUI.EQUIPPED_SLOT_TINT, "Expected strongest sword slot to be tinted")

	for index in inventory.get_free_slot_count():
		_assert(inventory.add_item({
			"name": "Filler %d" % index,
			"effect": "",
			"attack": 0,
			"armor": 0,
		}), "Expected filler item to occupy a free slot")
	_assert(not inventory.has_space(), "Expected inventory to report full when every slot has one item")

	loot_ui.open_loot(loot)
	_assert(player.food == 8, "Expected food loot to add immediately even when item slots are full")
	_assert(player.gold == 11, "Expected gold loot to add immediately even when item slots are full")
	_assert(loot_ui.loot.size() == 1, "Expected only item loot to remain after opening full-inventory loot")
	loot_ui.take_all()
	_assert(loot_ui.is_open(), "Expected full inventory to leave item loot behind after Take All")
	_assert(player.food == 8, "Expected Take All not to add already collected food again")
	_assert(player.gold == 11, "Expected Take All not to add already collected gold again")
	_assert(loot_ui.loot.size() == 1, "Expected only the unclaimed item to remain")

	loot_item = loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootItem0") as Button
	slots = inventory.get_node("InventoryOverlay/ContentMargin/Slots") as HBoxContainer
	var first_backpack_slot := slots.get_child(0) as Button
	_assert(inventory.get_slot_index_at_canvas_position(first_backpack_slot.get_global_rect().get_center()) == 0, "Expected first backpack slot center to resolve to slot zero")
	loot_ui._start_drag(0, loot_item, Vector2.ZERO)
	loot_ui._finish_drag(first_backpack_slot.get_global_rect().get_center())
	_assert(inventory.get_active_items()[0]["effect"] == "+3 Attack", "Expected dropping loot on an occupied backpack slot to replace it")
	_assert(loot_ui.loot[0]["item"]["effect"] == "+2 Attack", "Expected replaced backpack item to move into the loot slot")

	loot_item = loot_ui.get_node("LootPanel/ContentMargin/Stack/LootList/LootItem0") as Button
	first_backpack_slot = slots.get_child(0) as Button
	inventory._start_item_drag(0, first_backpack_slot, Vector2.ZERO)
	inventory._finish_item_drag(loot_item.get_global_rect().get_center())
	_assert(inventory.get_active_items()[0]["effect"] == "+2 Attack", "Expected dropping backpack item on occupied loot slot to replace it")
	_assert(loot_ui.loot[0]["item"]["effect"] == "+3 Attack", "Expected replaced loot item to move into the backpack slot")

	loot_ui.close_loot()
	_assert(not loot_ui.is_open(), "Expected closing loot to discard remaining loot")
	_assert(loot_ui.loot.is_empty(), "Expected closing loot to permanently remove leftovers")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
