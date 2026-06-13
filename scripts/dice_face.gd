class_name DiceFace
extends Control

@export var face_color := Color(0.96, 0.93, 0.86)
@export var pip_color := Color(0.10, 0.08, 0.06)

var value := 0


func _ready() -> void:
	resized.connect(queue_redraw)


func set_value(next_value: int) -> void:
	value = clampi(next_value, 0, 6)
	queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	var rect := Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)
	draw_style_box(_make_face_style(side), rect)
	if value == 0:
		_draw_question(rect)
		return
	for point in _pip_points(value):
		draw_circle(rect.position + point * rect.size, side * 0.075, pip_color)


func _draw_question(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var font_size := roundi(rect.size.y * 0.48)
	var text_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := rect.position + Vector2(
		(rect.size.x - text_size.x) * 0.5,
		(rect.size.y + text_size.y) * 0.5 - font.get_descent(font_size)
	)
	draw_string(font, baseline, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, pip_color)


func _pip_points(face: int) -> Array[Vector2]:
	var left := 0.27
	var center := 0.5
	var right := 0.73
	var top := 0.27
	var bottom := 0.73
	match face:
		1:
			return [Vector2(center, center)]
		2:
			return [Vector2(left, top), Vector2(right, bottom)]
		3:
			return [Vector2(left, top), Vector2(center, center), Vector2(right, bottom)]
		4:
			return [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]
		5:
			return [Vector2(left, top), Vector2(right, top), Vector2(center, center), Vector2(left, bottom), Vector2(right, bottom)]
		6:
			return [Vector2(left, top), Vector2(right, top), Vector2(left, center), Vector2(right, center), Vector2(left, bottom), Vector2(right, bottom)]
	return []


func _make_face_style(side: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face_color
	style.border_color = pip_color
	style.set_border_width_all(maxi(2, roundi(side * 0.035)))
	style.set_corner_radius_all(roundi(side * 0.14))
	style.shadow_color = Color(0.08, 0.06, 0.04, 0.35)
	style.shadow_size = maxi(2, roundi(side * 0.05))
	style.shadow_offset = Vector2(0.0, 2.0)
	return style
