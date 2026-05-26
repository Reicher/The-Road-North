extends SceneTree

const INVENTORY_SCRIPT := preload("res://scripts/inventory_ui.gd")


func _initialize() -> void:
	var root := Control.new()
	root.size = Vector2(360.0, 640.0)
	get_root().add_child(root)

	var inventory = INVENTORY_SCRIPT.new()
	inventory.size = root.size
	root.add_child(inventory)
	inventory._ready()

	var backpack_button := inventory.get_node("BackpackButton") as Button
	var overlay := inventory.get_node("InventoryOverlay") as PanelContainer
	var slots := inventory.get_node("InventoryOverlay/ContentMargin/Slots") as HBoxContainer
	var tooltip := inventory.get_node("ItemTooltip") as PanelContainer

	_assert(backpack_button != null, "Expected inventory to create a backpack button")
	_assert(backpack_button.position.x > 250.0, "Expected backpack button to sit near the top-right corner")
	_assert(not overlay.visible, "Expected inventory overlay to start closed")
	_assert(inventory.get_active_items().size() == 2, "Expected player inventory to start with two visible items")
	_assert(inventory.get_attack_bonus() == 2, "Expected Sword to add two attack")
	_assert(inventory.get_armor_bonus() == 2, "Expected Shield to add two armor")

	inventory.toggle_inventory()
	_assert(overlay.visible, "Expected backpack button to open the inventory overlay")
	_assert(slots.get_child_count() == 5, "Expected inventory overlay to contain five slots")

	var first_slot := slots.get_child(0) as Button
	var second_slot := slots.get_child(1) as Button
	var empty_slot := slots.get_child(2) as Button
	_assert(first_slot.text == "Sword", "Expected first slot to contain Sword")
	_assert(second_slot.text == "Shield", "Expected second slot to contain Shield")
	_assert(empty_slot.disabled, "Expected empty inventory slots to be disabled")
	_assert(first_slot.self_modulate == InventoryUI.EQUIPPED_SLOT_TINT, "Expected strongest sword slot to be tinted")
	_assert(second_slot.self_modulate == InventoryUI.EQUIPPED_SLOT_TINT, "Expected strongest shield slot to be tinted")

	inventory._on_item_pressed(0, first_slot)
	_assert(tooltip.visible, "Expected pressing an item to show a tooltip")
	var tooltip_name := tooltip.get_node("ContentMargin/Text/ItemName") as Label
	var tooltip_effect := tooltip.get_node("ContentMargin/Text/ItemEffect") as Label
	_assert(tooltip_name.text == "Sword", "Expected tooltip to show the item name")
	_assert(tooltip_effect.text == "+2 Attack", "Expected tooltip to show the item effect")
	_assert(tooltip_name.get_theme_color("font_color") == Color.WHITE, "Expected tooltip name text to be white")
	_assert(tooltip_effect.get_theme_color("font_color") == Color.WHITE, "Expected tooltip effect text to be white")

	inventory._on_item_pressed(0, first_slot)
	_assert(not tooltip.visible, "Expected pressing the same item again to hide the tooltip")

	inventory._on_item_pressed(0, first_slot)
	_assert(tooltip.visible, "Expected pressing the item after hiding it to show the tooltip again")

	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(16.0, 420.0)
	inventory._input(outside_click)
	_assert(not overlay.visible, "Expected clicking outside inventory to close the overlay")
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
	_assert(not overlay.visible, "Expected inventory overlay to close")
	_assert(not tooltip.visible, "Expected closing inventory to hide the tooltip")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
