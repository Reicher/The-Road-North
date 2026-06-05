class_name HandUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

signal card_focused(card: CardView)
signal card_unfocused
signal card_use_requested(card: CardView)

@export var card_scene: PackedScene = preload("res://ui/card.tscn")
@export var demo_cards_enabled := true
@export var card_size := Vector2(174.0, 250.0)
@export var bottom_margin := 20.0
@export var show_panel_background := false
@export var panel_color := Color.TRANSPARENT
@export_range(0.0, 1.0, 0.01) var focused_lift_ratio := 0.28
@export var focused_scale := 1.12
@export var arc_depth := 34.0
@export var preferred_spacing := 180.0
@export var minimum_spacing := 48.0
@export var focused_side_shift := 38.0
@export var layout_duration := 0.14
@export var use_button_size := Vector2(116.0, 48.0)
@export var use_button_gap := 8.0
@export var use_button_bottom_margin := 8.0

var cards: Array[CardView] = []
var focused_index := -1

var _layout_tween: Tween
var _ready_completed := false
var _card_parent: Control
var _use_button: Button


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resolve_card_parent()
	_resolve_use_button()
	resized.connect(_on_resized)
	if demo_cards_enabled and cards.is_empty():
		set_cards(_make_demo_cards())
	else:
		_layout_cards(false)


func _draw() -> void:
	if not show_panel_background:
		return
	var fill := panel_color if panel_color != Color.TRANSPARENT else UIStyle.panel_fill(self)
	UIStyle.draw_panel(self, Rect2(Vector2.ZERO, size).grow_individual(12.0, 0.0, 12.0, 12.0), fill, UIStyle.panel_border(self))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _is_canvas_position_over_card(get_global_transform_with_canvas() * event.position):
			clear_focus()
	elif event is InputEventScreenTouch and event.pressed:
		var touched_card := _card_at_canvas_position(event.position)
		if touched_card != null:
			_on_card_focus_requested(touched_card)
			accept_event()
		else:
			clear_focus()


func set_cards(card_data_list: Array) -> void:
	for card in cards:
		card.queue_free()
	cards.clear()
	focused_index = -1

	for card_data in card_data_list:
		add_card(card_data, false)

	_layout_cards(false)


func add_card(card_data: Dictionary, animate := true) -> CardView:
	_resolve_card_parent()
	_resolve_use_button()
	if _card_parent == null:
		return null
	var card := card_scene.instantiate() as CardView
	card.custom_minimum_size = card_size
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	card.configure(card_data)
	card.focus_requested.connect(_on_card_focus_requested)
	card.use_requested.connect(_on_card_use_requested)
	_card_parent.add_child(card)
	cards.append(card)
	_layout_cards(animate)
	return card


func remove_card(card: CardView, animate := true) -> bool:
	var index := cards.find(card)
	if index == -1:
		return false

	var removed_focused_card := focused_index == index
	cards.remove_at(index)
	if removed_focused_card:
		focused_index = -1
	elif focused_index > index:
		focused_index -= 1
	card.queue_free()
	if removed_focused_card:
		card_unfocused.emit()
	_layout_cards(animate)
	return true


func clear_focus() -> void:
	if focused_index == -1:
		return

	focused_index = -1
	for card in cards:
		card.set_focused(false)
	card_unfocused.emit()
	_layout_cards()


func focus_card(card: CardView) -> void:
	var index := cards.find(card)
	if index == -1:
		return

	focused_index = index
	for card_index in cards.size():
		cards[card_index].set_focused(card_index == focused_index)
	card_focused.emit(card)
	_layout_cards()


func get_focused_card() -> CardView:
	if focused_index < 0 or focused_index >= cards.size():
		return null
	return cards[focused_index]


func get_card_spacing() -> float:
	var count := cards.size()
	if count <= 1:
		return 0.0

	var available_width := _available_width()
	var max_spacing := (available_width - card_size.x) / float(count - 1)
	return minf(preferred_spacing, maxf(0.0, max_spacing))


