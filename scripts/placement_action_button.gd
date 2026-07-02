class_name PlacementActionButton
extends Button

enum Action {
	ROTATE_LEFT,
	ROTATE_RIGHT,
	CONFIRM,
	CANCEL,
	WALK,
}

@export var action := Action.CONFIRM
@export var pressed_icon: Texture2D

var _normal_icon: Texture2D


func _ready() -> void:
	_normal_icon = icon
	_apply_styles()
	button_down.connect(_show_pressed_icon)
	button_up.connect(_show_normal_icon)


func _apply_styles() -> void:
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _show_pressed_icon() -> void:
	if pressed_icon != null:
		if _normal_icon == null:
			_normal_icon = icon
		icon = pressed_icon


func _show_normal_icon() -> void:
	icon = _normal_icon
