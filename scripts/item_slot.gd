class_name ItemSlot
extends Button

const ItemIconLibrary = preload("res://scripts/item_icon_library.gd")

signal slot_gui_input(event: InputEvent, slot: ItemSlot)

@export var slot_size := Vector2(82.0, 82.0):
	set(value):
		slot_size = value
		custom_minimum_size = slot_size
		size = slot_size
		if icon != null:
			add_theme_constant_override("icon_max_width", int(slot_size.x))

var slot_index := -1
var item_data: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = slot_size
	size = slot_size
	add_theme_constant_override("icon_max_width", int(slot_size.x))
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


func configure(item: Dictionary, index := -1) -> void:
	item_data = item
	slot_index = index
	if item.is_empty():
		icon = null
		disabled = true
		tooltip_text = ""
	else:
		icon = ItemIconLibrary.get_icon(item)
		disabled = false
		tooltip_text = "%s\n%s" % [item.get("name", "Item"), item.get("effect", "")]


func clear_slot() -> void:
	configure({}, slot_index)


func _on_gui_input(event: InputEvent) -> void:
	slot_gui_input.emit(event, self)
