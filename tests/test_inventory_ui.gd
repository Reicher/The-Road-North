extends SceneTree

const INVENTORY_SCENE := preload("res://ui/inventory.tscn")
const UIStyle := preload("res://scripts/ui_style.gd")


func _initialize() -> void:
	var root := Control.new()
	root.size = Vector2(360.0, 640.0)
	get_root().add_child(root)

	var inventory = INVENTORY_SCENE.instantiate() as InventoryUI
	root.add_child(inventory)
	inventory._ready()

	var backpack_button := inventory.get_node("BackpackButton") as Button
	var overlay := inventory.get_node("InventoryOverlay") as PanelContainer
	var slots := inventory.get_node("InventoryOverlay/ContentMargin/Slots") as HBoxContainer
	var tooltip := inventory.get_node("ItemTooltip") as PanelContainer

	_assert(backpack_button != null, "Expected inventory to create a backpack button")
	_assert(backpack_button.size == Vector2(130.0, 130.0), "Expected backpack button to use the requested icon size")
	_assert(backpack_button.text == "", "Expected backpack button to use the painted bag icon instead of text")
	_assert(is_equal_approx(backpack_button.position.x + backpack_button.size.x, 342.0), "Expected backpack button to keep its right margin")
	_assert(not overlay.visible, "Expected inventory overlay to start closed")
	_assert(inventory.get_active_items().size() == 1, "Expected player inventory to start with one visible weapon")
	_assert(inventory.get_power_bonus() == 1, "Expected Knife to add one power")
	var stats_signal_result := {"count": 0}
	inventory.stats_changed.connect(func() -> void:
		stats_signal_result["count"] += 1
	)

	inventory.toggle_inventory()
	_assert(overlay.visible, "Expected backpack button to open the inventory overlay")
	_assert(slots.get_child_count() == 5, "Expected inventory overlay to contain five slots")

	var first_slot := slots.get_child(0) as Button
	var second_slot := slots.get_child(1) as Button
	var empty_slot := slots.get_child(2) as Button
	_assert(first_slot.text == "Knife", "Expected first slot to contain Knife")
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

	_assert(inventory.add_item({
		"name": "Dagger",
		"effect": "+1 Power",
		"power": 1,
	}), "Expected adding a test item to succeed")
	_assert(stats_signal_result["count"] == 1, "Expected adding items to notify stat listeners")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
