class_name TitleBackground
extends Control

const SKY_TOP := Color(0.055, 0.12, 0.105)
const SKY_BOTTOM := Color(0.16, 0.25, 0.17)
const ROAD := Color(0.42, 0.31, 0.20)
const ROAD_EDGE := Color(0.22, 0.17, 0.12, 0.58)
const TREE_DARK := Color(0.05, 0.16, 0.10)
const TREE_MID := Color(0.10, 0.26, 0.15)
const FOG := Color(0.80, 0.86, 0.72, 0.12)

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, SKY_BOTTOM)
	var bands := 8
	for index in bands:
		var ratio := float(index) / float(bands - 1)
		var band := Rect2(0.0, size.y * ratio, size.x, size.y / bands + 1.0)
		draw_rect(band, SKY_TOP.lerp(SKY_BOTTOM, ratio))
	_draw_tree_line(0.30, TREE_DARK, 0.0)
	_draw_tree_line(0.40, TREE_MID, 0.45)
	_draw_road()
	_draw_fog()


func _draw_tree_line(y_ratio: float, color: Color, phase: float) -> void:
	var drift := sin(_time * 0.18 + phase) * 8.0
	var base_y := size.y * y_ratio
	var step := maxf(34.0, size.x / 12.0)
	var index := -2
	while float(index) * step < size.x + step * 2.0:
		var x := float(index) * step + drift
		var height := 120.0 + float(posmod(index * 31, 45))
		var width := 68.0 + float(posmod(index * 17, 25))
		var top := Vector2(x + width * 0.5, base_y - height)
		var left := Vector2(x, base_y)
		var right := Vector2(x + width, base_y)
		draw_colored_polygon(PackedVector2Array([top, right, left]), color)
		draw_rect(Rect2(x + width * 0.43, base_y - 18.0, width * 0.14, 46.0), color.darkened(0.35))
		index += 1


func _draw_road() -> void:
	var horizon := size.y * 0.44
	var bottom := size.y
	var center := size.x * (0.5 + sin(_time * 0.11) * 0.012)
	var road_shape := PackedVector2Array([
		Vector2(center - size.x * 0.08, horizon),
		Vector2(center + size.x * 0.08, horizon),
		Vector2(size.x * 0.78, bottom),
		Vector2(size.x * 0.22, bottom),
	])
	draw_colored_polygon(road_shape, ROAD)
	draw_polyline(PackedVector2Array([road_shape[0], road_shape[3]]), ROAD_EDGE, 6.0, true)
	draw_polyline(PackedVector2Array([road_shape[1], road_shape[2]]), ROAD_EDGE, 6.0, true)


func _draw_fog() -> void:
	for index in 4:
		var y := size.y * (0.34 + float(index) * 0.10)
		var x := fposmod(_time * (10.0 + index * 2.0) + index * 180.0, size.x + 240.0) - 120.0
		draw_rect(Rect2(x - 180.0, y, 360.0, 26.0), FOG, true)
