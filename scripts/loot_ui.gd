class_name LootUI
extends Control

@export var player_path: NodePath
@export var inventory_path: NodePath
@export var panel_size := Vector2(286.0, 310.0)

var loot: Array[Dictionary] = []

var _player: GamePlayer
var _inventory: InventoryUI
var _panel: PanelContainer
var _loot_list: VBoxContainer
var _take_all_button: Button
var _close_button: Button
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_effect: Label
var _dragged_item_index := -1
var _drag_source_button: Button
var _backpack_drag_slot_index := -1
var _backpack_drag_item: Dictionary = {}
var _backpack_drag_source_button: Button
var _drag_ghost: Label
var _ready_completed := false


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resolve_paths()
	resized.connect(_layout_loot)
	_build_loot_screen()
	_layout_loot()
	visible = false
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _dragged_item_index < 0 and _backpack_drag_slot_index < 0:
		return
	if event is InputEventMouseMotion:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _dragged_item_index >= 0:
			_finish_drag(event.position)
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		if _dragged_item_index >= 0:
			_finish_drag(event.position)


func open_loot(new_loot: Array) -> void:
	_resolve_paths()
	loot.clear()
	_hide_tooltip()
	for entry in new_loot:
		if entry is Dictionary:
			var entry_copy: Dictionary = entry.duplicate(true)
			if _collect_resource_entry(entry_copy):
				continue
			loot.append(entry_copy)
	visible = not loot.is_empty()
	if visible and _inventory != null:
		_inventory.set_inventory_open(true)
		_inventory.set_outside_close_enabled(false)
	_refresh_loot()
	_layout_loot()


func close_loot() -> void:
	loot.clear()
	_cancel_drag()
	_cancel_backpack_drag()
	_hide_tooltip()
	visible = false
	if _inventory != null:
		_inventory.set_outside_close_enabled(true)
	_refresh_loot()


func is_open() -> bool:
	return visible


func take_all() -> void:
	_resolve_paths()
	for index in range(loot.size() - 1, -1, -1):
		var entry := loot[index]
		if _collect_loot_entry(entry):
			loot.remove_at(index)
	_refresh_loot()
	if loot.is_empty():
		close_loot()


func _build_loot_screen() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0.0, 0.0, 0.0, 0.38)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	_panel = PanelContainer.new()
	_panel.name = "LootPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var title := Label.new()
	title.name = "Title"
	title.text = "Loot"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	stack.add_child(title)

	_loot_list = VBoxContainer.new()
	_loot_list.name = "LootList"
	_loot_list.add_theme_constant_override("separation", 6)
	_loot_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_loot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_loot_list)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 8)
	stack.add_child(button_row)

	_take_all_button = Button.new()
	_take_all_button.name = "TakeAllButton"
	_take_all_button.text = "Take All"
	_take_all_button.focus_mode = Control.FOCUS_NONE
	_take_all_button.pressed.connect(take_all)
	button_row.add_child(_take_all_button)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Close"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(close_loot)
	button_row.add_child(_close_button)

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


func _refresh_loot() -> void:
	if _loot_list == null:
		return
	for child in _loot_list.get_children():
		_loot_list.remove_child(child)
		child.free()

	for index in loot.size():
		var entry := loot[index]
		if _is_item_loot(entry):
			var item_button := Button.new()
			item_button.name = "LootItem%d" % index
			item_button.text = _format_loot_entry(entry)
			item_button.focus_mode = Control.FOCUS_NONE
			item_button.custom_minimum_size = _get_loot_slot_size()
			item_button.size = _get_loot_slot_size()
			item_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			item_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			item_button.gui_input.connect(_on_item_gui_input.bind(index, item_button))
			_loot_list.add_child(item_button)
		else:
			var resource_label := Label.new()
			resource_label.name = "LootResource%d" % index
			resource_label.text = _format_loot_entry(entry)
			resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			resource_label.custom_minimum_size = Vector2(240.0, 34.0)
			_loot_list.add_child(resource_label)


