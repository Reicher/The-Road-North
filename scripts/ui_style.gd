class_name UIStyle
extends RefCounted

const CUSTOM_TYPE := "GameUI"

const DEFAULT_PANEL_FILL := Color(0.96, 0.88, 0.68)
const DEFAULT_PANEL_BORDER := Color(0.34, 0.23, 0.14)
const DEFAULT_TEXT := Color(0.20, 0.14, 0.09)
const DEFAULT_MUTED_TEXT := Color(0.45, 0.32, 0.20)
const DEFAULT_CARD_FILL := Color(0.98, 0.91, 0.72)
const DEFAULT_CARD_ART_FILL := Color(0.66, 0.76, 0.55)
const DEFAULT_ROAD_INK := Color(0.36, 0.27, 0.18)
const DEFAULT_FOCUS := Color(1.0, 0.78, 0.28)

const DEFAULT_CORNER_RADIUS := 14
const DEFAULT_BORDER_WIDTH := 3


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


static func card_art_fill(control: Control) -> Color:
	return color(control, &"card_art_fill", DEFAULT_CARD_ART_FILL)


static func road_ink(control: Control) -> Color:
	return color(control, &"road_ink", DEFAULT_ROAD_INK)


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


static func draw_panel(control: Control, rect: Rect2, fill: Color, border: Color) -> void:
	control.draw_style_box(rounded_box(control, fill, border), rect)


static func _resolved_corner_radius(control: Control, override: int) -> int:
	if override >= 0:
		return override
	return constant(control, &"corner_radius", DEFAULT_CORNER_RADIUS)


static func _resolved_border_width(control: Control, override: int) -> int:
	if override >= 0:
		return override
	return constant(control, &"border_width", DEFAULT_BORDER_WIDTH)
