class_name LootUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")
const ItemIconLibrary = preload("res://scripts/item_icon_library.gd")
const ITEM_SLOT_SCENE := preload("res://ui/item_slot.tscn")
const FULL_INVENTORY_FLASH_COLOR := Color(1.0, 0.32, 0.28)
const FULL_INVENTORY_FLASH_DURATION := 0.28
const TOOLTIP_VISIBLE_DURATION := 1.5

@export var player_path: NodePath
@export var inventory_path: NodePath
@export var panel_size := Vector2(286.0, 310.0)

var loot: Array[Dictionary] = []

var _player: GamePlayer
var _rewards: PlayerRewards
var _inventory: InventoryUI
var _dimmer: ColorRect
var _panel: PanelContainer
var _loot_list: VBoxContainer
var _take_all_button: Button
var _close_button: Button
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_effect: Label
var _tooltip_item_index := -1
var _tooltip_hide_tween: Tween
var _dragged_item_index := -1
var _drag_source_button: Button
var _backpack_drag_slot_index := -1
var _drag_ghost: TextureRect
var _ready_completed := false
var _full_inventory_flash_tween: Tween


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	_resolve_paths()
	resized.connect(_layout_loot)
	_bind_scene_nodes()
	_layout_loot()
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
	mouse_filter = Control.MOUSE_FILTER_STOP if not loot.is_empty() else Control.MOUSE_FILTER_IGNORE
	if not loot.is_empty() and _inventory != null:
		_inventory.set_inventory_open(true)
		_inventory.set_outside_close_enabled(false)
	_refresh_loot()
	_layout_loot()


func close_loot() -> void:
	loot.clear()
	_reset_full_inventory_flash()
	_cancel_drag()
	_cancel_backpack_drag()
	_hide_tooltip()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _inventory != null:
		_inventory.set_outside_close_enabled(true)
	_refresh_loot()


func is_open() -> bool:
	return visible and not loot.is_empty()


func take_all() -> void:
	_resolve_paths()
	_hide_tooltip()
	if not _can_take_all():
		_flash_inventory_full()
		return
	for index in range(loot.size() - 1, -1, -1):
		var entry := loot[index]
		if _collect_loot_entry(entry):
			loot.remove_at(index)
	_refresh_loot()
	if loot.is_empty():
		if _inventory != null:
			_inventory.set_inventory_open(false)
		close_loot()


func _bind_scene_nodes() -> void:
	_dimmer = get_node("Dimmer") as ColorRect
	_panel = get_node("LootPanel") as PanelContainer
	_loot_list = get_node("LootPanel/ContentMargin/Stack/LootList") as VBoxContainer
	_take_all_button = get_node("LootPanel/ContentMargin/Stack/ButtonRow/TakeAllButton") as Button
	_close_button = get_node("LootPanel/ContentMargin/Stack/ButtonRow/CloseButton") as Button
	_tooltip = get_node("ItemTooltip") as PanelContainer
	_tooltip_name = get_node("ItemTooltip/ContentMargin/Text/ItemName") as Label
	_tooltip_effect = get_node("ItemTooltip/ContentMargin/Text/ItemEffect") as Label
	_drag_ghost = get_node("DragGhost") as TextureRect

	if not _take_all_button.pressed.is_connected(take_all):
		_take_all_button.pressed.connect(take_all)
	if not _close_button.pressed.is_connected(close_loot):
		_close_button.pressed.connect(close_loot)


func _refresh_loot() -> void:
	if _loot_list == null:
		return
	for child in _loot_list.get_children():
		_loot_list.remove_child(child)
		child.free()

	for index in loot.size():
		var entry := loot[index]
		if _is_item_loot(entry):
			var loot_slot_size := _get_loot_slot_size()
			var item_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
			item_slot.name = "LootItem%d" % index
			item_slot.slot_size = loot_slot_size
			item_slot.configure(entry.get("item", {}), index)
			item_slot.slot_gui_input.connect(_on_item_slot_gui_input)
			_loot_list.add_child(item_slot)


