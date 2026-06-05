extends SceneTree

const INVENTORY_SCENE := preload("res://ui/inventory.tscn")
const UIStyle := preload("res://scripts/ui_style.gd")


func _initialize() -> void:
	var root := Control.new()
	root.size = Vector2(720.0, 1280.0)
	get_root().add_child(root)

	var inventory = INVENTORY_SCENE.instantiate() as InventoryUI
	root.add_child(inventory)
	inventory._ready()

	var backpack_button := inventory.get_node("BackpackButton") as Button
	var frame := inventory.get_node("InventoryFrame") as PanelContainer
	var overlay := inventory.get_node("InventoryOverlay") as PanelContainer
	var title := inventory.get_node("InventoryOverlay/ContentMargin/Stack/Title") as Label
	var slots := inventory.get_node("InventoryOverlay/ContentMargin/Stack/Slots") as HBoxContainer
	var tooltip := inventory.get_node("ItemTooltip") as PanelContainer

	_assert(backpack_button != null, "Expected inventory to create a backpack button")
	_assert(inventory.button_size == Vector2(195.0, 195.0), "Expected configured backpack button to be fifty percent larger for mobile")
	_assert(inventory.slot_size == Vector2(93.0, 93.0), "Expected configured inventory slots to be fifty percent larger for mobile")
	_assert(backpack_button.text == "", "Expected backpack button to use the painted bag icon instead of text")
	_assert(backpack_button.icon != null, "Expected backpack button to use a replaceable image texture")
	_assert(backpack_button.expand_icon, "Expected backpack image to fill the button")
	_assert(is_equal_approx(backpack_button.position.x + backpack_button.size.x, 702.0), "Expected backpack button right edge %s to keep its right margin" % (backpack_button.position.x + backpack_button.size.x))
	_assert(not overlay.visible, "Expected inventory overlay to start closed")
	_assert(inventory.get_active_items().size() == 1, "Expected player inventory to start with one visible weapon")
	_assert(inventory.get_power_bonus() == 1, "Expected Knife to add one power")
	var stats_signal_result := {"count": 0}
	inventory.stats_changed.connect(func() -> void:
		stats_signal_result["count"] += 1
	)

	inventory.toggle_inventory()
	inventory.set_inventory_open(true)
	_assert(overlay.visible, "Expected backpack button to open the inventory overlay")
	_assert(slots.get_child_count() == 3, "Expected inventory overlay to contain three slots")
	_assert(overlay.position.x + overlay.size.x <= backpack_button.position.x, "Expected inventory overlay to grow out to the left of the backpack")
	_assert(is_equal_approx(overlay.position.x + overlay.size.x, backpack_button.position.x), "Expected inventory overlay to connect directly to the backpack button")
	_assert(overlay.position.y == backpack_button.position.y, "Expected inventory overlay to share the backpack button top edge")
	_assert(is_equal_approx(overlay.size.y, backpack_button.size.y), "Expected inventory overlay height %s to share backpack button height %s" % [overlay.size.y, backpack_button.size.y])
	_assert(overlay.pivot_offset.x == overlay.size.x, "Expected inventory overlay to animate from its right edge")
	_assert(title.text == "Inventory", "Expected expanded inventory area to show a small title")
	_assert(frame.position == overlay.position, "Expected shared inventory frame to start at the expanded slot area")
	_assert(frame.size.x == overlay.size.x + backpack_button.size.x, "Expected shared inventory frame to wrap slots and backpack as one control")
	_assert(frame.size.y == backpack_button.size.y, "Expected shared inventory frame to match backpack height")
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
	_assert(first_slot.self_modulate == InventoryUI.EQUIPPED_SLOT_TINT, "Expected strongest weapon slot to be tinted")

	inventory._on_item_pressed(0, first_slot)
	_assert(tooltip.visible, "Expected pressing an item to show a tooltip")
	var tooltip_name := tooltip.get_node("ContentMargin/Text/ItemName") as Label
	var tooltip_effect := tooltip.get_node("ContentMargin/Text/ItemEffect") as Label
	_assert(tooltip_name.text == "Knife", "Expected tooltip to show the item name")
	_assert(tooltip_effect.text == "+1 Power", "Expected tooltip to show the item effect")
	_assert(tooltip_name.get_theme_color("font_color") == UIStyle.text(inventory), "Expected tooltip name text to use the shared UI text color")
	_assert(tooltip_effect.get_theme_color("font_color") == UIStyle.muted_text(inventory), "Expected tooltip effect text to use the shared UI muted text color")

	inventory._on_item_pressed(0, first_slot)
	_assert(not tooltip.visible, "Expected pressing the same item again to hide the tooltip")

	inventory._on_item_pressed(0, first_slot)
	_assert(tooltip.visible, "Expected pressing the item after hiding it to show the tooltip again")

	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(16.0, 420.0)
	inventory._input(outside_click)
	_assert(not inventory.is_open(), "Expected clicking outside inventory to close it")
	_assert(overlay.visible, "Expected clicking outside inventory to animate the overlay closed")
	_assert(not tooltip.visible, "Expected outside click to hide the tooltip")

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

	_assert(inventory.add_item({
		"name": "Dagger",
		"effect": "+2 Power",
		"power_bonus": 2,
	}), "Expected adding a test item to succeed")
	_assert(stats_signal_result["count"] == 1, "Expected adding items to notify stat listeners")
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
	_assert(inventory.get_active_items()[0]["name"] == "Dagger", "Expected dropping an inventory item onto another slot to swap them")
	_assert(inventory.get_active_items()[1]["name"] == "Knife", "Expected replaced inventory item to move into the source slot")
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

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
