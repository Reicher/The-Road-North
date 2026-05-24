class_name InventoryUI
extends Control

const SLOT_COUNT := 5

@export var button_size := Vector2(64.0, 48.0)
@export var slot_size := Vector2(82.0, 82.0)
@export var top_margin := 18.0
@export var right_margin := 18.0
@export var slot_spacing := 8.0

var items: Array[Dictionary] = [
	{
		"name": "Sword",
		"effect": "+2 Attack",
		"attack": 2,
		"armor": 0,
	},
	{
		"name": "Shield",
		"effect": "+2 Armor",
		"attack": 0,
		"armor": 2,
	},
]

var _backpack_button: Button
var _overlay: PanelContainer
var _slot_row: HBoxContainer
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_effect: Label
var _ready_completed := false
var _tooltip_slot_index := -1


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var current_size := size
	if current_size.x <= 0.0 or current_size.y <= 0.0:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_inventory)
	_build_inventory()
	_refresh_slots()
	_layout_inventory()
	set_process_input(true)
	set_process_unhandled_input(true)


func _input(event: InputEvent) -> void:
	_close_on_outside_press(event)


func _unhandled_input(event: InputEvent) -> void:
	_close_on_outside_press(event)


func _close_on_outside_press(event: InputEvent) -> void:
	if not is_open():
		return

	var canvas_position := Vector2.INF
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		canvas_position = event.position
	elif event is InputEventScreenTouch and event.pressed:
		canvas_position = event.position
	else:
		return

	if not _is_canvas_position_inside_inventory(canvas_position):
		set_inventory_open(false)


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func get_attack_bonus() -> int:
	var total := 0
	for item in items:
		total += int(item.get("attack", 0))
	return total


func get_armor_bonus() -> int:
	var total := 0
	for item in items:
		total += int(item.get("armor", 0))
	return total


func get_active_items() -> Array[Dictionary]:
	return items.duplicate(true)


func toggle_inventory() -> void:
	set_inventory_open(not is_open())


func set_inventory_open(open: bool) -> void:
	if _overlay == null:
		return
	_overlay.visible = open
	if not open:
		_hide_tooltip()


func _build_inventory() -> void:
	_backpack_button = Button.new()
	_backpack_button.name = "BackpackButton"
	_backpack_button.text = "Pack"
	_backpack_button.focus_mode = Control.FOCUS_NONE
	_backpack_button.custom_minimum_size = button_size
	_backpack_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_backpack_button.pressed.connect(toggle_inventory)
	add_child(_backpack_button)

	_overlay = PanelContainer.new()
	_overlay.name = "InventoryOverlay"
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var overlay_margin := MarginContainer.new()
	overlay_margin.name = "ContentMargin"
	overlay_margin.add_theme_constant_override("margin_left", 10)
	overlay_margin.add_theme_constant_override("margin_top", 10)
	overlay_margin.add_theme_constant_override("margin_right", 10)
	overlay_margin.add_theme_constant_override("margin_bottom", 10)
	_overlay.add_child(overlay_margin)

	_slot_row = HBoxContainer.new()
	_slot_row.name = "Slots"
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", int(slot_spacing))
	overlay_margin.add_child(_slot_row)

	_tooltip = PanelContainer.new()
	_tooltip.name = "ItemTooltip"
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)

	var tooltip_margin := MarginContainer.new()
	tooltip_margin.name = "ContentMargin"
	tooltip_margin.add_theme_constant_override("margin_left", 8)
	tooltip_margin.add_theme_constant_override("margin_top", 6)
	tooltip_margin.add_theme_constant_override("margin_right", 8)
	tooltip_margin.add_theme_constant_override("margin_bottom", 6)
	_tooltip.add_child(tooltip_margin)

	var tooltip_stack := VBoxContainer.new()
	tooltip_stack.name = "Text"
	tooltip_stack.add_theme_constant_override("separation", 2)
	tooltip_margin.add_child(tooltip_stack)

	_tooltip_name = Label.new()
	_tooltip_name.name = "ItemName"
	_tooltip_name.add_theme_font_size_override("font_size", 13)
	_tooltip_name.add_theme_color_override("font_color", Color.WHITE)
	tooltip_stack.add_child(_tooltip_name)

	_tooltip_effect = Label.new()
	_tooltip_effect.name = "ItemEffect"
	_tooltip_effect.add_theme_font_size_override("font_size", 12)
	_tooltip_effect.add_theme_color_override("font_color", Color.WHITE)
	tooltip_stack.add_child(_tooltip_effect)


