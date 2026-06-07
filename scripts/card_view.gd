class_name CardView
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")
const CARD_DEFINITION_SCRIPT = preload("res://scripts/card_definition.gd")
const DEFAULT_CARD_BASE_TEXTURE_PATH := "res://assets/images/card_base.png"
const FALLBACK_EVENT_ART_TEXTURE_PATH := "res://assets/images/card_art_event.png"
const EVENT_ART_TEXTURES := {
	DeckController.EVENT_DESTROY_TILE: "res://assets/images/card_art_event_destroy_tile.png",
	DeckController.EVENT_DRAW_TWO: "res://assets/images/card_art_event_draw_two.png",
	DeckController.EVENT_ROTATE_TILE: "res://assets/images/card_art_event_rotate_tile.png",
	DeckController.EVENT_LUCKY_FIND: "res://assets/images/card_art_event_lucky_find.png",
}
const ROAD_ART_TEXTURES := {
	"Straight Road": "res://assets/images/card_art_road_straight.png",
	"Corner": "res://assets/images/card_art_road_corner.png",
	"T-Junction": "res://assets/images/card_art_road_t_junction.png",
	"Four-Way Intersection": "res://assets/images/card_art_road_four_way.png",
	"Dead End": "res://assets/images/card_art_road_dead_end.png",
}
const ENCOUNTER_MARKER_TEXTURES := {
	GameMap.ENCOUNTER_ENEMY: "res://assets/images/card_marker_danger.png",
	GameMap.ENCOUNTER_BERRY_BUSH: "res://assets/images/card_marker_berry.png",
	GameMap.ENCOUNTER_CACHE: "res://assets/images/card_marker_cache.png",
}

signal pointer_pressed(card: CardView, canvas_position: Vector2)
signal pointer_moved(card: CardView, canvas_position: Vector2)
signal pointer_released(card: CardView, canvas_position: Vector2)

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
@export var encounter_data := {}:
	set(value):
		encounter_data = value
		_refresh_text()
		queue_redraw()

@export var card_border_color := Color.TRANSPARENT:
	set(value):
		card_border_color = value
		queue_redraw()

@export_file("*.png") var card_base_texture_path := DEFAULT_CARD_BASE_TEXTURE_PATH:
	set(value):
		card_base_texture_path = value
		queue_redraw()

var _title_label: Label
var _category_label: Label
var _detail_label: Label
var _touch_button: Button
static var _texture_cache := {}

const TITLE_RECT := Rect2(14.0, 12.0, 122.0, 52.0)
const ART_RECT := Rect2(18.0, 72.0, 114.0, 62.0)
const NO_DETAIL_ART_RECT := Rect2(18.0, 94.0, 114.0, 62.0)
const DETAIL_RECT := Rect2(14.0, 141.0, 122.0, 38.0)
const CATEGORY_RECT := Rect2(22.0, 186.0, 106.0, 22.0)
const TITLE_FONT_MAX := 19
const TITLE_FONT_MIN := 14
const CATEGORY_FONT_SIZE := 12
const DETAIL_FONT_MAX := 13
const DETAIL_FONT_MIN := 11
const BASE_CARD_SIZE := Vector2(150.0, 216.0)


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(150.0, 216.0)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_scene_nodes()
	_layout_content()
	_refresh_text()
	_refresh_focus()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var base_art_rect := _card_art_rect()
	var art_rect := Rect2(Vector2(base_art_rect.position.x, base_art_rect.position.y), Vector2(size.x - base_art_rect.position.x * 2.0, base_art_rect.size.y))
	var border := _resolved_card_border_color()
	var card_base_texture := _load_texture(card_base_texture_path)
	if card_base_texture != null:
		draw_texture_rect(card_base_texture, rect, false)
	else:
		UIStyle.draw_panel(self, rect, _resolved_card_color(), border)
	_draw_card_art_texture(art_rect)

	if focused:
		var focus_box := UIStyle.rounded_box(self, Color.TRANSPARENT, UIStyle.focus(self), -1, 4)
		draw_style_box(focus_box, rect.grow(-2.0))


func _gui_input(event: InputEvent) -> void:
	_handle_pointer_input(event, self)


