class_name HandUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

signal card_focused(card: CardView)
signal card_unfocused
signal card_drag_started(card: CardView, canvas_position: Vector2)
signal card_drag_moved(card: CardView, canvas_position: Vector2, activated: bool)
signal card_drag_finished(card: CardView, canvas_position: Vector2, activated: bool, released_over_hand: bool)

@export var card_scene: PackedScene = preload("res://ui/card.tscn")
@export var demo_cards_enabled := true
@export var card_size := Vector2(174.0, 250.0)
@export var side_margin := 16.0
@export var bottom_margin := 20.0
@export var show_panel_background := false
@export var panel_color := Color.TRANSPARENT
@export_range(0.0, 1.0, 0.01) var focused_lift_ratio := 0.28
@export var focused_scale := 1.18
@export var arc_depth := 34.0
@export var preferred_spacing := 180.0
@export var focused_side_shift := 38.0
@export var layout_duration := 0.14
@export var inactive_visible_ratio := 0.5
@export var drag_threshold := 12.0
@export var activation_margin := 20.0

var cards: Array[CardView] = []
var focused_index := -1
var interaction_enabled := true
var inactive := false

var _layout_tween: Tween
var _ready_completed := false
var _card_parent: Control
var _pressed_card: CardView
var _press_position := Vector2.ZERO
var _dragged_card: CardView
var _drag_ghost: CardView
var _drag_activated := false


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resolve_card_parent()
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
		if _card_at_canvas_position(get_global_transform_with_canvas() * event.position) == null:
			clear_focus()
	elif event is InputEventScreenTouch and event.pressed:
		var touched_card := _card_at_canvas_position(event.position)
		if touched_card != null:
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
	if _card_parent == null:
		return null
	var card := card_scene.instantiate() as CardView
	card.custom_minimum_size = card_size
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	card.configure(card_data)
	card.pointer_pressed.connect(_on_card_pointer_pressed)
	card.pointer_moved.connect(_on_card_pointer_moved)
	card.pointer_released.connect(_on_card_pointer_released)
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

	var available_width := maxf(0.0, _available_width() - side_margin * 2.0)
	var max_spacing := (available_width - card_size.x) / float(count - 1)
	return minf(preferred_spacing, maxf(0.0, max_spacing))


func _layout_cards(animated := true) -> void:
	if _layout_tween != null:
		_layout_tween.kill()
		_layout_tween = null

	if cards.is_empty():
		return

	var spacing := get_card_spacing()
	var count := cards.size()
	var hand_width := card_size.x + spacing * float(count - 1)
	var start_x := side_margin + (maxf(0.0, _available_width() - side_margin * 2.0) - hand_width) * 0.5
	var base_y := _available_height() - card_size.y - bottom_margin
	if inactive:
		base_y += card_size.y * inactive_visible_ratio + bottom_margin
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
		elif focused_index != -1:
			var direction := signf(float(index - focused_index))
			var distance_from_focus := absf(float(index - focused_index))
			target_position.x += direction * focused_side_shift / distance_from_focus

		target_position.x = _clamp_card_x(target_position.x, target_scale.x)
		card.z_index = target_z
		if animated and layout_duration > 0.0:
			_layout_tween.tween_property(card, "position", target_position, layout_duration)
			_layout_tween.tween_property(card, "rotation", target_rotation, layout_duration)
			_layout_tween.tween_property(card, "scale", target_scale, layout_duration)
		else:
			card.position = target_position
			card.rotation = target_rotation
			card.scale = target_scale

func _on_card_focus_requested(card: CardView) -> void:
	if card == get_focused_card():
		clear_focus()
		return
	focus_card(card)


func _on_card_pointer_pressed(card: CardView, canvas_position: Vector2) -> void:
	if not interaction_enabled or _dragged_card != null:
		return
	_pressed_card = card
	_press_position = canvas_position


func _on_card_pointer_moved(card: CardView, canvas_position: Vector2) -> void:
	if card != _pressed_card:
		return
	if _dragged_card == null:
		if _press_position.distance_to(canvas_position) < drag_threshold:
			return
		_start_card_drag(card, canvas_position)
	_update_card_drag(canvas_position)