func _refresh_slots() -> void:
	for child in _slot_row.get_children():
		child.queue_free()

	for slot_index in SLOT_COUNT:
		var slot_button := Button.new()
		slot_button.name = "Slot%d" % (slot_index + 1)
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.custom_minimum_size = slot_size
		slot_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if slot_index < items.size():
			var item := items[slot_index]
			slot_button.text = str(item.get("name", "Item"))
			slot_button.disabled = false
			slot_button.pressed.connect(_on_item_pressed.bind(slot_index, slot_button))
		else:
			slot_button.text = ""
			slot_button.disabled = true
		_slot_row.add_child(slot_button)


func _on_item_pressed(slot_index: int, slot_button: Button) -> void:
	if slot_index < 0 or slot_index >= items.size():
		_hide_tooltip()
		return
	if _tooltip.visible and _tooltip_slot_index == slot_index:
		_hide_tooltip()
		return

	var item := items[slot_index]
	_tooltip_slot_index = slot_index
	_tooltip_name.text = str(item.get("name", "Item"))
	_tooltip_effect.text = str(item.get("effect", ""))
	_tooltip.visible = true
	_tooltip.size = _tooltip.get_combined_minimum_size()

	var slot_position := slot_button.get_global_rect().position
	var tooltip_size := _tooltip.get_combined_minimum_size()
	var viewport_size := _get_layout_size()
	var target_position := Vector2(slot_position.x, slot_position.y + slot_button.size.y + 6.0)
	target_position.x = clampf(target_position.x, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0))
	target_position.y = clampf(target_position.y, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0))
	_tooltip.position = target_position


func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.visible = false
	_tooltip_slot_index = -1


func _layout_inventory() -> void:
	if _backpack_button == null or _overlay == null:
		return

	var viewport_size := _get_layout_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_backpack_button.size = button_size
	_backpack_button.position = Vector2(
		viewport_size.x - button_size.x - right_margin,
		top_margin
	)

	var overlay_width := slot_size.x * SLOT_COUNT + slot_spacing * float(SLOT_COUNT - 1) + 20.0
	var overlay_height := slot_size.y + 20.0
	_overlay.size = Vector2(overlay_width, overlay_height)
	_overlay.position = Vector2(
		clampf(viewport_size.x - overlay_width - right_margin, 8.0, viewport_size.x - overlay_width),
		top_margin + button_size.y + 8.0
	)

	if _tooltip != null and _tooltip.visible:
		_tooltip.position.x = clampf(_tooltip.position.x, 8.0, maxf(8.0, viewport_size.x - _tooltip.size.x - 8.0))
		_tooltip.position.y = clampf(_tooltip.position.y, 8.0, maxf(8.0, viewport_size.y - _tooltip.size.y - 8.0))


func _get_layout_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2.ZERO


func _is_canvas_position_inside_inventory(canvas_position: Vector2) -> bool:
	if _backpack_button != null and _backpack_button.get_global_rect().has_point(canvas_position):
		return true
	if _overlay != null and _overlay.visible and _overlay.get_global_rect().has_point(canvas_position):
		return true
	if _tooltip != null and _tooltip.visible and _tooltip.get_global_rect().has_point(canvas_position):
		return true
	return false
