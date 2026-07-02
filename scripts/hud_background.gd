class_name HudBackground
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

const HUD_FILL := Color(0.16, 0.34, 0.29, 0.98)
const HUD_BORDER := Color(0.58, 0.43, 0.23, 0.9)

@export var margin := 0.0
@export var top_bar_height := 68.0
@export var pocket_overlap := 8.0
@export var backpack_width := 154.0
@export var backpack_height := 170.0
@export var settings_width := 68.0
@export var settings_height := 68.0
@export var inner_corner_radius := 16.0

var _inventory: InventoryUI
var _animated_backpack_right := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory = get_parent().get_node_or_null("Inventory") as InventoryUI
	set_process(_inventory != null)
	resized.connect(_layout_panel)
	_layout_panel()


func _process(_delta: float) -> void:
	if _inventory == null:
		return
	var target_right := _inventory.get_hud_extension_right()
	if is_equal_approx(target_right, _animated_backpack_right):
		return
	_animated_backpack_right = target_right
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panel()


func _draw() -> void:
	var pocket_top := top_bar_height - pocket_overlap
	var bevel := minf(inner_corner_radius, 12.0)
	var backpack_right := minf(maxf(backpack_width, _animated_backpack_right), size.x)
	var backpack_bottom := pocket_top + backpack_height
	var settings_left := maxf(0.0, size.x - settings_width)
	var settings_bottom := pocket_top + settings_height
	var outline := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(size.x, 0.0),
		Vector2(size.x, settings_bottom - bevel),
		Vector2(size.x - bevel, settings_bottom),
		Vector2(settings_left + bevel, settings_bottom),
		Vector2(settings_left, settings_bottom - bevel),
		Vector2(settings_left, top_bar_height + bevel),
		Vector2(settings_left - bevel, top_bar_height),
		Vector2(backpack_right + bevel, top_bar_height),
		Vector2(backpack_right, top_bar_height + bevel),
		Vector2(backpack_right, backpack_bottom - bevel),
		Vector2(backpack_right - bevel, backpack_bottom),
		Vector2(0.0, backpack_bottom),
	])
	draw_colored_polygon(outline, HUD_FILL)
	var closed_outline := outline.duplicate()
	closed_outline.append(outline[0])
	draw_polyline(closed_outline, HUD_BORDER, 3.0, true)


func _layout_panel() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2(margin, margin)
	var panel_height := maxf(top_bar_height, top_bar_height - pocket_overlap + backpack_height)
	size = Vector2(maxf(1.0, viewport_size.x - margin * 2.0), panel_height)
	queue_redraw()