func _on_card_pointer_released(card: CardView, canvas_position: Vector2) -> void:
	if card != _pressed_card:
		return
	if _dragged_card == null:
		_pressed_card = null
		_on_card_focus_requested(card)
		return
	_finish_card_drag(canvas_position)


func _start_card_drag(card: CardView, canvas_position: Vector2) -> void:
	_dragged_card = card
	_drag_activated = false
	add_to_group("ui_item_drag_active")
	clear_focus()
	_show_drag_ghost(card, canvas_position)
	card.modulate.a = 0.35
	card_drag_started.emit(card, canvas_position)


func _update_card_drag(canvas_position: Vector2) -> void:
	if _dragged_card == null:
		return
	_drag_activated = canvas_position.y < get_activation_boundary_y()
	set_inactive(_drag_activated)
	_update_drag_ghost(canvas_position)
	if _drag_ghost != null:
		_drag_ghost.visible = not _drag_activated or not _dragged_card_uses_preview()
	card_drag_moved.emit(_dragged_card, canvas_position, _drag_activated)


func _finish_card_drag(canvas_position: Vector2) -> void:
	var card := _dragged_card
	var activated := _drag_activated
	var released_over_hand := is_canvas_position_over_hand(canvas_position)
	if not activated or released_over_hand:
		set_inactive(false)
	_cancel_drag_visual()
	card_drag_finished.emit(card, canvas_position, activated, released_over_hand)


func _cancel_drag_visual() -> void:
	if _dragged_card != null:
		_dragged_card.modulate = Color.WHITE
	_pressed_card = null
	_dragged_card = null
	_drag_activated = false
	remove_from_group("ui_item_drag_active")
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null


func _show_drag_ghost(card: CardView, canvas_position: Vector2) -> void:
	_drag_ghost = card_scene.instantiate() as CardView
	_drag_ghost.custom_minimum_size = card_size
	_drag_ghost.size = card_size
	_drag_ghost.pivot_offset = card_size * 0.5
	_drag_ghost.configure(card.get_card_data())
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.modulate.a = 0.88
	_drag_ghost.z_index = 1000
	add_child(_drag_ghost)
	_update_drag_ghost(canvas_position)


func _update_drag_ghost(canvas_position: Vector2) -> void:
	if _drag_ghost == null:
		return
	var local_position := get_global_transform_with_canvas().affine_inverse() * canvas_position
	_drag_ghost.position = local_position - _drag_ghost.size * 0.5


func get_activation_boundary_y() -> float:
	return get_global_rect().position.y - activation_margin


func get_card_top_screen_y() -> float:
	if cards.is_empty():
		return get_global_rect().position.y

	var card_top := INF
	for card in cards:
		var canvas_transform := card.get_global_transform_with_canvas()
		for corner in [
			Vector2.ZERO,
			Vector2(card.size.x, 0.0),
			Vector2(0.0, card.size.y),
			card.size,
		]:
			card_top = minf(card_top, (canvas_transform * corner).y)
	return card_top


func is_canvas_position_over_hand(canvas_position: Vector2) -> bool:
	return get_global_rect().has_point(canvas_position)


func is_drag_active() -> bool:
	return _dragged_card != null


func set_inactive(value: bool, animated := true) -> void:
	if inactive == value:
		return
	inactive = value
	_layout_cards(animated)


func _dragged_card_uses_preview() -> bool:
	if _dragged_card == null:
		return false
	if _dragged_card.category == DeckController.ROAD_CATEGORY:
		return true
	return _dragged_card.event_type in DeckController.TARGETED_EVENT_TYPES


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


func _clamp_card_x(card_x: float, card_scale: float) -> float:
	var scale_overhang := card_size.x * maxf(0.0, card_scale - 1.0) * 0.5
	var minimum_x := side_margin + scale_overhang
	var maximum_x := _available_width() - side_margin - card_size.x - scale_overhang
	return clampf(card_x, minimum_x, maxf(minimum_x, maximum_x))


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
