class_name SettingsMenu
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

@export var top_margin := 70.0
@export var right_margin := 2.0
@export var button_size := Vector2(64.0, 64.0)
@export var menu_size := Vector2(260.0, 170.0)

var _settings_button: Button
var _menu_panel: PanelContainer
var _resume_button: Button


func _ready() -> void:
	_settings_button = $SettingsButton as Button
	_menu_panel = $SettingsPanel as PanelContainer
	_resume_button = $SettingsPanel/Margin/Stack/ResumeButton as Button

	_settings_button.text = "⚙"
	_settings_button.custom_minimum_size = button_size
	_settings_button.add_theme_font_size_override("font_size", 52)
	_settings_button.add_theme_color_override("font_color", UIStyle.text(self))
	_settings_button.add_theme_color_override("font_hover_color", UIStyle.text(self))
	_settings_button.add_theme_color_override("font_pressed_color", UIStyle.text(self))
	_settings_button.add_theme_color_override("font_outline_color", Color(0.34, 0.23, 0.14, 0.45))
	_settings_button.add_theme_constant_override("outline_size", 1)
	_settings_button.add_theme_stylebox_override("normal", _transparent_stylebox())
	_settings_button.add_theme_stylebox_override("hover", UIStyle.rounded_box(self, Color(1.0, 0.94, 0.78, 0.45), Color(0, 0, 0, 0), 12, 0))
	_settings_button.add_theme_stylebox_override("pressed", UIStyle.rounded_box(self, Color(0.90, 0.72, 0.40, 0.52), Color(0, 0, 0, 0), 12, 0))
	_settings_button.pressed.connect(_toggle_menu)

	_menu_panel.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), Color(0, 0, 0, 0), 16, 0))
	_resume_button.pressed.connect(_close_menu)

	resized.connect(_layout_settings)
	_layout_settings()


func _toggle_menu() -> void:
	_menu_panel.visible = not _menu_panel.visible


func _close_menu() -> void:
	_menu_panel.visible = false


func _layout_settings() -> void:
	var viewport_size := get_viewport_rect().size
	_settings_button.size = button_size
	_settings_button.position = Vector2(
		viewport_size.x - right_margin - button_size.x,
		top_margin
	)
	_menu_panel.size = menu_size
	_menu_panel.position = Vector2(
		clampf(viewport_size.x - right_margin - menu_size.x, 8.0, viewport_size.x - menu_size.x - 8.0),
		top_margin + button_size.y + 8.0
	)


func _transparent_stylebox() -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0)
	stylebox.border_color = Color(0, 0, 0, 0)
	stylebox.set_corner_radius_all(0)
	stylebox.set_border_width_all(0)
	return stylebox
