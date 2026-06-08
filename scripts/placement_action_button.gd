class_name PlacementActionButton
extends Button

enum Action {
	ROTATE,
	CONFIRM,
	CANCEL,
}

const BUTTON_SIZE := 56.0
const BORDER_COLOR := Color(0.96, 0.96, 0.90, 1.0)
const ROTATE_COLOR := Color(0.18, 0.43, 0.70, 1.0)
const CONFIRM_COLOR := Color(0.16, 0.62, 0.30, 1.0)
const CANCEL_COLOR := Color(0.78, 0.18, 0.16, 1.0)
const DISABLED_COLOR := Color(0.34, 0.40, 0.36, 0.82)

@export var action := Action.CONFIRM


func _ready() -> void:
	_apply_styles()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_draw_icon()


func _apply_styles() -> void:
	var fill := _action_color()
	add_theme_stylebox_override("normal", _circle_style(fill, 4.0))
	add_theme_stylebox_override("hover", _circle_style(fill.lightened(0.10), 5.0))
	add_theme_stylebox_override("pressed", _circle_style(fill.darkened(0.16), 2.0))
	add_theme_stylebox_override("disabled", _circle_style(DISABLED_COLOR, 2.0))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _circle_style(fill: Color, shadow_size: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(roundi(BUTTON_SIZE * 0.5))
	style.shadow_color = Color(0.04, 0.07, 0.05, 0.55)
	style.shadow_size = roundi(shadow_size)
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _draw_icon() -> void:
	var center := size * 0.5
	var icon_color := Color(1.0, 1.0, 1.0, 0.48 if disabled else 1.0)
	match action:
		Action.ROTATE:
			_draw_rotation_icon(center, icon_color)
		Action.CONFIRM:
			draw_polyline(
				PackedVector2Array([
					center + Vector2(-12.0, 0.0),
					center + Vector2(-3.0, 9.0),
					center + Vector2(14.0, -10.0),
				]),
				icon_color,
				5.0,
				true
			)
		Action.CANCEL:
			draw_line(center + Vector2(-10.0, -10.0), center + Vector2(10.0, 10.0), icon_color, 5.0, true)
			draw_line(center + Vector2(10.0, -10.0), center + Vector2(-10.0, 10.0), icon_color, 5.0, true)


func _draw_rotation_icon(center: Vector2, color: Color) -> void:
	draw_arc(center, 13.0, deg_to_rad(205.0), deg_to_rad(350.0), 18, color, 3.5, true)
	draw_arc(center, 13.0, deg_to_rad(25.0), deg_to_rad(170.0), 18, color, 3.5, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(13.0, -7.0),
		center + Vector2(16.0, 2.0),
		center + Vector2(7.0, 0.0),
	]), color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-13.0, 7.0),
		center + Vector2(-16.0, -2.0),
		center + Vector2(-7.0, 0.0),
	]), color)


func _action_color() -> Color:
	match action:
		Action.ROTATE:
			return ROTATE_COLOR
		Action.CANCEL:
			return CANCEL_COLOR
		_:
			return CONFIRM_COLOR
