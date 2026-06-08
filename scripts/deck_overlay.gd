class_name DeckOverlay
extends PanelContainer

const UIStyle = preload("res://scripts/ui_style.gd")

signal close_requested

var _title_label: Label
var _list: VBoxContainer
var _close_button: Button


func _ready() -> void:
	_title_label = $Margin/Stack/Title as Label
	_list = $Margin/Stack/Scroll/List as VBoxContainer
	_close_button = $Margin/Stack/CloseButton as Button
	if not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)
	visible = false
	add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self)))


func show_overlay(title_text: String) -> void:
	_title_label.text = title_text
	visible = true


func hide_overlay() -> void:
	visible = false


func clear_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


func add_list_button(text: String, disabled_state: bool, callback: Callable = Callable()) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled_state
	if callback.is_valid():
		button.pressed.connect(callback)
	_list.add_child(button)
	return button


func add_list_label(text: String, font_size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	_list.add_child(label)
	return label


func _on_close_pressed() -> void:
	hide_overlay()
	close_requested.emit()
