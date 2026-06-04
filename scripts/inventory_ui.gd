class_name InventoryUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")
const ItemIconLibrary = preload("res://scripts/item_icon_library.gd")
const BACKPACK_ICON_PATH := "res://assets/images/inventory_backpack.png"

signal item_drag_started(slot_index: int, item: Dictionary, source_button: Button, canvas_position: Vector2)
signal item_drag_moved(canvas_position: Vector2)
signal item_drag_finished(slot_index: int, item: Dictionary, source_button: Button, canvas_position: Vector2)
signal stats_changed

const SLOT_COUNT := 3
const EQUIPPED_SLOT_TINT := Color(1.0, 0.86, 0.45)
const NORMAL_SLOT_TINT := Color.WHITE

@export var button_size := Vector2(130.0, 130.0)
@export var slot_size := Vector2(58.0, 58.0)
@export var top_margin := 18.0
@export var right_margin := 18.0
@export var slot_spacing := 6.0
@export var overlay_gap := 0.0
@export var overlay_padding := 8.0
@export var overlay_animation_duration := 0.36

var items: Array[Dictionary] = [
	{
		"name": "Knife",
		"effect": "+1 Power",
		"power": 1,
	},
	{},
	{},
]

var _frame: PanelContainer
var _backpack_button: Button
var _overlay: PanelContainer
var _overlay_title: Label
var _slot_row: HBoxContainer
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_effect: Label
var _drag_ghost: TextureRect
var _ready_completed := false
var _tooltip_slot_index := -1
var _outside_close_enabled := true
var _dragged_slot_index := -1
var _drag_source_button: Button
var _overlay_tween: Tween
var _inventory_open := false


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var current_size := size
	if current_size.x <= 0.0 or current_size.y <= 0.0:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_inventory)
	_bind_scene_nodes()
	_refresh_slots()
	_layout_inventory()
	set_process_input(true)
	set_process_unhandled_input(true)


func _input(event: InputEvent) -> void:
	_handle_drag_input(event)
	_close_on_outside_press(event)


func _unhandled_input(event: InputEvent) -> void:
	_close_on_outside_press(event)


func _close_on_outside_press(event: InputEvent) -> void:
	if not is_open():
		return
	if not _outside_close_enabled:
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
	return _inventory_open


func get_power_bonus() -> int:
	var highest := 0
	for item in items:
		if item.is_empty():
			continue
		highest = maxi(highest, int(item.get("power", 0)))
	return highest


func get_active_items() -> Array[Dictionary]:
	var active_items: Array[Dictionary] = []
	for item in items:
		if not item.is_empty():
			active_items.append(item.duplicate(true))
	return active_items


func has_space() -> bool:
	return _get_first_empty_slot_index() >= 0


func get_free_slot_count() -> int:
	var count := 0
	for item in items:
		if item.is_empty():
			count += 1
	return count


func get_slot_size() -> Vector2:
	return slot_size


func get_slot_spacing() -> float:
	return slot_spacing


func get_inventory_frame_global_rect() -> Rect2:
	if _frame != null:
		return _frame.get_global_rect()
	return Rect2()


func add_item(item: Dictionary) -> bool:
	var slot_index := _get_first_empty_slot_index()
	if slot_index < 0:
		return false
	items[slot_index] = item.duplicate(true)
	_refresh_slots()
	stats_changed.emit()
	return true


func replace_item_at_slot(slot_index: int, item: Dictionary) -> Dictionary:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return {}
	var previous: Dictionary = {}
	if not items[slot_index].is_empty():
		previous = items[slot_index].duplicate(true)
	items[slot_index] = item.duplicate(true)
	_refresh_slots()
	stats_changed.emit()
	return previous


func swap_items(source_slot_index: int, target_slot_index: int) -> bool:
	if source_slot_index < 0 or source_slot_index >= SLOT_COUNT:
		return false
	if target_slot_index < 0 or target_slot_index >= SLOT_COUNT:
		return false
	if items[source_slot_index].is_empty():
		return false
	if source_slot_index == target_slot_index:
		return true
	var source_item := items[source_slot_index].duplicate(true)
	items[source_slot_index] = items[target_slot_index].duplicate(true)
	items[target_slot_index] = source_item
	_refresh_slots()
	stats_changed.emit()
	return true


func get_slot_index_at_canvas_position(canvas_position: Vector2) -> int:
	if _slot_row == null or not is_open():
		return -1
	for index in _slot_row.get_child_count():
		var slot_button := _slot_row.get_child(index) as Button
		if slot_button != null and slot_button.get_global_rect().has_point(canvas_position):
			return index
	return -1


