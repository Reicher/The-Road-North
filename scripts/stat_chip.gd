class_name StatChip
extends HBoxContainer

const ICON_PATHS := GameConstants.STAT_ICON_PATHS

@export var stat_name := "":
	set(value):
		stat_name = value
		_load_icon()

@export var icon_size := Vector2(38.0, 38.0):
	set(value):
		icon_size = value
		if _icon != null:
			_icon.custom_minimum_size = icon_size

var _icon: TextureRect
var _value_label: Label


func _ready() -> void:
	_icon = $Icon as TextureRect
	_value_label = $Value as Label
	_icon.custom_minimum_size = icon_size
	_load_icon()


func set_value(text: String) -> void:
	if _value_label != null:
		_value_label.text = text


func get_value() -> String:
	if _value_label != null:
		return _value_label.text
	return ""


func _load_icon() -> void:
	if _icon == null:
		return
	var path := str(ICON_PATHS.get(stat_name, ""))
	if path.is_empty():
		_icon.texture = null
	else:
		_icon.texture = load(path) as Texture2D
