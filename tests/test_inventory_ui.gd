extends SceneTree

const INVENTORY_SCENE := preload("res://ui/inventory.tscn")
const UIStyle := preload("res://scripts/ui_style.gd")
const ItemIconLibrary := preload("res://scripts/item_icon_library.gd")
const ItemCatalog := preload("res://scripts/item_catalog.gd")


func _initialize() -> void:
	var root := Control.new()
	root.size = Vector2(720.0, 1280.0)
	get_root().add_child(root)

	var inventory = INVENTORY_SCENE.instantiate() as InventoryUI
	root.add_child(inventory)
	inventory._ready()

	var backpack_button := inventory.get_node("BackpackButton") as Button
	var frame := inventory.get_node("InventoryFrame") as PanelContainer
	var reveal := inventory.get_node("InventoryReveal") as Control
	var overlay := inventory.get_node("InventoryReveal/InventoryOverlay") as PanelContainer
	var title := inventory.get_node("InventoryReveal/InventoryOverlay/ContentMargin/Stack/Title") as Label
	var slots := inventory.get_node("InventoryReveal/InventoryOverlay/ContentMargin/Stack/Slots") as HBoxContainer
	var tooltip := inventory.get_node("ItemTooltip") as PanelContainer
	var item_popup := inventory.get_node("ItemDetailsPopup") as Control

	_assert(backpack_button != null, "Expected inventory to create a backpack button")
	_assert(inventory.button_size == Vector2(144.0, 144.0), "Expected backpack button to fit closely around its icon")
	_assert(inventory.slot_size == Vector2(93.0, 93.0), "Expected configured inventory slots to be fifty percent larger for mobile")
	_assert(backpack_button.text == "", "Expected backpack button to use the painted bag icon instead of text")
	_assert(backpack_button.icon != null, "Expected backpack button to use a replaceable image texture")
	_assert(backpack_button.expand_icon, "Expected backpack image to fill the button")
	_assert(is_equal_approx(backpack_button.position.x, inventory.left_margin), "Expected backpack button to sit at the left HUD edge")
	_assert(is_equal_approx(backpack_button.position.y, inventory.top_margin), "Expected backpack button to sit below the resource row")
	_assert(inventory.top_margin == 73.0, "Expected a small gap between the resource row and backpack image")
	_assert(is_equal_approx(frame.position.x + frame.size.x, backpack_button.position.x + backpack_button.size.x), "Expected the collapsed extension's right edge to align with the backpack")
	_assert(is_equal_approx(frame.size.x, 20.0), "Expected the closed inventory extension to remain tucked behind the backpack")
	_assert(is_equal_approx(frame.size.y, backpack_button.size.y + inventory.frame_top_padding + inventory.frame_bottom_padding), "Expected the inventory extension to share the backpack panel height")
	_assert(not overlay.visible, "Expected inventory overlay to start closed")
	_assert(inventory.get_carried_items().size() == 1, "Expected player inventory to start with one visible weapon")
	_assert(inventory.get_power_bonus() == 1, "Expected Walking Stick to add one power")
	_assert(inventory.get_sight_bonus() == 0, "Expected the starting inventory not to increase Sight")
	var stats_signal_result := {"count": 0}
	inventory.stats_changed.connect(func() -> void:
		stats_signal_result["count"] += 1
	)

	inventory.toggle_inventory()
	inventory.set_inventory_open(true)
	_assert(overlay.visible, "Expected backpack button to open the inventory overlay")
	_assert(slots.get_child_count() == 3, "Expected inventory overlay to contain three slots")
	_assert(reveal.position.x >= backpack_button.position.x + backpack_button.size.x, "Expected inventory overlay to grow out to the right of the backpack")
	_assert(is_equal_approx(reveal.position.x, backpack_button.position.x + backpack_button.size.x), "Expected inventory overlay to connect directly to the backpack button")
	_assert(reveal.position.y == backpack_button.position.y, "Expected inventory overlay to share the backpack button top edge")
	_assert(is_equal_approx(overlay.size.y, backpack_button.size.y), "Expected inventory overlay height %s to share backpack button height %s" % [overlay.size.y, backpack_button.size.y])
	_assert(overlay.pivot_offset.x == 0.0, "Expected inventory overlay to animate from its left edge")
	_assert(title.text == "Inventory", "Expected expanded inventory area to show its title")
	_assert(title.get_theme_font_size("font_size") == 18, "Expected inventory title to be clearly readable")
	_assert(title.get_theme_color("font_color") == Color(1, 0.93, 0.72), "Expected inventory title to remain readable on the dark HUD extension")
	_assert(frame.position.x < reveal.position.x and frame.position.y < backpack_button.position.y, "Expected the inventory extension to overlap the backpack's existing right edge")
	_assert(is_equal_approx(frame.position.x + frame.size.x, reveal.position.x + overlay.size.x), "Expected the moving right edge to end beyond all three slots")
	_assert(is_equal_approx(frame.position.y + frame.size.y, backpack_button.position.y + backpack_button.size.y + inventory.frame_bottom_padding), "Expected the extension to retain the backpack panel bottom edge")
	_assert(overlay.scale == Vector2.ONE, "Expected inventory contents to remain undistorted while the shared panel expands")
	_assert(reveal.clip_contents, "Expected the growing panel to clip inventory contents during its transition")
	var open_frame_size := frame.size
	inventory.toggle_inventory()
	_assert(frame.size == open_frame_size, "Expected closing inventory animation to start from the fully open frame")
	inventory.set_inventory_open(true)

	var first_slot := slots.get_child(0) as Button
	var second_slot := slots.get_child(1) as Button
	var empty_slot := slots.get_child(2) as Button
	_assert(first_slot.text == "", "Expected inventory item slots to use icons instead of text")
	_assert(first_slot.icon != null, "Expected first inventory slot to show an item image")
	_assert(first_slot.custom_minimum_size.is_equal_approx(inventory.get_slot_size()), "Expected inventory item slots to use the shared item slot size")
	_assert(second_slot.disabled, "Expected second slot to be empty")
	_assert(empty_slot.disabled, "Expected empty inventory slots to be disabled")
	var empty_slot_style := empty_slot.get_theme_stylebox("disabled") as StyleBoxFlat
	_assert(empty_slot_style.bg_color == InventoryUI.SLOT_DISABLED_FILL, "Expected empty inventory slots to use a light parchment background")
	_assert(first_slot.self_modulate == InventoryUI.NORMAL_SLOT_TINT, "Expected inventory items not to use active/inactive tinting")
	_assert((first_slot.get_node("ItemSizeBadge") as Label).text == "▲", "Expected the large Walking Stick icon to show a size marker")

	inventory._on_item_pressed(0, first_slot)
	_assert(item_popup.visible, "Expected pressing an item to show the item details popup")
	var popup_name := item_popup.get_node("Center/Panel/Margin/Stack/Header/Heading/ItemName") as Label
	var popup_meta := item_popup.get_node("Center/Panel/Margin/Stack/Header/Heading/Meta") as Label
	var popup_stats := item_popup.get_node("Center/Panel/Margin/Stack/Stats") as VBoxContainer
	var popup_discard := item_popup.get_node("Center/Panel/Margin/Stack/Buttons/DiscardButton") as Button
	_assert(popup_name.text == "Walking Stick", "Expected item popup to show the item name")
	_assert(popup_meta.text.contains("BIG ITEM"), "Expected item popup to state that the item is big")
	_assert(popup_stats.get_child_count() == 1 and (popup_stats.get_child(0).get_child(1) as Label).text == "+1", "Expected item popup to show each stat clearly")
	_assert(popup_discard.visible and not popup_discard.disabled, "Expected owned item details to include a discard action")
	_assert(not tooltip.visible, "Expected the old compact tooltip to stay hidden")

	item_popup.call("hide_popup")
	_assert(not item_popup.visible, "Expected the item popup close action to hide it")

	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(16.0, 420.0)
	inventory._input(outside_click)
	_assert(not inventory.is_open(), "Expected clicking outside inventory to close it")
	_assert(overlay.visible, "Expected clicking outside inventory to animate the overlay closed")
	_assert(not item_popup.visible, "Expected outside click to leave the item popup closed")

	inventory.toggle_inventory()
	inventory._on_item_pressed(0, first_slot)
	var inside_click := InputEventMouseButton.new()
	inside_click.button_index = MOUSE_BUTTON_LEFT
	inside_click.pressed = true
	inside_click.position = first_slot.get_global_rect().get_center()
	inventory._input(inside_click)
	_assert(overlay.visible, "Expected clicking inside inventory to keep the overlay open")

	inventory.set_inventory_open(false)
	_assert(not inventory.is_open(), "Expected inventory overlay to close")
	_assert(overlay.visible, "Expected direct inventory closing to use the soft closing animation")
	_assert(not tooltip.visible, "Expected closing inventory to hide the tooltip")

	_assert(not inventory.add_item(ItemCatalog.get_item("Machete")), "Expected a second large item to be rejected")
	_assert(inventory.add_item(ItemCatalog.get_item("Dagger")), "Expected adding a small weapon to succeed")
	_assert(inventory.get_power_bonus() == 3, "Expected small weapons to contribute while carried with a large item")
	inventory.replace_item_at_slot(1, {})
	_assert(inventory.add_item(ItemCatalog.get_item("Binoculars")), "Expected adding a small test item to succeed")
	_assert(inventory.get_sight_bonus() == 1, "Expected every carried small item to be active")
	_assert(stats_signal_result["count"] == 3, "Expected adding and removing items to notify stat listeners")
	inventory.set_inventory_open(true)
	inventory._layout_inventory()
	var first_slot_after_add := slots.get_child(0) as Button
	var second_slot_after_add := slots.get_child(1) as Button
	first_slot_after_add.position = Vector2.ZERO
	second_slot_after_add.position = Vector2(inventory.get_slot_size().x + inventory.get_slot_spacing(), 0.0)
	var second_slot_center := second_slot_after_add.get_global_rect().get_center()
	_assert(inventory.get_slot_index_at_canvas_position(second_slot_center) == 1, "Expected second backpack slot center to resolve to slot one")
	inventory._start_item_drag(0, first_slot_after_add, first_slot_after_add.get_global_rect().get_center())
	var drag_ghost := inventory.get_node("DragGhost") as TextureRect
	_assert(drag_ghost.visible, "Expected inventory drag to show an item image cursor")
	_assert(drag_ghost.texture == first_slot_after_add.icon, "Expected inventory drag cursor to use the dragged item image")
	_assert(drag_ghost.size.is_equal_approx(inventory.get_slot_size()), "Expected inventory drag cursor to match item slot size")
	_assert(inventory.is_in_group("ui_item_drag_active"), "Expected item drag to block camera input")
	inventory._finish_item_drag(second_slot_center)
	_assert(not inventory.is_in_group("ui_item_drag_active"), "Expected finishing item drag to unblock camera input")
	_assert(inventory.get_carried_items()[0]["name"] == "Binoculars", "Expected dropping an inventory item onto another slot to swap them")
	_assert(inventory.get_carried_items()[1]["name"] == "Walking Stick", "Expected replaced inventory item to move into the source slot")
	first_slot_after_add = slots.get_child(0) as Button
	second_slot_after_add = slots.get_child(1) as Button
	var third_slot_after_swap := slots.get_child(2) as Button
	third_slot_after_swap.position = Vector2((inventory.get_slot_size().x + inventory.get_slot_spacing()) * 2.0, 0.0)
	var third_slot_center := third_slot_after_swap.get_global_rect().get_center()
	_assert(inventory.get_slot_index_at_canvas_position(third_slot_center) == 2, "Expected third backpack slot center to resolve to slot two")
	inventory._start_item_drag(1, second_slot_after_add, second_slot_after_add.get_global_rect().get_center())
	inventory._finish_item_drag(third_slot_center)
	_assert((slots.get_child(1) as Button).disabled, "Expected moving an inventory item to an empty slot to clear the source slot")
	_assert(not (slots.get_child(2) as Button).disabled, "Expected moving an inventory item to an empty slot to fill the target slot")
	_assert((slots.get_child(2) as Button).icon != null, "Expected moved inventory item to keep its icon")

	inventory.set_items([
		{"name": "Binoculars", "effect": "+1 Sight", "sight_bonus": 1},
		{"name": "Goldsmith's Scale", "effect": "Gain twice as much gold.", "gold_multiplier": 2},
		{"name": "Field Medic's Bag", "effect": "+2 Max Health", "max_health_bonus": 2},
	])
	_assert(inventory.get_sight_bonus() == 1, "Expected Binoculars to grant +1 Sight")
	_assert(inventory.get_gold_multiplier() == 2, "Expected Goldsmith's Scale to double gold gains")
	_assert(inventory.get_max_health_bonus() == 2, "Expected Field Medic's Bag to increase max health by two")
	_assert(inventory.get_minimum_hand_size_bonus() == 0, "Expected utility items without a hand bonus not to change minimum hand size")
	for item in inventory.get_items():
		_assert(ItemIconLibrary.get_icon(item) != null, "Expected every utility item to have an item icon")
	inventory.replace_item_at_slot(2, ItemCatalog.get_item("Guiding Charm"))
	_assert(inventory.get_minimum_hand_size_bonus() == 1, "Expected Guiding Charm to increase minimum hand size by one")
	_assert(ItemIconLibrary.get_icon(ItemCatalog.get_item("Guiding Charm")) != null, "Expected Guiding Charm to have an item icon")
	inventory.show_item_details(inventory.get_items()[2], 2)
	popup_discard.pressed.emit()
	_assert(inventory.get_items()[2].is_empty(), "Expected discard from item details to remove the owned item")
	_assert(inventory.get_minimum_hand_size_bonus() == 0, "Expected discarding an item to remove its stat bonus")
	inventory.replace_item_at_slot(2, ItemCatalog.get_item("Field Medic's Bag"))
	var player := GamePlayer.new()
	player.gold = 1
	player.health = 4
	player.max_health = 4
	player.set("_inventory", inventory)
	player.set("_inventory_max_health_bonus", 0)
	inventory.stats_changed.connect(player.call.bind("_on_inventory_stats_changed"))
	player.call("_on_inventory_stats_changed")
	player.add_gold(3)
	_assert(player.gold == 7, "Expected Goldsmith's Scale to double gold gained by the player")
	_assert(player.health == 6 and player.max_health == 6, "Expected Field Medic's Bag to add two current and max health")
	inventory.replace_item_at_slot(2, {})
	_assert(player.health == 4 and player.max_health == 4, "Expected removing Field Medic's Bag to remove its health bonus")
	player.free()

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