func _on_item_slot_gui_input(event: InputEvent, slot: ItemSlot) -> void:
	var item_index := slot.slot_index
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		slot.accept_event()
		if event.pressed:
			_start_drag(item_index, slot, _event_canvas_position(event, slot))
		else:
			_finish_drag(_event_canvas_position(event, slot))
	elif event is InputEventMouseMotion and _dragged_item_index == item_index:
		slot.accept_event()
		_update_drag(_event_canvas_position(event, slot))
	elif event is InputEventScreenTouch:
		slot.accept_event()
		if event.pressed:
			_start_drag(item_index, slot, event.position)
		else:
			_finish_drag(event.position)
	elif event is InputEventScreenDrag and _dragged_item_index == item_index:
		slot.accept_event()
		_update_drag(event.position)


func _start_drag(item_index: int, source_button: Button, canvas_position: Vector2) -> void:
	if item_index < 0 or item_index >= loot.size():
		return
	if not _is_item_loot(loot[item_index]):
		return
	_mark_input_handled()
	add_to_group("ui_item_drag_active")
	_dragged_item_index = item_index
	_drag_source_button = source_button
	_drag_ghost.texture = ItemIconLibrary.get_icon(loot[item_index].get("item", {}))
	_drag_ghost.custom_minimum_size = _get_loot_slot_size()
	_drag_ghost.size = _get_loot_slot_size()
	_drag_ghost.modulate = source_button.self_modulate
	_drag_ghost.visible = true
	_update_drag(canvas_position)


func _update_drag(canvas_position: Vector2) -> void:
	if _drag_ghost == null:
		return
	_mark_input_handled()
	_drag_ghost.position = canvas_position - _drag_ghost.size * 0.5


func _finish_drag(canvas_position: Vector2) -> void:
	if _dragged_item_index < 0 or _dragged_item_index >= loot.size():
		_cancel_drag()
		return
	_mark_input_handled()

	if _drag_source_button != null and canvas_position.distance_to(_drag_source_button.get_global_rect().get_center()) <= 2.0:
		_show_item_tooltip(_dragged_item_index, _drag_source_button)
		_cancel_drag()
		return

	var target_loot_index := get_loot_item_index_at_canvas_position(canvas_position)
	if target_loot_index >= 0 and target_loot_index != _dragged_item_index:
		var target_item: Dictionary = loot[target_loot_index].get("item", {}).duplicate(true)
		loot[target_loot_index]["item"] = loot[_dragged_item_index].get("item", {}).duplicate(true)
		loot[_dragged_item_index]["item"] = target_item
		_hide_tooltip()
		_refresh_loot()
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
	remove_from_group("ui_item_drag_active")
	if _drag_ghost != null:
		_drag_ghost.visible = false


func _start_backpack_drag(slot_index: int, _item: Dictionary, _source_button: Button, _canvas_position: Vector2) -> void:
	if not is_open():
		return
	_mark_input_handled()
	add_to_group("ui_item_drag_active")
	_backpack_drag_slot_index = slot_index


func _move_backpack_drag(_canvas_position: Vector2) -> void:
	if _backpack_drag_slot_index < 0:
		return
	_mark_input_handled()


func _finish_backpack_drag(slot_index: int, item: Dictionary, _source_button: Button, canvas_position: Vector2) -> void:
	if _backpack_drag_slot_index < 0:
		return
	_mark_input_handled()
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
	remove_from_group("ui_item_drag_active")
	if _drag_ghost != null and _dragged_item_index < 0:
		_drag_ghost.visible = false


func _collect_loot_entry(entry: Dictionary) -> bool:
	if _rewards != null:
		return _rewards.collect_entry(entry)
	return false


func _collect_resource_entry(entry: Dictionary) -> bool:
	var kind := str(entry.get("kind", "item"))
	if kind == "food" or kind == "gold":
		if _rewards != null:
			_rewards.collect_entry(entry)
		return true
	return false


func _can_take_all() -> bool:
	if _inventory == null:
		return false
	var required_slots := 0
	for entry in loot:
		if not _is_item_loot(entry):
			return false
		required_slots += 1
	return required_slots <= _inventory.get_free_slot_count()


func _flash_inventory_full() -> void:
	if _panel == null:
		return
	if _full_inventory_flash_tween != null:
		_full_inventory_flash_tween.kill()
	_panel.self_modulate = FULL_INVENTORY_FLASH_COLOR
	_full_inventory_flash_tween = create_tween()
	_full_inventory_flash_tween.set_trans(Tween.TRANS_SINE)
	_full_inventory_flash_tween.set_ease(Tween.EASE_OUT)
	_full_inventory_flash_tween.tween_property(_panel, "self_modulate", Color.WHITE, FULL_INVENTORY_FLASH_DURATION)
	_full_inventory_flash_tween.finished.connect(func() -> void:
		_full_inventory_flash_tween = null
	)


