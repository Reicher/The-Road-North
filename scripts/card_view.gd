class_name CardView
extends Control

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

@export var card_color := Color(0.93, 0.86, 0.68):
	set(value):
		card_color = value
		queue_redraw()

@export var event_type := ""

@export var card_border_color := Color(0.24, 0.19, 0.15):
	set(value):
		card_border_color = value
		queue_redraw()

var _title_label: Label
var _category_label: Label
var _detail_label: Label
var _use_button: Button
var _children_built := false


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
	draw_rect(rect, card_border_color, true)
	draw_rect(inner_rect, card_color, true)
	draw_rect(inner_rect, card_border_color, false, 2.0)

	var art_rect := Rect2(Vector2(18.0, 54.0), Vector2(size.x - 36.0, 58.0))
	draw_rect(art_rect, Color(0.48, 0.61, 0.46), true)
	draw_rect(art_rect, card_border_color.darkened(0.12), false, 2.0)
	_draw_card_symbol(art_rect)

	if focused:
		draw_rect(rect.grow(-2.0), Color(1.0, 0.96, 0.64), false, 4.0)


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
	card_color = card_data.get("card_color", card_color)


func set_focused(value: bool) -> void:
	focused = value


func _ensure_children() -> void:
	if _children_built:
		return
	_children_built = true

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.16, 0.12, 0.09))
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_left = 14.0
	_title_label.offset_top = 12.0
	_title_label.offset_right = -14.0
	_title_label.offset_bottom = 44.0
	add_child(_title_label)

	_category_label = Label.new()
	_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_category_label.add_theme_font_size_override("font_size", 12)
	_category_label.add_theme_color_override("font_color", Color(0.34, 0.25, 0.18))
	_category_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_category_label.offset_left = 16.0
	_category_label.offset_top = 116.0
	_category_label.offset_right = -16.0
	_category_label.offset_bottom = 136.0
	add_child(_category_label)

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 11)
	_detail_label.add_theme_color_override("font_color", Color(0.22, 0.17, 0.13))
	_detail_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_detail_label.offset_left = 14.0
	_detail_label.offset_top = 136.0
	_detail_label.offset_right = -14.0
	_detail_label.offset_bottom = 164.0
	add_child(_detail_label)

	_use_button = Button.new()
	_use_button.name = "UseButton"
	_use_button.text = "Use"
	_use_button.focus_mode = Control.FOCUS_NONE
	_use_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_use_button.offset_left = 22.0
	_use_button.offset_top = -42.0
	_use_button.offset_right = -22.0
	_use_button.offset_bottom = -12.0
	_use_button.pressed.connect(_on_use_button_pressed)
	add_child(_use_button)


func _refresh_text() -> void:
	if _title_label != null:
		_title_label.text = title
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
		draw_circle(art_rect.get_center(), minf(art_rect.size.x, art_rect.size.y) * 0.25, Color(0.31, 0.36, 0.27))
		return

	var openings: Dictionary = tile_definition.get_base_openings()
	var center := art_rect.get_center()
	var road_width := 12.0
	var road_color := Color(0.35, 0.29, 0.22)

	if openings.get("north", false) == true:
		draw_rect(Rect2(Vector2(center.x - road_width * 0.5, art_rect.position.y), Vector2(road_width, art_rect.size.y * 0.5)), road_color, true)
	if openings.get("east", false) == true:
		draw_rect(Rect2(Vector2(center.x, center.y - road_width * 0.5), Vector2(art_rect.size.x * 0.5, road_width)), road_color, true)
	if openings.get("south", false) == true:
		draw_rect(Rect2(Vector2(center.x - road_width * 0.5, center.y), Vector2(road_width, art_rect.size.y * 0.5)), road_color, true)
	if openings.get("west", false) == true:
		draw_rect(Rect2(Vector2(art_rect.position.x, center.y - road_width * 0.5), Vector2(art_rect.size.x * 0.5, road_width)), road_color, true)
	draw_circle(center, road_width * 0.62, road_color)