func toggle_inventory() -> void:
	set_inventory_open(not is_open(), true)


func set_inventory_open(open: bool, animate := false) -> void:
	if _overlay == null or _frame == null:
		return
	if _overlay_tween != null:
		_overlay_tween.kill()
		_overlay_tween = null
	var previous_open := _inventory_open
	var transition_start_rect := _get_open_frame_rect() if previous_open else _get_closed_frame_rect()
	_inventory_open = open
	_layout_inventory()
	if open:
		_overlay.visible = true
		_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		if animate and overlay_animation_duration > 0.0:
			if not previous_open:
				_set_frame_rect(_get_closed_frame_rect())
			var open_frame_rect := _get_open_frame_rect()
			_overlay.scale = Vector2(0.05, 1.0)
			_overlay.modulate.a = 1.0
			_overlay_tween = create_tween()
			_overlay_tween.set_parallel(true)
			_overlay_tween.tween_property(_frame, "position", open_frame_rect.position, overlay_animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_overlay_tween.tween_property(_frame, "size", open_frame_rect.size, overlay_animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_overlay_tween.tween_property(_overlay, "scale:x", 1.0, overlay_animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_set_frame_rect(_get_open_frame_rect())
			_overlay.scale = Vector2.ONE
			_overlay.modulate.a = 1.0
	else:
		_hide_tooltip()
		if animate and overlay_animation_duration > 0.0 and _overlay.visible:
			var closed_frame_rect := _get_closed_frame_rect()
			_set_frame_rect(transition_start_rect)
			_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_overlay.visible = true
			_overlay.scale = Vector2.ONE
			_overlay.modulate.a = 1.0
			_overlay_tween = create_tween()
			_overlay_tween.set_parallel(true)
			_overlay_tween.tween_property(_frame, "position", closed_frame_rect.position, overlay_animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_overlay_tween.tween_property(_frame, "size", closed_frame_rect.size, overlay_animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_overlay_tween.tween_property(_overlay, "scale:x", 0.05, overlay_animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_overlay_tween.finished.connect(func() -> void:
				if not _inventory_open:
					_overlay.visible = false
					_set_frame_rect(_get_closed_frame_rect())
					_overlay.scale = Vector2.ONE
			)
		else:
			_overlay.visible = false
			_set_frame_rect(_get_closed_frame_rect())
			_overlay.scale = Vector2.ONE
			_overlay.modulate.a = 1.0
	if not open:
		_hide_tooltip()


func set_outside_close_enabled(enabled: bool) -> void:
	_outside_close_enabled = enabled


func _bind_scene_nodes() -> void:
	_frame = get_node("InventoryFrame") as PanelContainer
	_backpack_button = get_node("BackpackButton") as Button
	_overlay = get_node("InventoryOverlay") as PanelContainer
	_overlay_title = get_node("InventoryOverlay/ContentMargin/Stack/Title") as Label
	_slot_row = get_node("InventoryOverlay/ContentMargin/Stack/Slots") as HBoxContainer
	_tooltip = get_node("ItemTooltip") as PanelContainer
	_tooltip_name = get_node("ItemTooltip/ContentMargin/Text/ItemName") as Label
	_tooltip_effect = get_node("ItemTooltip/ContentMargin/Text/ItemEffect") as Label
	_drag_ghost = get_node("DragGhost") as TextureRect

	_backpack_button.custom_minimum_size = button_size
	_backpack_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_backpack_button.text = ""
	_backpack_button.icon = _load_backpack_icon()
	_backpack_button.expand_icon = true
	_backpack_button.add_theme_stylebox_override("normal", _transparent_stylebox())
	_backpack_button.add_theme_stylebox_override("hover", _transparent_stylebox())
	_backpack_button.add_theme_stylebox_override("pressed", _transparent_stylebox())
	if not _backpack_button.pressed.is_connected(toggle_inventory):
		_backpack_button.pressed.connect(toggle_inventory)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override("panel", UIStyle.rounded_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self), 10, 3))
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.scale = Vector2.ONE
	_overlay.modulate.a = 1.0
	_overlay.add_theme_stylebox_override("panel", _transparent_stylebox())
	_overlay_title.add_theme_color_override("font_color", UIStyle.muted_text(self))
	_overlay_title.add_theme_font_size_override("font_size", 13)
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", int(slot_spacing))
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_name.add_theme_font_size_override("font_size", 13)
	_tooltip_name.add_theme_color_override("font_color", UIStyle.text(self))
	_tooltip_effect.add_theme_font_size_override("font_size", 12)
	_tooltip_effect.add_theme_color_override("font_color", UIStyle.muted_text(self))
	_drag_ghost.visible = false
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.z_index = 1000
	_drag_ghost.top_level = true
	_drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _load_backpack_icon() -> Texture2D:
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(BACKPACK_ICON_PATH))
	if error != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _transparent_stylebox() -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0)
	stylebox.border_color = Color(0, 0, 0, 0)
	stylebox.set_corner_radius_all(0)
	stylebox.set_border_width_all(0)
	return stylebox


func _refresh_slots() -> void:
	for slot_index in SLOT_COUNT:
		var slot_button := _slot_row.get_child(slot_index) as Button
		if slot_button == null:
			continue
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.custom_minimum_size = slot_size
		slot_button.size = slot_size
		slot_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot_button.add_theme_constant_override("icon_max_width", int(slot_size.x))
		if not items[slot_index].is_empty():
			var item := items[slot_index]
			slot_button.text = ""
			slot_button.icon = ItemIconLibrary.get_icon(item)
			slot_button.expand_icon = true
			slot_button.disabled = false
			slot_button.self_modulate = EQUIPPED_SLOT_TINT if _is_equipped_slot(slot_index) else NORMAL_SLOT_TINT
			var input_callback := _on_item_gui_input.bind(slot_index, slot_button)
			if not slot_button.gui_input.is_connected(input_callback):
				slot_button.gui_input.connect(input_callback)
		else:
			slot_button.text = ""
			slot_button.icon = null
			slot_button.disabled = true
			slot_button.self_modulate = NORMAL_SLOT_TINT


func _handle_drag_input(event: InputEvent) -> void:
	if _dragged_slot_index < 0 or _dragged_slot_index >= SLOT_COUNT:
		return
	_mark_input_handled()
	if event is InputEventMouseMotion:
		_update_drag_ghost(event.position)
		item_drag_moved.emit(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_item_drag(event.position)
	elif event is InputEventScreenDrag:
		_update_drag_ghost(event.position)
		item_drag_moved.emit(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_item_drag(event.position)


func _on_item_gui_input(event: InputEvent, slot_index: int, slot_button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		slot_button.accept_event()
		if event.pressed:
			_start_item_drag(slot_index, slot_button, event.position)
		else:
			_finish_item_drag(_event_canvas_position(event, slot_button))
	elif event is InputEventMouseMotion and _dragged_slot_index == slot_index:
		slot_button.accept_event()
		var canvas_position := _event_canvas_position(event, slot_button)
		_update_drag_ghost(canvas_position)
		item_drag_moved.emit(canvas_position)
	elif event is InputEventScreenTouch:
		slot_button.accept_event()
		if event.pressed:
			_start_item_drag(slot_index, slot_button, event.position)
		else:
			_finish_item_drag(event.position)
	elif event is InputEventScreenDrag and _dragged_slot_index == slot_index:
		slot_button.accept_event()
		_update_drag_ghost(event.position)
		item_drag_moved.emit(event.position)


func _start_item_drag(slot_index: int, slot_button: Button, local_position: Vector2) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	if items[slot_index].is_empty():
		return
	_mark_input_handled()
	add_to_group("ui_item_drag_active")
	_dragged_slot_index = slot_index
	_drag_source_button = slot_button
	_show_drag_ghost(items[slot_index], slot_button.get_global_position() + local_position, slot_button.self_modulate)
	item_drag_started.emit(slot_index, items[slot_index].duplicate(true), slot_button, slot_button.get_global_position() + local_position)


func _finish_item_drag(canvas_position: Vector2) -> void:
	if _dragged_slot_index < 0 or _dragged_slot_index >= SLOT_COUNT:
		_cancel_item_drag()
		return
	if items[_dragged_slot_index].is_empty():
		_cancel_item_drag()
		return
	_mark_input_handled()
	var slot_index := _dragged_slot_index
	var item := items[slot_index].duplicate(true)
	var source_button := _drag_source_button
	item_drag_finished.emit(slot_index, item, source_button, canvas_position)
	var target_slot_index := get_slot_index_at_canvas_position(canvas_position)
	if target_slot_index >= 0 and target_slot_index != slot_index:
		swap_items(slot_index, target_slot_index)
	elif source_button != null and source_button.get_global_rect().has_point(canvas_position):
		_on_item_pressed(slot_index, source_button)
	_cancel_item_drag()


func _cancel_item_drag() -> void:
	_dragged_slot_index = -1
	_drag_source_button = null
	remove_from_group("ui_item_drag_active")
	if _drag_ghost != null:
		_drag_ghost.visible = false


func _mark_input_handled() -> void:
	var viewport := get_viewport() if is_inside_tree() else null
	if viewport != null:
		viewport.set_input_as_handled()


func _show_drag_ghost(item: Dictionary, canvas_position: Vector2, tint := Color.WHITE) -> void:
	if _drag_ghost == null:
		return
	_drag_ghost.texture = ItemIconLibrary.get_icon(item)
	_drag_ghost.size = slot_size
	_drag_ghost.modulate = tint
	_drag_ghost.visible = true
	_update_drag_ghost(canvas_position)


func _update_drag_ghost(canvas_position: Vector2) -> void:
	if _drag_ghost == null or not _drag_ghost.visible:
		return
	_drag_ghost.position = canvas_position - _drag_ghost.size * 0.5


func _event_canvas_position(event: InputEvent, source_button: Button) -> Vector2:
	if source_button == null:
		return Vector2.ZERO
	if event is InputEventMouse:
		return source_button.get_global_position() + event.position
	return source_button.get_global_rect().get_center()


func _on_item_pressed(slot_index: int, slot_button: Button) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		_hide_tooltip()
		return
	if items[slot_index].is_empty():
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


func _is_equipped_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if items[slot_index].is_empty():
		return false
	return slot_index == _get_equipped_power_slot_index()


func _get_equipped_power_slot_index() -> int:
	var equipped_index := -1
	var highest := 0
	for index in items.size():
		if items[index].is_empty():
			continue
		var value := int(items[index].get("power", 0))
		if value > highest:
			highest = value
			equipped_index = index
	return equipped_index


func _get_first_empty_slot_index() -> int:
	for index in SLOT_COUNT:
		if items[index].is_empty():
			return index
	return -1


func _layout_inventory() -> void:
	if _backpack_button == null or _overlay == null or _frame == null:
		return

	var viewport_size := _get_layout_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_backpack_button.size = button_size
	_backpack_button.position = Vector2(
		viewport_size.x - button_size.x - right_margin,
		top_margin
	)

	var overlay_width := slot_size.x * SLOT_COUNT + slot_spacing * float(SLOT_COUNT - 1) + overlay_padding * 2.0
	var overlay_height := button_size.y
	_overlay.size = Vector2(overlay_width, overlay_height)
	_overlay.pivot_offset = Vector2(overlay_width, overlay_height * 0.5)
	_overlay.position = Vector2(
		clampf(_backpack_button.position.x - overlay_width - overlay_gap, 8.0, viewport_size.x - overlay_width),
		clampf(_backpack_button.position.y, 8.0, viewport_size.y - overlay_height - 8.0)
	)
	if _overlay_tween == null:
		_set_frame_rect(_get_open_frame_rect() if _inventory_open else _get_closed_frame_rect())

	if _tooltip != null and _tooltip.visible:
		_tooltip.position.x = clampf(_tooltip.position.x, 8.0, maxf(8.0, viewport_size.x - _tooltip.size.x - 8.0))
		_tooltip.position.y = clampf(_tooltip.position.y, 8.0, maxf(8.0, viewport_size.y - _tooltip.size.y - 8.0))


func _get_layout_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		return parent_control.size
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2.ZERO


func _get_closed_frame_rect() -> Rect2:
	if _backpack_button == null:
		return Rect2()
	return Rect2(_backpack_button.position, _backpack_button.size)


func _get_open_frame_rect() -> Rect2:
	if _backpack_button == null or _overlay == null:
		return _get_closed_frame_rect()
	var left := minf(_overlay.position.x, _backpack_button.position.x)
	var top := minf(_overlay.position.y, _backpack_button.position.y)
	var right := maxf(_overlay.position.x + _overlay.size.x, _backpack_button.position.x + _backpack_button.size.x)
	var bottom := maxf(_overlay.position.y + _overlay.size.y, _backpack_button.position.y + _backpack_button.size.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _set_frame_rect(rect: Rect2) -> void:
	if _frame == null:
		return
	_frame.position = rect.position
	_frame.size = rect.size


func _is_canvas_position_inside_inventory(canvas_position: Vector2) -> bool:
	if _backpack_button != null and _backpack_button.get_global_rect().has_point(canvas_position):
		return true
	if _inventory_open and _get_open_frame_rect().has_point(canvas_position):
		return true
	if _overlay != null and _overlay.visible and _overlay.get_global_rect().has_point(canvas_position):
		return true
	if _tooltip != null and _tooltip.visible and _tooltip.get_global_rect().has_point(canvas_position):
		return true
	return false


func is_canvas_position_inside_backpack(canvas_position: Vector2) -> bool:
	return _overlay != null and _overlay.visible and _overlay.get_global_rect().has_point(canvas_position)