func _reset_full_inventory_flash() -> void:
	if _full_inventory_flash_tween != null:
		_full_inventory_flash_tween.kill()
		_full_inventory_flash_tween = null
	if _panel != null:
		_panel.self_modulate = Color.WHITE


func _is_item_loot(entry: Dictionary) -> bool:
	return str(entry.get("kind", "item")) == "item"


func _resolve_paths() -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as GamePlayer
	if _player != null and _rewards == null:
		_rewards = _player.get_node_or_null("Rewards") as PlayerRewards
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
		var item_slot := _loot_list.get_child(index) as ItemSlot
		if item_slot != null and item_slot.get_global_rect().has_point(canvas_position):
			var item_index := item_slot.slot_index
			if item_index >= 0 and item_index < loot.size() and _is_item_loot(loot[item_index]):
				return item_index
	return -1


func _event_canvas_position(event: InputEvent, source_button: Button) -> Vector2:
	return UIUtils.event_canvas_position(event, source_button)


func _mark_input_handled() -> void:
	UIUtils.mark_input_handled(self)


func _show_item_tooltip(item_index: int, source_button: Button) -> void:
	if item_index < 0 or item_index >= loot.size() or _tooltip == null:
		_hide_tooltip()
		return
	if _tooltip.visible and _tooltip_item_index == item_index:
		_hide_tooltip()
		return
	var item: Dictionary = loot[item_index].get("item", {})
	_tooltip_item_index = item_index
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
	_schedule_tooltip_hide()


func _hide_tooltip() -> void:
	if _tooltip_hide_tween != null:
		_tooltip_hide_tween.kill()
		_tooltip_hide_tween = null
	if _tooltip != null:
		_tooltip.visible = false
	_tooltip_item_index = -1


func _schedule_tooltip_hide() -> void:
	if _tooltip_hide_tween != null:
		_tooltip_hide_tween.kill()
	_tooltip_hide_tween = create_tween()
	_tooltip_hide_tween.tween_interval(TOOLTIP_VISIBLE_DURATION)
	_tooltip_hide_tween.finished.connect(func() -> void:
		_tooltip_hide_tween = null
		_hide_tooltip()
	)


func _get_layout_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		return parent_control.size
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2.ZERO


func _layout_loot() -> void:
	if _panel == null:
		return
	var viewport_size := _get_layout_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if _dimmer != null:
		_dimmer.visible = visible and not loot.is_empty()
	_panel.visible = visible and not loot.is_empty()
	var content_size := _panel.get_combined_minimum_size()
	var max_size := Vector2(
		minf(panel_size.x, viewport_size.x - 28.0),
		minf(panel_size.y, viewport_size.y - 80.0)
	)
	var width := minf(content_size.x, max_size.x)
	var height := minf(content_size.y, max_size.y)
	_panel.size = Vector2(width, height)
	var target_position := _get_loot_panel_position(viewport_size, _panel.size)
	_panel.position = target_position

	if _tooltip != null and _tooltip.visible:
		_tooltip.position.x = clampf(_tooltip.position.x, 8.0, maxf(8.0, viewport_size.x - _tooltip.size.x - 8.0))
		_tooltip.position.y = clampf(_tooltip.position.y, 8.0, maxf(8.0, viewport_size.y - _tooltip.size.y - 8.0))


func _get_loot_panel_position(viewport_size: Vector2, loot_panel_size: Vector2) -> Vector2:
	var target_position := Vector2(
		14.0,
		clampf(viewport_size.y - loot_panel_size.y - 118.0, 168.0, maxf(168.0, viewport_size.y - loot_panel_size.y - 14.0))
	)
	if _inventory != null and _inventory.is_open():
		var inventory_rect := _inventory.get_inventory_frame_global_rect()
		if inventory_rect.size.x > 0.0 and inventory_rect.size.y > 0.0:
			target_position.x = clampf(inventory_rect.position.x, 8.0, maxf(8.0, viewport_size.x - loot_panel_size.x - 8.0))
			target_position.y = clampf(inventory_rect.position.y + inventory_rect.size.y + 6.0, 8.0, maxf(8.0, viewport_size.y - loot_panel_size.y - 8.0))
	return target_position