func configure(card_data: Dictionary) -> void:
	_bind_scene_nodes()
	var definition = card_data.get("card_definition")
	if definition is CARD_DEFINITION_SCRIPT:
		card_data = definition.to_card_data().merged(card_data, true)
	tile_definition = card_data.get("tile_definition")
	title = str(card_data.get("title", _title_from_definition()))
	category = str(card_data.get("category", "Road"))
	detail = str(card_data.get("detail", _detail_from_definition()))
	event_type = str(card_data.get("event_type", ""))
	var raw_encounter: Dictionary = card_data.get("encounter", card_data.get("enemy", {}))
	if not raw_encounter.is_empty() and not raw_encounter.has("type") and card_data.has("enemy"):
		raw_encounter = raw_encounter.duplicate(true)
		raw_encounter["type"] = GameMap.ENCOUNTER_ENEMY
	encounter_data = raw_encounter
	card_color = card_data.get("card_color", card_color)
	_layout_content()


func set_focused(value: bool) -> void:
	focused = value


func _bind_scene_nodes() -> void:
	if _title_label != null:
		return
	_title_label = get_node("Title") as Label
	_category_label = get_node("Category") as Label
	_detail_label = get_node("Detail") as Label
	_touch_button = get_node("TouchButton") as Button
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_color_override("font_color", UIStyle.card_text(self))
	_category_label.add_theme_color_override("font_color", UIStyle.card_muted_text(self))
	_detail_label.add_theme_color_override("font_color", UIStyle.card_text(self))
	_category_label.add_theme_font_size_override("font_size", CATEGORY_FONT_SIZE)
	if not _touch_button.gui_input.is_connected(_on_touch_button_gui_input):
		_touch_button.gui_input.connect(_on_touch_button_gui_input)


func _layout_content() -> void:
	if _title_label == null:
		return
	var scale_factor := _content_scale()
	_apply_scaled_rect(_title_label, TITLE_RECT, scale_factor)
	_apply_scaled_rect(_detail_label, DETAIL_RECT, scale_factor)
	_apply_scaled_rect(_category_label, CATEGORY_RECT, scale_factor)
	_category_label.add_theme_font_size_override("font_size", roundi(CATEGORY_FONT_SIZE * minf(scale_factor.x, scale_factor.y)))


