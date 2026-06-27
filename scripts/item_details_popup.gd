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
var _action_button: Button
var _action := Callable()


func _ready() -> void:
	_bind_nodes()
	$Center/Panel.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self), 16, 3))
	$Center/Panel/Margin/Stack/Buttons/CloseButton.pressed.connect(hide_popup)
	_action_button.pressed.connect(_run_action)
	$Shade.gui_input.connect(_on_shade_input)
	visible = false


func _bind_nodes() -> void:
	if _item_icon != null:
		return
	_item_icon = $Center/Panel/Margin/Stack/Header/ItemIcon as TextureRect
	_name_label = $Center/Panel/Margin/Stack/Header/Heading/ItemName as Label
	_meta_label = $Center/Panel/Margin/Stack/Header/Heading/Meta as Label
	_stats = $Center/Panel/Margin/Stack/Stats as VBoxContainer
	_action_button = $Center/Panel/Margin/Stack/Buttons/ActionButton as Button


func show_item(item: Dictionary, action_label := "", action := Callable(), action_enabled := true) -> void:
	if item.is_empty():
		return
	_bind_nodes()
	var normalized := ItemCatalog.normalize_item(item)
	_action = action
	_item_icon.texture = ItemIconLibrary.get_icon(normalized)
	_name_label.text = str(normalized.get("name", "Item"))
	_meta_label.text = "%s  •  %s" % [
		str(normalized.get("rarity", ItemCatalog.RARITY_COMMON)),
		"BIG ITEM" if str(normalized.get("size", ItemCatalog.SIZE_SMALL)) == ItemCatalog.SIZE_LARGE else "SMALL ITEM",
	]
	_populate_stats(normalized)
	_action_button.text = action_label
	_action_button.visible = not action_label.is_empty()
	_action_button.disabled = not action_enabled
	visible = true
	move_to_front()


func hide_popup() -> void:
	if not visible:
		return
	visible = false
	_action = Callable()
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


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_popup()
	elif event is InputEventScreenTouch and event.pressed:
		hide_popup()
