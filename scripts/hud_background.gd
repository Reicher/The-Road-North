class_name HudBackground
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")
const HUD_FRAME_TEXTURE := preload("res://assets/images/ui/frames/hud_wood_frame_strip.png")

const HUD_FILL := Color(0.12, 0.075, 0.04, 0.98)
const HUD_FRAME_SHADOW := Color(0.055, 0.032, 0.018, 0.96)
const HUD_FRAME_BRASS := Color(0.68, 0.48, 0.20, 0.95)

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
var _frame_shadow: Line2D
var _frame_wood: Line2D
var _frame_brass: Line2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory = get_parent().get_node_or_null("Inventory") as InventoryUI
	_create_frame_lines()
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
	var lower_frame := PackedVector2Array([
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
	_update_frame_lines(lower_frame)


func _create_frame_lines() -> void:
	_frame_shadow = _frame_line(15.0, HUD_FRAME_SHADOW)
	_frame_wood = _frame_line(11.0, Color.WHITE, HUD_FRAME_TEXTURE)
	_frame_brass = _frame_line(1.5, HUD_FRAME_BRASS)
	add_child(_frame_shadow)
	add_child(_frame_wood)
	add_child(_frame_brass)


func _frame_line(line_width: float, color: Color, texture: Texture2D = null) -> Line2D:
	var line := Line2D.new()
	line.width = line_width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	if texture != null:
		line.texture = texture
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
	return line


func _update_frame_lines(points: PackedVector2Array) -> void:
	if _frame_shadow == null:
		return
	_frame_shadow.points = points
	_frame_wood.points = points
	_frame_brass.points = points


func _layout_panel() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2(margin, margin)
	var panel_height := maxf(top_bar_height, top_bar_height - pocket_overlap + backpack_height)
	size = Vector2(maxf(1.0, viewport_size.x - margin * 2.0), panel_height)
	queue_redraw()