func _apply_scaled_rect(control: Control, rect: Rect2, scale_factor: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position * scale_factor
	control.size = rect.size * scale_factor


func _content_scale() -> Vector2:
	return Vector2(size.x / BASE_CARD_SIZE.x, size.y / BASE_CARD_SIZE.y)


func _scaled_rect(rect: Rect2) -> Rect2:
	var scale_factor := _content_scale()
	return Rect2(rect.position * scale_factor, rect.size * scale_factor)


func _refresh_text() -> void:
	if _title_label != null:
		_title_label.text = _card_header_text()
		_fit_label_font_size(_title_label, _scaled_font_size(TITLE_FONT_MAX), _scaled_font_size(TITLE_FONT_MIN))
	if _category_label != null:
		_category_label.text = _category_badge_text()
	if _detail_label != null:
		_detail_label.text = _compact_detail_text()
		_fit_label_font_size(_detail_label, _scaled_font_size(DETAIL_FONT_MAX), _scaled_font_size(DETAIL_FONT_MIN))
	queue_redraw()


func _refresh_focus() -> void:
	queue_redraw()


func _on_touch_button_gui_input(event: InputEvent) -> void:
	_handle_pointer_input(event, _touch_button)


func _handle_pointer_input(event: InputEvent, source: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var canvas_position: Vector2 = source.get_global_transform_with_canvas() * event.position
		if event.pressed:
			pointer_pressed.emit(self, canvas_position)
		else:
			pointer_released.emit(self, canvas_position)
		source.accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pointer_moved.emit(self, source.get_global_transform_with_canvas() * event.position)
		source.accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			pointer_pressed.emit(self, event.position)
		else:
			pointer_released.emit(self, event.position)
		source.accept_event()
	elif event is InputEventScreenDrag:
		pointer_moved.emit(self, event.position)
		source.accept_event()


func get_card_data() -> Dictionary:
	return {
		"title": title,
		"category": category,
		"detail": detail,
		"tile_definition": tile_definition,
		"event_type": event_type,
		"encounter": encounter_data.duplicate(true),
		"card_color": card_color,
	}


func _title_from_definition() -> String:
	if tile_definition == null:
		return title
	return str(tile_definition.get("display_name"))


func _card_header_text() -> String:
	if category != DeckController.ROAD_CATEGORY or tile_definition == null:
		return title
	return _title_from_definition()


func _detail_from_definition() -> String:
	return detail


func _draw_card_art_texture(art_rect: Rect2) -> void:
	var art_texture := _card_art_texture()
	if art_texture == null:
		return
	draw_texture_rect(art_texture, art_rect, false)

	var marker_texture := _encounter_marker_texture()
	if marker_texture == null:
		return
	var marker_size := marker_texture.get_size()
	var marker_position := art_rect.get_center() - marker_size * 0.5
	if _encounter_type() != GameMap.ENCOUNTER_ENEMY:
		marker_position += Vector2(-art_rect.size.x * 0.22, art_rect.size.y * 0.12)
	draw_texture_rect(marker_texture, Rect2(marker_position, marker_size), false)


func get_card_art_rect() -> Rect2:
	if _compact_detail_text().is_empty():
		return _scaled_rect(NO_DETAIL_ART_RECT)
	return _scaled_rect(ART_RECT)


func _card_art_rect() -> Rect2:
	return get_card_art_rect()


func _card_art_texture() -> Texture2D:
	if category == DeckController.EVENT_CATEGORY:
		return _load_texture(str(EVENT_ART_TEXTURES.get(event_type, FALLBACK_EVENT_ART_TEXTURE_PATH)))
	if tile_definition == null:
		return null
	return _load_texture(str(ROAD_ART_TEXTURES.get(str(tile_definition.get("display_name")), "")))


func _encounter_marker_texture() -> Texture2D:
	if encounter_data.is_empty():
		return null
	return _load_texture(str(ENCOUNTER_MARKER_TEXTURES.get(_encounter_type(), "")))


static func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]

	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Could not load card texture: %s" % path)
		return null
	_texture_cache[path] = texture
	return texture


func _category_badge_text() -> String:
	if category == DeckController.EVENT_CATEGORY:
		return "EVENT"
	if _encounter_type() == GameMap.ENCOUNTER_ENEMY:
		return "ROAD + ENEMY"
	if _encounter_type() == GameMap.ENCOUNTER_BERRY_BUSH:
		return "ROAD + FOOD"
	if _encounter_type() == GameMap.ENCOUNTER_CACHE:
		return "ROAD + LOOT"
	if not encounter_data.is_empty():
		return "ROAD + LOOT"
	return "ROAD"


func _compact_detail_text() -> String:
	if category == DeckController.ROAD_CATEGORY:
		return ""
	if detail.is_empty():
		if _encounter_type() == GameMap.ENCOUNTER_BERRY_BUSH:
			return "Plus food"
		if _encounter_type() == GameMap.ENCOUNTER_CACHE:
			return "Plus treasure"
	if detail == "Enemy waits on this road.":
		return "Hidden fight on this road."
	if detail == "Grants food when reached.":
		return "Plus food"
	if detail == "Contains an item when reached.":
		return "Plus treasure"
	if detail == "Draw two extra cards.":
		return "Draw 2 cards."
	if detail == "Destroy a placed tile.":
		return "Destroy placed tile."
	return detail


func _category_badge_fill() -> Color:
	if category == DeckController.EVENT_CATEGORY:
		return Color(0.66, 0.78, 0.86, 1.0)
	if _encounter_type() == GameMap.ENCOUNTER_ENEMY:
		return Color(0.88, 0.60, 0.48, 1.0)
	if not encounter_data.is_empty():
		return Color(0.74, 0.82, 0.54, 1.0)
	return Color(0.86, 0.76, 0.52, 1.0)


func _fit_label_font_size(label: Label, max_size: int, min_size: int) -> void:
	var text_value := label.text.strip_edges()
	var line_count := maxi(1, text_value.count("\n") + 1)
	var longest_line := 0
	for line in text_value.split("\n"):
		longest_line = maxi(longest_line, line.length())

	var font_size := max_size
	if line_count > 1:
		font_size -= 1
	if longest_line > 15:
		font_size -= ceili(float(longest_line - 15) / 4.0)
	if line_count > 2:
		font_size -= line_count - 2

	label.add_theme_font_size_override("font_size", clampi(font_size, min_size, max_size))


func _scaled_font_size(font_size: int) -> int:
	var scale_factor := _content_scale()
	return maxi(1, roundi(font_size * minf(scale_factor.x, scale_factor.y)))


func _encounter_type() -> String:
	return str(encounter_data.get("type", ""))


func _resolved_card_color() -> Color:
	if card_color != Color.TRANSPARENT:
		return card_color
	return UIStyle.card_fill(self)


func _resolved_card_border_color() -> Color:
	if card_border_color != Color.TRANSPARENT:
		return card_border_color
	return UIStyle.panel_border(self)
