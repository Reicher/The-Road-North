class_name ItemDetailsPopup
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")
const ItemIconLibrary = preload("res://scripts/item_icon_library.gd")

signal closed

var _item_icon: TextureRect
var _name_label: Label
var _meta_label: Label
var _stats: VBoxContainer
var _shade: ColorRect
var _close_button: Button
var _action_button: Button
var _discard_button: Button
var _close_action := Callable()
var _action := Callable()
var _discard_action := Callable()
var _background_blocks_input := true


func _ready() -> void:
	_bind_nodes()
	$Center/Panel.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self), 16, 3))


func _bind_nodes() -> void:
	if _item_icon != null:
		return
	_shade = $Shade as ColorRect
	_item_icon = $Center/Panel/Margin/Stack/Header/ItemIcon as TextureRect
	_name_label = $Center/Panel/Margin/Stack/Header/Heading/ItemName as Label
	_meta_label = $Center/Panel/Margin/Stack/Header/Heading/Meta as Label
	_stats = $Center/Panel/Margin/Stack/Stats as VBoxContainer
	_close_button = $Center/Panel/Margin/Stack/Buttons/CloseButton as Button
	_discard_button = $Center/Panel/Margin/Stack/Buttons/DiscardButton as Button
	_action_button = $Center/Panel/Margin/Stack/Buttons/ActionButton as Button
	if not _close_button.pressed.is_connected(_run_close_action):
		_close_button.pressed.connect(_run_close_action)
	if not _discard_button.pressed.is_connected(_run_discard_action):
		_discard_button.pressed.connect(_run_discard_action)
	if not _action_button.pressed.is_connected(_run_action):
		_action_button.pressed.connect(_run_action)
	if not _shade.gui_input.is_connected(_on_shade_input):
		_shade.gui_input.connect(_on_shade_input)


func show_item(
	item: Dictionary,
	action_label := "",
	action := Callable(),
	action_enabled := true,
	discard_action := Callable(),
	discard_label := "Discard",
	context_label := "",
	close_label := "Close",
	close_action := Callable(),
	background_blocks_input := true
) -> void:
	if item.is_empty():
		return
	_bind_nodes()
	var normalized := ItemCatalog.normalize_item(item)
	_background_blocks_input = background_blocks_input
	_close_action = close_action
	_action = action
	_discard_action = discard_action
	_item_icon.texture = ItemIconLibrary.get_icon(normalized)
	_name_label.text = str(normalized.get("name", "Item"))
	var meta_parts := [
		str(normalized.get("rarity", ItemCatalog.RARITY_COMMON)),
		"BIG ITEM" if str(normalized.get("size", ItemCatalog.SIZE_SMALL)) == ItemCatalog.SIZE_LARGE else "SMALL ITEM",
	]
	if not context_label.is_empty():
		meta_parts.push_front(context_label)
	_meta_label.text = "  •  ".join(meta_parts)
	_populate_stats(normalized)
	_close_button.text = close_label
	_action_button.text = action_label
	_action_button.visible = not action_label.is_empty()
	_action_button.disabled = not action_enabled
	_discard_button.text = discard_label
	_discard_button.visible = discard_action.is_valid()
	_discard_button.disabled = not discard_action.is_valid()
	mouse_filter = Control.MOUSE_FILTER_PASS if background_blocks_input else Control.MOUSE_FILTER_IGNORE
	_shade.visible = background_blocks_input
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP if background_blocks_input else Control.MOUSE_FILTER_IGNORE
	visible = true
	move_to_front()


func hide_popup() -> void:
	if not visible:
		return
	visible = false
	_close_action = Callable()
	_action = Callable()
	_discard_action = Callable()
	_background_blocks_input = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	if _shade != null:
		_shade.visible = true
		_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	if _close_button != null:
		_close_button.text = "Close"
	if _discard_button != null:
		_discard_button.text = "Discard"
	closed.emit()


func _populate_stats(item: Dictionary) -> void:
	for child in _stats.get_children():
		child.free()
	var labels := {
		ItemCatalog.STAT_MAX_HEALTH: "Max Health",
		ItemCatalog.STAT_POWER: "Power",
		ItemCatalog.STAT_SIGHT: "Sight",
		ItemCatalog.STAT_MAX_HAND_SIZE: "Max Hand Size",
	}
	var has_details := false
	for stat_name in ItemCatalog.SUPPORTED_STATS:
		var value := ItemCatalog.get_stat(item, stat_name)
		if value == 0:
			continue
		_add_detail_row(str(labels[stat_name]), "%+d" % value, value > 0)
		has_details = true
	var gold_multiplier := ItemCatalog.get_special_effect(item, "gold_multiplier", 1)
	if gold_multiplier > 1:
		_add_detail_row("Gold gained", "×%d" % gold_multiplier, true)
		has_details = true
	if not has_details:
		_add_detail_row("Effect", "None", false)


func _add_detail_row(title: String, value: String, positive: bool) -> void:
	var row := HBoxContainer.new()
	row.name = title.replace(" ", "") + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", UIStyle.text(self))
	row.add_child(title_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 26)
	value_label.add_theme_color_override("font_color", Color(0.13, 0.48, 0.22) if positive else UIStyle.muted_text(self))
	row.add_child(value_label)
	_stats.add_child(row)


func _run_action() -> void:
	if _action.is_valid():
		_action.call()
	hide_popup()


func _run_close_action() -> void:
	if _close_action.is_valid():
		_close_action.call()
	hide_popup()


func _run_discard_action() -> void:
	if _discard_action.is_valid():
		_discard_action.call()
	hide_popup()


func _on_shade_input(event: InputEvent) -> void:
	if not _background_blocks_input:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_run_close_action()
	elif event is InputEventScreenTouch and event.pressed:
		_run_close_action()
