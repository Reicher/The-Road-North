class_name StatIconPainter
extends RefCounted

const HEART_COLOR := Color(0.84, 0.12, 0.18)
const SWORD_COLOR := Color(0.86, 0.86, 0.78)
const SWORD_HILT_COLOR := Color(0.45, 0.31, 0.16)
const SHIELD_COLOR := Color(0.10, 0.78, 0.82)
const SHIELD_EDGE_COLOR := Color(0.04, 0.36, 0.42)


static func draw_heart(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var radius := size * 0.23
	var left := center + Vector2(-radius * 0.75, -radius * 0.35)
	var right := center + Vector2(radius * 0.75, -radius * 0.35)
	var point := center + Vector2(0.0, size * 0.36)
	canvas.draw_circle(left, radius, HEART_COLOR)
	canvas.draw_circle(right, radius, HEART_COLOR)
	canvas.draw_colored_polygon(PackedVector2Array([
		left + Vector2(-radius, radius * 0.15),
		right + Vector2(radius, radius * 0.15),
		point,
	]), HEART_COLOR)


static func draw_sword(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var blade_top := center + Vector2(size * 0.24, -size * 0.36)
	var blade_bottom := center + Vector2(-size * 0.14, size * 0.08)
	var blade_width := size * 0.10
	canvas.draw_colored_polygon(PackedVector2Array([
		blade_top,
		blade_bottom + Vector2(-blade_width, 0.0),
		blade_bottom + Vector2(blade_width, 0.0),
	]), SWORD_COLOR)
	canvas.draw_line(center + Vector2(-size * 0.28, size * 0.20), center + Vector2(size * 0.10, -size * 0.18), SWORD_COLOR, maxf(2.0, size * 0.10))
	canvas.draw_line(center + Vector2(-size * 0.25, size * 0.00), center + Vector2(size * 0.04, size * 0.28), SWORD_HILT_COLOR, maxf(2.0, size * 0.10))
	canvas.draw_line(center + Vector2(-size * 0.32, size * 0.30), center + Vector2(-size * 0.16, size * 0.14), SWORD_HILT_COLOR, maxf(2.0, size * 0.11))


static func draw_shield(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var half_width := size * 0.30
	var top := center + Vector2(0.0, -size * 0.34)
	var bottom := center + Vector2(0.0, size * 0.38)
	var points := PackedVector2Array([
		top + Vector2(-half_width, size * 0.07),
		top + Vector2(half_width, size * 0.07),
		center + Vector2(half_width * 0.82, size * 0.18),
		bottom,
		center + Vector2(-half_width * 0.82, size * 0.18),
	])
	canvas.draw_colored_polygon(points, SHIELD_COLOR)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, SHIELD_EDGE_COLOR, maxf(1.5, size * 0.08))
