class_name CardView
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

signal focus_requested(card: CardView)
signal use_requested(card: CardView)

@export var title := "Card":
	set(value):
		title = value
		_refresh_text()
		queue_redraw()

@export var category := "Road":
	set(value):
		category = value
		_refresh_text()
		queue_redraw()

@export var detail := "":
	set(value):
		detail = value
		_refresh_text()

@export var tile_definition: Resource:
	set(value):
		tile_definition = value
		if tile_definition != null and title == "Card":
			title = str(tile_definition.get("display_name"))
		queue_redraw()

@export var focused := false:
	set(value):
		focused = value
		_refresh_focus()

@export var card_color := Color.TRANSPARENT:
	set(value):
		card_color = value
		queue_redraw()

@export var event_type := ""
@export var enemy_data := {}:
	set(value):
		enemy_data = value
		_refresh_text()
		queue_redraw()

@export var landmark_data := {}:
	set(value):
		landmark_data = value
		_refresh_text()
		queue_redraw()

@export var card_border_color := Color.TRANSPARENT:
	set(value):
		card_border_color = value
		queue_redraw()

var _title_label: Label
var _category_label: Label
var _detail_label: Label
var _use_button: Button
var _children_built := false

const TITLE_RECT := Rect2(14.0, 10.0, 104.0, 44.0)
const ART_RECT := Rect2(18.0, 62.0, 96.0, 48.0)
const CATEGORY_RECT := Rect2(16.0, 116.0, 100.0, 18.0)
const DETAIL_RECT := Rect2(14.0, 132.0, 104.0, 18.0)
const USE_BUTTON_BOTTOM_MARGIN := 8.0
const USE_BUTTON_HEIGHT := 28.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(132.0, 190.0)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_children()
	_refresh_text()
	_refresh_focus()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var inner_rect := rect.grow(-8.0)
	var border := _resolved_card_border_color()
	UIStyle.draw_panel(self, rect, border, border)
	UIStyle.draw_panel(self, inner_rect, _resolved_card_color(), border)

	var art_rect := Rect2(Vector2(ART_RECT.position.x, ART_RECT.position.y), Vector2(size.x - ART_RECT.position.x * 2.0, ART_RECT.size.y))
	UIStyle.draw_panel(self, art_rect, UIStyle.card_art_fill(self), border.darkened(0.12))
	_draw_card_symbol(art_rect)

	if focused:
		var focus_box := UIStyle.rounded_box(self, Color.TRANSPARENT, UIStyle.focus(self), -1, 4)
		draw_style_box(focus_box, rect.grow(-2.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		focus_requested.emit(self)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		focus_requested.emit(self)
		accept_event()


func configure(card_data: Dictionary) -> void:
	_ensure_children()
	tile_definition = card_data.get("tile_definition")
	title = str(card_data.get("title", _title_from_definition()))
	category = str(card_data.get("category", "Road"))
	detail = str(card_data.get("detail", _detail_from_definition()))
	event_type = str(card_data.get("event_type", ""))
	enemy_data = card_data.get("enemy", {})
	landmark_data = card_data.get("landmark", {})
	card_color = card_data.get("card_color", card_color)


func set_focused(value: bool) -> void:
	focused = value


func _ensure_children() -> void:
	if _children_built:
		return
	_children_built = true

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.clip_text = true
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_constant_override("line_spacing", -3)
	_title_label.add_theme_color_override("font_color", UIStyle.text(self))
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_left = TITLE_RECT.position.x
	_title_label.offset_top = TITLE_RECT.position.y
	_title_label.offset_right = -TITLE_RECT.position.x
	_title_label.offset_bottom = TITLE_RECT.position.y + TITLE_RECT.size.y
	add_child(_title_label)

	_category_label = Label.new()
	_category_label.name = "Category"
	_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_category_label.add_theme_font_size_override("font_size", 12)
	_category_label.add_theme_color_override("font_color", UIStyle.muted_text(self))
	_category_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_category_label.offset_left = CATEGORY_RECT.position.x
	_category_label.offset_top = CATEGORY_RECT.position.y
	_category_label.offset_right = -CATEGORY_RECT.position.x
	_category_label.offset_bottom = CATEGORY_RECT.position.y + CATEGORY_RECT.size.y
	add_child(_category_label)

	_detail_label = Label.new()
	_detail_label.name = "Detail"
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.clip_text = true
	_detail_label.add_theme_font_size_override("font_size", 11)
	_detail_label.add_theme_color_override("font_color", UIStyle.text(self))
	_detail_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_detail_label.offset_left = DETAIL_RECT.position.x
	_detail_label.offset_top = DETAIL_RECT.position.y
	_detail_label.offset_right = -DETAIL_RECT.position.x
	_detail_label.offset_bottom = DETAIL_RECT.position.y + DETAIL_RECT.size.y
	add_child(_detail_label)

	_use_button = Button.new()
	_use_button.name = "UseButton"
	_use_button.text = "Use"
	_use_button.focus_mode = Control.FOCUS_NONE
	_use_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_use_button.offset_left = 22.0
	_use_button.offset_top = -(USE_BUTTON_HEIGHT + USE_BUTTON_BOTTOM_MARGIN)
	_use_button.offset_right = -22.0
	_use_button.offset_bottom = -USE_BUTTON_BOTTOM_MARGIN
	_use_button.pressed.connect(_on_use_button_pressed)
	add_child(_use_button)


func _refresh_text() -> void:
	if _title_label != null:
		_title_label.text = _card_header_text()
	if _category_label != null:
		_category_label.text = category
	if _detail_label != null:
		_detail_label.text = detail


func _refresh_focus() -> void:
	if _use_button != null:
		_use_button.visible = focused
	queue_redraw()


func _on_use_button_pressed() -> void:
	use_requested.emit(self)


func _title_from_definition() -> String:
	if tile_definition == null:
		return title
	return str(tile_definition.get("display_name"))


func _card_header_text() -> String:
	if category != DeckController.ROAD_CATEGORY or tile_definition == null:
		return title

	var road_type := _title_from_definition()
	var modifier := _road_modifier_title()
	if modifier.is_empty():
		return road_type
	return "%s\n%s" % [modifier, _compact_road_type_title(road_type)]


func _road_modifier_title() -> String:
	if not enemy_data.is_empty():
		return "Enemy"
	if landmark_data.is_empty():
		return ""

	var kind := str(landmark_data.get("type", ""))
	if kind == GameMap.LANDMARK_BERRY_BUSH:
		return "Berry"
	if kind == GameMap.LANDMARK_RUINS:
		return "Ruins"
	if kind == GameMap.LANDMARK_CACHE:
		return "Treasure"
	return "Reward"


func _compact_road_type_title(road_type: String) -> String:
	if road_type.ends_with(" Road"):
		return road_type.trim_suffix(" Road")
	if road_type.ends_with(" Intersection"):
		return road_type.trim_suffix(" Intersection")
	return road_type


func _detail_from_definition() -> String:
	if tile_definition == null or not tile_definition.has_method("get_base_openings"):
		return detail

	var openings: Dictionary = tile_definition.get_base_openings()
	var names: Array[String] = []
	for direction_name in TileDefinition.DIRECTION_NAMES:
		if openings.get(direction_name, false) == true:
			names.append(direction_name.capitalize())
	return "Open: %s" % ", ".join(names)


func _draw_card_symbol(art_rect: Rect2) -> void:
	if tile_definition == null or not tile_definition.has_method("get_base_openings"):
		draw_circle(art_rect.get_center(), minf(art_rect.size.x, art_rect.size.y) * 0.25, UIStyle.road_ink(self))
		return

	var openings: Dictionary = tile_definition.get_base_openings()
	var center := art_rect.get_center()
	var road_width := 12.0
	var road_color := UIStyle.road_ink(self)

	if openings.get("north", false) == true:
		draw_rect(Rect2(Vector2(center.x - road_width * 0.5, art_rect.position.y), Vector2(road_width, art_rect.size.y * 0.5)), road_color, true)
	if openings.get("east", false) == true:
		draw_rect(Rect2(Vector2(center.x, center.y - road_width * 0.5), Vector2(art_rect.size.x * 0.5, road_width)), road_color, true)
	if openings.get("south", false) == true:
		draw_rect(Rect2(Vector2(center.x - road_width * 0.5, center.y), Vector2(road_width, art_rect.size.y * 0.5)), road_color, true)
	if openings.get("west", false) == true:
		draw_rect(Rect2(Vector2(art_rect.position.x, center.y - road_width * 0.5), Vector2(art_rect.size.x * 0.5, road_width)), road_color, true)
	draw_circle(center, road_width * 0.62, road_color)
	if not landmark_data.is_empty():
		_draw_landmark_marker(art_rect)
	if not enemy_data.is_empty():
		_draw_hidden_enemy_marker(art_rect)


func _draw_hidden_enemy_marker(art_rect: Rect2) -> void:
	var radius := minf(art_rect.size.x, art_rect.size.y) * 0.24
	var center := art_rect.get_center()
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, Color(0.54, 0.12, 0.16, 0.90))
	draw_arc(center, radius, 0.0, TAU, 24, Color(0.22, 0.06, 0.07, 0.95), 2.0)
	draw_circle(center, radius * 0.30, Color(1.0, 0.86, 0.36, 0.98))


func _draw_landmark_marker(art_rect: Rect2) -> void:
	var kind := str(landmark_data.get("type", ""))
	var center := art_rect.get_center() + Vector2(-art_rect.size.x * 0.22, art_rect.size.y * 0.12)
	var radius := minf(art_rect.size.x, art_rect.size.y) * 0.16
	if kind == GameMap.LANDMARK_BERRY_BUSH:
		draw_circle(center, radius, Color(0.18, 0.44, 0.22))
		draw_circle(center + Vector2(radius * 0.35, -radius * 0.2), radius * 0.22, Color(0.67, 0.10, 0.18))
	elif kind == GameMap.LANDMARK_RUINS:
		draw_rect(Rect2(center - Vector2(radius * 0.8, radius * 0.5), Vector2(radius * 0.45, radius)), Color(0.48, 0.49, 0.45), true)
		draw_rect(Rect2(center + Vector2(radius * 0.2, -radius * 0.3), Vector2(radius * 0.45, radius * 0.8)), Color(0.56, 0.56, 0.51), true)
	elif kind == GameMap.LANDMARK_CACHE:
		var box_rect := Rect2(center - Vector2(radius, radius * 0.55), Vector2(radius * 2.0, radius * 1.15))
		draw_rect(box_rect, Color(0.48, 0.27, 0.12), true)
		draw_rect(box_rect, Color(0.88, 0.67, 0.28), false, 1.5)


func _resolved_card_color() -> Color:
	if card_color != Color.TRANSPARENT:
		return card_color
	return UIStyle.card_fill(self)


func _resolved_card_border_color() -> Color:
	if card_border_color != Color.TRANSPARENT:
		return card_border_color
	return UIStyle.panel_border(self)
