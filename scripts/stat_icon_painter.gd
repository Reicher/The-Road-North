class_name StatIconPainter
extends RefCounted

const HEART_COLOR := Color(0.84, 0.12, 0.18)
const SWORD_COLOR := Color(0.86, 0.86, 0.78)
const SWORD_HILT_COLOR := Color(0.45, 0.31, 0.16)
const FOOD_COLOR := Color(0.92, 0.64, 0.28)
const FOOD_EDGE_COLOR := Color(0.48, 0.26, 0.10)
const GOLD_COLOR := Color(0.96, 0.75, 0.20)
const GOLD_EDGE_COLOR := Color(0.54, 0.34, 0.08)
const BAG_COLOR := Color(0.62, 0.39, 0.18)
const BAG_EDGE_COLOR := Color(0.28, 0.17, 0.08)
const BAG_STRAP_COLOR := Color(0.91, 0.72, 0.38)


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
	var blade_top := center + Vector2(size * 0.30, -size * 0.40)
	var blade_bottom := center + Vector2(-size * 0.06, size * 0.02)
	var blade_normal := Vector2(-0.76, -0.65)
	var blade_width := size * 0.09
	var edge_color := Color(0.36, 0.36, 0.34)
	canvas.draw_colored_polygon(PackedVector2Array([
		blade_top,
		blade_bottom + blade_normal * blade_width,
		blade_bottom - blade_normal * blade_width,
	]), SWORD_COLOR)
	canvas.draw_line(blade_top + Vector2(-size * 0.03, size * 0.05), blade_bottom, Color(1.0, 1.0, 0.92), maxf(1.0, size * 0.035))
	canvas.draw_line(blade_bottom + blade_normal * blade_width, blade_top, edge_color, maxf(1.0, size * 0.035))
	canvas.draw_line(blade_top, blade_bottom - blade_normal * blade_width, edge_color, maxf(1.0, size * 0.035))

	var guard_center := center + Vector2(-size * 0.12, size * 0.10)
	canvas.draw_line(guard_center + Vector2(-size * 0.20, -size * 0.12), guard_center + Vector2(size * 0.16, size * 0.18), SWORD_HILT_COLOR, maxf(2.0, size * 0.12))
	canvas.draw_line(guard_center + Vector2(-size * 0.03, size * 0.03), center + Vector2(-size * 0.34, size * 0.36), SWORD_HILT_COLOR.darkened(0.08), maxf(2.0, size * 0.12))
	canvas.draw_circle(center + Vector2(-size * 0.38, size * 0.40), size * 0.075, SWORD_HILT_COLOR)


static func draw_food(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var loaf_rect := Rect2(center + Vector2(-size * 0.34, -size * 0.12), Vector2(size * 0.68, size * 0.36))
	canvas.draw_circle(center + Vector2(-size * 0.20, -size * 0.10), size * 0.20, FOOD_COLOR)
	canvas.draw_circle(center + Vector2(0.0, -size * 0.18), size * 0.24, FOOD_COLOR)
	canvas.draw_circle(center + Vector2(size * 0.22, -size * 0.10), size * 0.20, FOOD_COLOR)
	canvas.draw_rect(loaf_rect, FOOD_COLOR, true)
	canvas.draw_arc(center + Vector2(-size * 0.13, -size * 0.03), size * 0.10, -PI * 0.15, PI * 0.75, 10, FOOD_EDGE_COLOR, maxf(1.5, size * 0.06))
	canvas.draw_arc(center + Vector2(size * 0.16, -size * 0.03), size * 0.10, -PI * 0.15, PI * 0.75, 10, FOOD_EDGE_COLOR, maxf(1.5, size * 0.06))


static func draw_gold(canvas: CanvasItem, center: Vector2, size: float) -> void:
	canvas.draw_circle(center, size * 0.34, GOLD_COLOR)
	canvas.draw_arc(center, size * 0.34, 0.0, TAU, 24, GOLD_EDGE_COLOR, maxf(1.5, size * 0.08))
	canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-size * 0.11, size * 0.15), "G", HORIZONTAL_ALIGNMENT_LEFT, size * 0.24, int(size * 0.54), GOLD_EDGE_COLOR)


static func draw_bag(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var body := Rect2(center + Vector2(-size * 0.30, -size * 0.08), Vector2(size * 0.60, size * 0.46))
	var neck := Rect2(center + Vector2(-size * 0.20, -size * 0.26), Vector2(size * 0.40, size * 0.24))
	var tie_y := center.y - size * 0.07
	canvas.draw_circle(center + Vector2(-size * 0.22, size * 0.08), size * 0.16, BAG_COLOR)
	canvas.draw_circle(center + Vector2(size * 0.22, size * 0.08), size * 0.16, BAG_COLOR)
	canvas.draw_rect(body, BAG_COLOR, true)
	canvas.draw_rect(neck, BAG_COLOR.darkened(0.10), true)
	canvas.draw_line(Vector2(body.position.x, tie_y), Vector2(body.position.x + body.size.x, tie_y), BAG_EDGE_COLOR, maxf(1.5, size * 0.07))
	canvas.draw_line(center + Vector2(-size * 0.16, -size * 0.30), center + Vector2(size * 0.16, -size * 0.30), BAG_EDGE_COLOR, maxf(1.5, size * 0.08))
	canvas.draw_arc(center + Vector2(0.0, size * 0.08), size * 0.20, PI * 0.08, PI * 0.92, 12, BAG_STRAP_COLOR, maxf(1.5, size * 0.08))
	canvas.draw_arc(center + Vector2(size * 0.12, size * 0.13), size * 0.06, -PI * 0.20, PI * 0.80, 8, BAG_EDGE_COLOR, maxf(1.0, size * 0.04))