func _on_item_gui_input(event: InputEvent, item_index: int, source_button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(item_index, source_button, event.position)
		else:
			_finish_drag(_event_canvas_position(event, source_button))
	elif event is InputEventMouseMotion and _dragged_item_index == item_index:
		_update_drag(_event_canvas_position(event, source_button))
	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(item_index, source_button, event.position)
		else:
			_finish_drag(event.position)
	elif event is InputEventScreenDrag and _dragged_item_index == item_index:
		_update_drag(event.position)


func _start_drag(item_index: int, source_button: Button, local_position: Vector2) -> void:
	if item_index < 0 or item_index >= loot.size():
		return
	if not _is_item_loot(loot[item_index]):
		return
	_dragged_item_index = item_index
	_drag_source_button = source_button
	if _drag_ghost == null:
		_drag_ghost = Label.new()
		_drag_ghost.name = "DragGhost"
		_drag_ghost.add_theme_color_override("font_color", Color.WHITE)
		_drag_ghost.add_theme_font_size_override("font_size", 14)
		_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_drag_ghost)
	_drag_ghost.text = source_button.text
	_drag_ghost.visible = true
	_update_drag(source_button.get_global_position() + local_position)


func _update_drag(canvas_position: Vector2) -> void:
	if _drag_ghost == null:
		return
	_drag_ghost.position = canvas_position + Vector2(12.0, -18.0)


func _finish_drag(canvas_position: Vector2) -> void:
	if _dragged_item_index < 0 or _dragged_item_index >= loot.size():
		_cancel_drag()
		return

	_resolve_paths()
	if _inventory != null and _inventory.is_open() and _inventory.is_canvas_position_inside_backpack(canvas_position):
		var slot_index := _inventory.get_slot_index_at_canvas_position(canvas_position)
		var entry := loot[_dragged_item_index]
		if slot_index >= 0:
			var previous := _inventory.replace_item_at_slot(slot_index, entry.get("item", {}).duplicate(true))
			if previous.is_empty():
				loot.remove_at(_dragged_item_index)
			else:
				loot[_dragged_item_index]["item"] = previous
			_hide_tooltip()
			_refresh_loot()
			if loot.is_empty():
				close_loot()
			_cancel_drag()
			return
		elif _inventory.add_item(entry.get("item", {}).duplicate(true)):
			loot.remove_at(_dragged_item_index)
			_hide_tooltip()
			_refresh_loot()
			if loot.is_empty():
				close_loot()
			_cancel_drag()
			return
	if _drag_source_button != null:
		_show_item_tooltip(_dragged_item_index, _drag_source_button)
	_cancel_drag()


func _cancel_drag() -> void:
	_dragged_item_index = -1
	_drag_source_button = null
	if _drag_ghost != null:
		_drag_ghost.visible = false


func _start_backpack_drag(slot_index: int, item: Dictionary, _source_button: Button, canvas_position: Vector2) -> void:
	if not is_open():
		return
	_backpack_drag_slot_index = slot_index
	_backpack_drag_item = item.duplicate(true)
	_backpack_drag_source_button = _source_button
	_show_drag_ghost(str(item.get("name", "Item")), canvas_position)


func _move_backpack_drag(canvas_position: Vector2) -> void:
	if _backpack_drag_slot_index < 0:
		return
	_update_drag(canvas_position)


func _finish_backpack_drag(slot_index: int, item: Dictionary, _source_button: Button, canvas_position: Vector2) -> void:
	if _backpack_drag_slot_index < 0:
		return
	var loot_index := get_loot_item_index_at_canvas_position(canvas_position)
	if loot_index >= 0 and _inventory != null:
		var loot_item: Dictionary = loot[loot_index].get("item", {}).duplicate(true)
		loot[loot_index]["item"] = item.duplicate(true)
		_inventory.replace_item_at_slot(slot_index, loot_item)
		_hide_tooltip()
		_refresh_loot()
	_cancel_backpack_drag()


func _cancel_backpack_drag() -> void:
	_backpack_drag_slot_index = -1
	_backpack_drag_item.clear()
	_backpack_drag_source_button = null
	if _drag_ghost != null and _dragged_item_index < 0:
		_drag_ghost.visible = false


func _collect_loot_entry(entry: Dictionary) -> bool:
	var kind := str(entry.get("kind", "item"))
	if _collect_resource_entry(entry):
		return true
	if kind == "item":
		return _inventory != null and _inventory.add_item(entry.get("item", {}).duplicate(true))
	return false


func _collect_resource_entry(entry: Dictionary) -> bool:
	var kind := str(entry.get("kind", "item"))
	if kind == "food":
		if _player != null:
			_player.add_food(int(entry.get("amount", 0)))
		return true
	if kind == "gold":
		if _player != null:
			_player.add_gold(int(entry.get("amount", 0)))
		return true
	return false


