class_name UIStyle
extends RefCounted

const CUSTOM_TYPE := "GameUI"

const DEFAULT_PANEL_FILL := Color(0.96, 0.88, 0.68)
const DEFAULT_PANEL_BORDER := Color(0.34, 0.23, 0.14)
const DEFAULT_TEXT := Color(0.20, 0.14, 0.09)
const DEFAULT_MUTED_TEXT := Color(0.45, 0.32, 0.20)
const DEFAULT_CARD_FILL := Color(0.98, 0.91, 0.72)
const DEFAULT_CARD_TEXT := Color(0.20, 0.14, 0.09)
const DEFAULT_CARD_MUTED_TEXT := Color(0.45, 0.32, 0.20)
const DEFAULT_FOCUS := Color(1.0, 0.83, 0.35)
const DEFAULT_SHADOW := Color(0.13, 0.08, 0.04, 0.52)

const DEFAULT_CORNER_RADIUS := 14
const DEFAULT_BORDER_WIDTH := 3
const DEFAULT_SHADOW_SIZE := 7

const MENU_FRAME_TEXTURE := preload("res://assets/images/ui/frames/wood_frame_9patch.png")
const MENU_BUTTON_FRAME_TEXTURE := preload("res://assets/images/ui/frames/wood_button_frame_9patch.png")

const MENU_PANEL_FRAME_MARGIN := 26.0


static func color(control: Control, name: StringName, fallback: Color) -> Color:
	if control != null and control.has_theme_color(name, CUSTOM_TYPE):
		return control.get_theme_color(name, CUSTOM_TYPE)
	return fallback


static func constant(control: Control, name: StringName, fallback: int) -> int:
	if control != null and control.has_theme_constant(name, CUSTOM_TYPE):
		return control.get_theme_constant(name, CUSTOM_TYPE)
	return fallback


static func panel_fill(control: Control) -> Color:
	return color(control, &"panel_fill", DEFAULT_PANEL_FILL)


static func panel_border(control: Control) -> Color:
	return color(control, &"panel_border", DEFAULT_PANEL_BORDER)


static func text(control: Control) -> Color:
	return color(control, &"text", DEFAULT_TEXT)


static func muted_text(control: Control) -> Color:
	return color(control, &"muted_text", DEFAULT_MUTED_TEXT)


static func card_fill(control: Control) -> Color:
	return color(control, &"card_fill", DEFAULT_CARD_FILL)


static func card_text(control: Control) -> Color:
	return color(control, &"card_text", DEFAULT_CARD_TEXT)


static func card_muted_text(control: Control) -> Color:
	return color(control, &"card_muted_text", DEFAULT_CARD_MUTED_TEXT)


static func focus(control: Control) -> Color:
	return color(control, &"focus", DEFAULT_FOCUS)


static func rounded_box(
	control: Control,
	fill: Color,
	border: Color,
	corner_radius := -1,
	border_width := -1
) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = fill
	style_box.border_color = border
	style_box.set_corner_radius_all(_resolved_corner_radius(control, corner_radius))
	style_box.set_border_width_all(_resolved_border_width(control, border_width))
	return style_box


static func elevated_box(
	control: Control,
	fill: Color,
	border: Color,
	corner_radius := -1,
	border_width := -1
) -> StyleBoxFlat:
	var style_box := rounded_box(control, fill, border, corner_radius, border_width)
	style_box.shadow_color = color(control, &"shadow", DEFAULT_SHADOW)
	style_box.shadow_size = constant(control, &"shadow_size", DEFAULT_SHADOW_SIZE)
	style_box.shadow_offset = Vector2(0.0, 4.0)
	return style_box


static func draw_panel(control: Control, rect: Rect2, fill: Color, border: Color) -> void:
	control.draw_style_box(rounded_box(control, fill, border), rect)


static func menu_panel_style() -> StyleBoxTexture:
	return _menu_frame_style(MENU_FRAME_TEXTURE, Color.WHITE, 20.0, 18.0, -1.0, -1.0, MENU_PANEL_FRAME_MARGIN, MENU_PANEL_FRAME_MARGIN)


static func apply_menu_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _menu_button_style(Color(1.22, 1.12, 0.86, 1.0), 9.0, 7.0))
	button.add_theme_stylebox_override("hover", _menu_button_style(Color(1.32, 1.22, 0.94, 1.0), 9.0, 7.0))
	button.add_theme_stylebox_override("pressed", _menu_button_style(Color(1.02, 0.83, 0.52, 1.0), 12.0, 4.0))
	button.add_theme_stylebox_override("disabled", _menu_button_style(Color(0.72, 0.70, 0.62, 0.78), 9.0, 7.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.78))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.48))
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.72, 0.60))
	button.add_theme_color_override("font_outline_color", Color(0.045, 0.022, 0.008, 0.96))
	button.add_theme_constant_override("outline_size", 3)


static func _menu_button_style(modulate: Color, top_margin: float, bottom_margin: float) -> StyleBoxTexture:
	return _menu_frame_style(MENU_BUTTON_FRAME_TEXTURE, modulate, 18.0, 6.0, top_margin, bottom_margin, 16.0, 12.0)


static func _menu_frame_style(
	texture: Texture2D,
	modulate: Color,
	horizontal_content_margin: float,
	vertical_content_margin: float,
	pressed_top_margin := -1.0,
	pressed_bottom_margin := -1.0,
	horizontal_texture_margin := MENU_PANEL_FRAME_MARGIN,
	vertical_texture_margin := MENU_PANEL_FRAME_MARGIN
) -> StyleBoxTexture:
	var style_box := StyleBoxTexture.new()
	style_box.texture = texture
	style_box.draw_center = true
	style_box.modulate_color = modulate
	style_box.texture_margin_left = horizontal_texture_margin
	style_box.texture_margin_top = vertical_texture_margin
	style_box.texture_margin_right = horizontal_texture_margin
	style_box.texture_margin_bottom = vertical_texture_margin
	style_box.content_margin_left = horizontal_content_margin
	style_box.content_margin_right = horizontal_content_margin
	style_box.content_margin_top = pressed_top_margin if pressed_top_margin >= 0.0 else vertical_content_margin
	style_box.content_margin_bottom = pressed_bottom_margin if pressed_bottom_margin >= 0.0 else vertical_content_margin
	return style_box


static func _resolved_corner_radius(control: Control, override: int) -> int:
	if override >= 0:
		return override
	return constant(control, &"corner_radius", DEFAULT_CORNER_RADIUS)


static func _resolved_border_width(control: Control, override: int) -> int:
	if override >= 0:
		return override
	return constant(control, &"border_width", DEFAULT_BORDER_WIDTH)
