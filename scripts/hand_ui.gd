class_name HandUI
extends Control

signal card_focused(card: CardView)
signal card_unfocused
signal card_use_requested(card: CardView)

@export var card_scene: PackedScene = preload("res://ui/card.tscn")
@export var demo_cards_enabled := true
@export var card_size := Vector2(132.0, 190.0)
@export var bottom_margin := 24.0
@export_range(0.0, 1.0, 0.01) var focused_lift_ratio := 0.28
@export var focused_scale := 1.16
@export var arc_depth := 28.0
@export var preferred_spacing := 94.0
@export var minimum_spacing := 48.0
@export var focused_side_shift := 30.0
@export var layout_duration := 0.14

var cards: Array[CardView] = []
var focused_index := -1

var _layout_tween: Tween
var _ready_completed := false


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	if demo_cards_enabled and cards.is_empty():
		set_cards(_make_demo_cards())
	else:
		_layout_cards(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _is_canvas_position_over_card(get_global_transform_with_canvas() * event.position):
			clear_focus()
	elif event is InputEventScreenTouch and event.pressed:
		if not _is_canvas_position_over_card(get_global_transform_with_canvas() * event.position):
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
	var card := card_scene.instantiate() as CardView
	card.custom_minimum_size = card_size
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	card.configure(card_data)
	card.focus_requested.connect(_on_card_focus_requested)
	card.use_requested.connect(_on_card_use_requested)
	add_child(card)
	cards.append(card)
	_layout_cards(animate)
	return card


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
	return clampf(max_spacing, minimum_spacing, preferred_spacing)


func _layout_cards(animated := true) -> void:
	if _layout_tween != null:
		_layout_tween.kill()
		_layout_tween = null

	if cards.is_empty():
		return

	var spacing := get_card_spacing()
	var count := cards.size()
	var hand_width := card_size.x + spacing * float(count - 1)
	var start_x := (_available_width() - hand_width) * 0.5
	var base_y := _available_height() - card_size.y - bottom_margin

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
	focus_card(card)


func _on_card_use_requested(card: CardView) -> void:
	if card != get_focused_card():
		return
	card_use_requested.emit(card)


func _on_resized() -> void:
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
	for card in cards:
		var local_position := card.get_global_transform_with_canvas().affine_inverse() * canvas_position
		if Rect2(Vector2.ZERO, card.size).has_point(local_position):
			return true
	return false


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