func _format_loot_entry(entry: Dictionary) -> String:
	var kind := str(entry.get("kind", "item"))
	if kind == "food":
		return "+%d Food" % int(entry.get("amount", 0))
	if kind == "gold":
		return "+%d Gold" % int(entry.get("amount", 0))
	var item: Dictionary = entry.get("item", {})
	return str(item.get("name", "Item"))


func _is_item_loot(entry: Dictionary) -> bool:
	return str(entry.get("kind", "item")) == "item"


func _resolve_paths() -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as GamePlayer
	if _inventory == null:
		_inventory = get_node_or_null(inventory_path) as InventoryUI
		if _inventory != null:
			if not _inventory.item_drag_started.is_connected(_start_backpack_drag):
				_inventory.item_drag_started.connect(_start_backpack_drag)
			if not _inventory.item_drag_moved.is_connected(_move_backpack_drag):
				_inventory.item_drag_moved.connect(_move_backpack_drag)
			if not _inventory.item_drag_finished.is_connected(_finish_backpack_drag):
				_inventory.item_drag_finished.connect(_finish_backpack_drag)


func _get_loot_slot_size() -> Vector2:
	if _inventory != null:
		return _inventory.get_slot_size()
	return Vector2(82.0, 82.0)


func get_loot_item_index_at_canvas_position(canvas_position: Vector2) -> int:
	if _loot_list == null or not is_open():
		return -1
	for index in _loot_list.get_child_count():
		var item_button := _loot_list.get_child(index) as Button
		if item_button != null and item_button.get_global_rect().has_point(canvas_position):
			var item_index := int(str(item_button.name).trim_prefix("LootItem"))
			if item_index >= 0 and item_index < loot.size() and _is_item_loot(loot[item_index]):
				return item_index
	return -1


func _event_canvas_position(event: InputEvent, source_button: Button) -> Vector2:
	if source_button == null:
		return Vector2.ZERO
	if event is InputEventMouse:
		return source_button.get_global_position() + event.position
	return source_button.get_global_rect().get_center()


func _show_drag_ghost(text: String, canvas_position: Vector2) -> void:
	if _drag_ghost == null:
		_drag_ghost = Label.new()
		_drag_ghost.name = "DragGhost"
		_drag_ghost.add_theme_color_override("font_color", Color.WHITE)
		_drag_ghost.add_theme_font_size_override("font_size", 14)
		_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_drag_ghost)
	_drag_ghost.text = text
	_drag_ghost.visible = true
	_update_drag(canvas_position)


func _show_item_tooltip(item_index: int, source_button: Button) -> void:
	if item_index < 0 or item_index >= loot.size() or _tooltip == null:
		_hide_tooltip()
		return
	var item: Dictionary = loot[item_index].get("item", {})
	_tooltip_name.text = str(item.get("name", "Item"))
	_tooltip_effect.text = str(item.get("effect", ""))
	_tooltip.visible = true
	_tooltip.size = _tooltip.get_combined_minimum_size()

	var slot_position := source_button.get_global_rect().position
	var tooltip_size := _tooltip.get_combined_minimum_size()
	var viewport_size := _get_layout_size()
	var target_position := Vector2(slot_position.x, slot_position.y + source_button.size.y + 6.0)
	target_position.x = clampf(target_position.x, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0))
	target_position.y = clampf(target_position.y, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0))
	_tooltip.position = target_position


func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.visible = false


func _get_layout_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2.ZERO


func _layout_loot() -> void:
	if _panel == null:
		return
	var viewport_size := _get_layout_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var width := minf(panel_size.x, maxf(260.0, viewport_size.x - 28.0))
	var height := minf(panel_size.y, maxf(250.0, viewport_size.y - 80.0))
	_panel.size = Vector2(width, height)
	_panel.position = (viewport_size - _panel.size) * 0.5

	if _tooltip != null and _tooltip.visible:
		_tooltip.position.x = clampf(_tooltip.position.x, 8.0, maxf(8.0, viewport_size.x - _tooltip.size.x - 8.0))
		_tooltip.position.y = clampf(_tooltip.position.y, 8.0, maxf(8.0, viewport_size.y - _tooltip.size.y - 8.0))
