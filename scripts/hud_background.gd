class_name HudBackground
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

@export var margin := 0.0
@export var top_bar_height := 76.0
@export var pocket_overlap := 8.0
@export var backpack_width := 154.0
@export var backpack_height := 170.0
@export var settings_width := 68.0
@export var settings_height := 68.0
@export var inner_corner_radius := 16.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_panel)
	_layout_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panel()


func _draw() -> void:
	var fill := UIStyle.panel_fill(self)
	var top_panel := _top_bar_style(fill)
	var backpack_panel := _backpack_pocket_style(fill)
	var settings_panel := _settings_pocket_style(fill)
	var top_rect := Rect2(Vector2.ZERO, Vector2(size.x, top_bar_height))
	var pocket_top := top_bar_height - pocket_overlap
	var backpack_rect := Rect2(
		Vector2(0.0, pocket_top),
		Vector2(minf(backpack_width, size.x), backpack_height)
	)
	var settings_rect := Rect2(
		Vector2(maxf(0.0, size.x - settings_width), pocket_top),
		Vector2(minf(settings_width, size.x), settings_height)
	)

	draw_style_box(top_panel, top_rect)
	draw_style_box(backpack_panel, backpack_rect)
	draw_style_box(settings_panel, settings_rect)
	_draw_inner_corner(Vector2(backpack_rect.end.x, top_bar_height), false, fill)
	_draw_inner_corner(Vector2(settings_rect.position.x, top_bar_height), true, fill)


func _layout_panel() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2(margin, margin)
	var panel_height := maxf(top_bar_height, top_bar_height - pocket_overlap + backpack_height)
	size = Vector2(maxf(1.0, viewport_size.x - margin * 2.0), panel_height)
	queue_redraw()


func _top_bar_style(fill: Color) -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = fill
	stylebox.border_color = Color(0, 0, 0, 0)
	stylebox.set_border_width_all(0)
	stylebox.corner_radius_top_left = 0
	stylebox.corner_radius_top_right = 0
	stylebox.corner_radius_bottom_left = 0
	stylebox.corner_radius_bottom_right = 0
	return stylebox


func _backpack_pocket_style(fill: Color) -> StyleBoxFlat:
	var stylebox := _square_style(fill)
	stylebox.corner_radius_bottom_right = 18
	return stylebox


func _settings_pocket_style(fill: Color) -> StyleBoxFlat:
	var stylebox := _square_style(fill)
	stylebox.corner_radius_bottom_left = 18
	return stylebox


func _square_style(fill: Color) -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = fill
	stylebox.border_color = Color(0, 0, 0, 0)
	stylebox.set_border_width_all(0)
	stylebox.set_corner_radius_all(0)
	return stylebox


func _draw_inner_corner(corner: Vector2, opens_left: bool, fill: Color) -> void:
	var radius := maxf(0.0, inner_corner_radius)
	if radius <= 0.0:
		return
	var points := PackedVector2Array([corner])
	var center := corner + Vector2(-radius if opens_left else radius, radius)
	var start_angle := -PI * 0.5
	var end_angle := 0.0 if opens_left else -PI
	for step in 9:
		var weight := float(step) / 8.0
		var angle := lerpf(start_angle, end_angle, weight)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, fill)