func _layout_cards(animated := true) -> void:
	if _layout_tween != null:
		_layout_tween.kill()
		_layout_tween = null

	if cards.is_empty():
		_layout_use_button(false)
		return

	var spacing := get_card_spacing()
	var count := cards.size()
	var hand_width := card_size.x + spacing * float(count - 1)
	var start_x := (_available_width() - hand_width) * 0.5
	var base_y := _available_height() - card_size.y - bottom_margin
	var focused_card_position := Vector2.ZERO
	var focused_card_scale := Vector2.ONE

	if animated and layout_duration > 0.0:
		_layout_tween = create_tween()
		_layout_tween.set_parallel(true)

	for index in count:
		var card := cards[index]
		var center_offset := float(index) - float(count - 1) * 0.5
		var target_position := Vector2(start_x + spacing * index, base_y + absf(center_offset) * arc_depth / maxf(1.0, float(count - 1)))
		var target_rotation := deg_to_rad(center_offset * 4.0)
		var target_scale := Vector2.ONE
		var target_z := index

		if index == focused_index:
			target_position += Vector2.UP.rotated(target_rotation) * card_size.y * focused_lift_ratio
			target_scale = Vector2.ONE * focused_scale
			target_z = 100
			focused_card_position = target_position
			focused_card_scale = target_scale
		elif focused_index != -1:
			var direction := signf(float(index - focused_index))
			var distance_from_focus := absf(float(index - focused_index))
			target_position.x += direction * focused_side_shift / distance_from_focus

		card.z_index = target_z
		if animated and layout_duration > 0.0:
			_layout_tween.tween_property(card, "position", target_position, layout_duration)
			_layout_tween.tween_property(card, "rotation", target_rotation, layout_duration)
			_layout_tween.tween_property(card, "scale", target_scale, layout_duration)
		else:
			card.position = target_position
			card.rotation = target_rotation
			card.scale = target_scale

	_layout_use_button(animated, focused_card_position, focused_card_scale)


func _on_card_focus_requested(card: CardView) -> void:
	if card == get_focused_card():
		clear_focus()
		return
	focus_card(card)


func _on_card_use_requested(card: CardView) -> void:
	if card != get_focused_card():
		return
	card_use_requested.emit(card)


func _on_use_button_pressed() -> void:
	var card := get_focused_card()
	if card == null:
		return
	card_use_requested.emit(card)


func _on_resized() -> void:
	queue_redraw()
	_layout_cards(false)


func _available_width() -> float:
	if size.x > 0.0:
		return size.x
	return get_viewport_rect().size.x


func _available_height() -> float:
	if size.y > 0.0:
		return size.y
	return get_viewport_rect().size.y


func _is_canvas_position_over_card(canvas_position: Vector2) -> bool:
	return _card_at_canvas_position(canvas_position) != null


func _card_at_canvas_position(canvas_position: Vector2) -> CardView:
	var touched_card: CardView
	var highest_z := -2147483648
	for card in cards:
		var local_position := card.get_global_transform_with_canvas().affine_inverse() * canvas_position
		if Rect2(Vector2.ZERO, card.size).has_point(local_position) and card.z_index >= highest_z:
			touched_card = card
			highest_z = card.z_index
	return touched_card


func _resolve_card_parent() -> void:
	if _card_parent != null:
		return

	_card_parent = get_node_or_null("CardContainer") as Control
	if _card_parent == null:
		push_warning("HandUI needs a CardContainer child.")


func _resolve_use_button() -> void:
	if _use_button != null:
		return

	_use_button = get_node_or_null("UseButton") as Button
	if _use_button == null:
		push_warning("HandUI needs a UseButton child.")
		return

	_use_button.text = "Use"
	_use_button.focus_mode = Control.FOCUS_NONE
	_use_button.custom_minimum_size = use_button_size
	_use_button.size = use_button_size
	_use_button.visible = false
	_use_button.z_index = 200
	if not _use_button.pressed.is_connected(_on_use_button_pressed):
		_use_button.pressed.connect(_on_use_button_pressed)


func _layout_use_button(animated := true, focused_card_position := Vector2.ZERO, focused_card_scale := Vector2.ONE) -> void:
	_resolve_use_button()
	if _use_button == null:
		return
	if focused_index == -1:
		_use_button.visible = false
		return

	_use_button.visible = true
	_use_button.size = use_button_size
	var scaled_card_size := card_size * focused_card_scale
	var card_center_x := focused_card_position.x + card_size.x * 0.5
	var card_bottom_y := focused_card_position.y + card_size.y * 0.5 + scaled_card_size.y * 0.5
	var target_position := Vector2(
		card_center_x - use_button_size.x * 0.5,
		card_bottom_y + use_button_gap
	)
	target_position.x = clampf(target_position.x, 0.0, maxf(0.0, _available_width() - use_button_size.x))
	target_position.y = clampf(target_position.y, 0.0, maxf(0.0, _available_height() - use_button_bottom_margin - use_button_size.y))

	if animated and layout_duration > 0.0 and _layout_tween != null:
		_layout_tween.tween_property(_use_button, "position", target_position, layout_duration)
	else:
		_use_button.position = target_position


func _make_demo_cards() -> Array[Dictionary]:
	var definitions: Array[Resource] = [
		preload("res://data/road_straight.tres"),
		preload("res://data/road_corner.tres"),
		preload("res://data/road_t_junction.tres"),
		preload("res://data/road_four_way.tres"),
		preload("res://data/road_dead_end.tres"),
	]
	var hand: Array[Dictionary] = []
	for definition in definitions:
		hand.append({
			"category": "Road",
			"tile_definition": definition,
		})
	return hand
