class_name PlacementController
extends Node2D

signal placement_started(card: CardView)
signal placement_cancelled(card: CardView)
signal placement_confirmed(grid_position: Vector2i, card: CardView)

const VALID_COLOR := Color(0.20, 0.90, 0.32, 0.46)
const INVALID_COLOR := Color(0.95, 0.18, 0.14, 0.50)

@export var map_path: NodePath
@export var roads_path: NodePath
@export var player_path: NodePath
@export var hand_path: NodePath
@export var deck_controller_path: NodePath
@export var tile_scene: PackedScene = preload("res://scenes/tile.tscn")
@export_range(0.0, 1.0, 0.05) var hand_placement_offset_ratio := 0.5
@export_range(0.0, 0.5, 0.01) var hand_placement_tween_duration := 0.10

var active_card: CardView
var active_definition: Resource
var preview_position := Vector2i(-1, -1)
var rotation_steps := 0

var _map: GameMap
var _roads: Roads
var _player: GamePlayer
var _hand: HandUI
var _deck_controller: DeckController
var _preview_tile: RoadTile
var _controls_layer: CanvasLayer
var _prompt_label: Label
var _controls: HBoxContainer
var _rotate_button: Button
var _confirm_button: Button
var _cancel_button: Button
var _placement_valid := false
var _hand_rest_position := Vector2.ZERO
var _hand_shifted := false
var _hand_tween: Tween


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_roads = get_node_or_null(roads_path) as Roads
	_player = get_node_or_null(player_path) as GamePlayer
	_hand = get_node_or_null(hand_path) as HandUI
	_deck_controller = get_node_or_null(deck_controller_path) as DeckController

	if _map == null:
		push_warning("PlacementController needs a GameMap at map_path.")
		return
	if _roads == null:
		push_warning("PlacementController needs Roads at roads_path.")
		return
	if _player == null:
		push_warning("PlacementController needs a GamePlayer at player_path.")
		return
	if _hand == null:
		push_warning("PlacementController needs a HandUI at hand_path.")
		return

	_build_controls()
	_hide_preview()

	if not _hand.card_use_requested.is_connected(_on_card_use_requested):
		_hand.card_use_requested.connect(_on_card_use_requested)
	if not _map.tile_pressed.is_connected(_on_tile_pressed):
		_map.tile_pressed.connect(_on_tile_pressed)

	set_process_unhandled_input(true)
	set_process(false)


func _process(_delta: float) -> void:
	_position_controls()


func _unhandled_input(event: InputEvent) -> void:
	if active_card == null or preview_position.x < 0:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		if _map.world_to_grid(get_global_mouse_position()) == preview_position:
			rotate_preview()
	elif event is InputEventScreenTouch and event.pressed and event.double_tap:
		var world_position: Vector2 = _map.get_global_transform_with_canvas().affine_inverse() * event.position
		if _map.world_to_grid(world_position) == preview_position:
			rotate_preview()


func is_placing() -> bool:
	return active_card != null


func begin_placement(card: CardView) -> bool:
	if card == null or card.category != DeckController.ROAD_CATEGORY or card.tile_definition == null:
		return false

	active_card = card
	active_definition = card.tile_definition
	preview_position = Vector2i(-1, -1)
	rotation_steps = 0
	_placement_valid = false
	_player.input_enabled = false
	_hand.clear_focus()
	_shift_hand_for_placement()
	_hide_preview()
	_show_prompt()
	placement_started.emit(card)
	return true


func rotate_preview() -> void:
	if active_card == null:
		return
	rotation_steps = posmod(rotation_steps + 1, 4)
	_refresh_preview()


func confirm_placement() -> bool:
	if active_card == null or not _placement_valid:
		return false

	var placed := _roads.place_tile(preview_position, active_definition, rotation_steps)
	if not placed:
		_refresh_preview()
		return false

	var confirmed_card := active_card
	var confirmed_position := preview_position
	if _deck_controller != null:
		_deck_controller.consume_card(confirmed_card)
	else:
		_hand.remove_card(confirmed_card)
	_end_placement(false)
	placement_confirmed.emit(confirmed_position, confirmed_card)
	return true


func cancel_placement() -> void:
	if active_card == null:
		return
	var cancelled_card := active_card
	_end_placement(false)
	placement_cancelled.emit(cancelled_card)


func has_valid_preview() -> bool:
	return _placement_valid


func _on_card_use_requested(card: CardView) -> void:
	begin_placement(card)


func _on_tile_pressed(grid_position: Vector2i) -> void:
	if active_card == null:
		return
	preview_position = grid_position
	_refresh_preview()


func _refresh_preview() -> void:
	if active_card == null or preview_position.x < 0:
		_hide_preview()
		return

	_ensure_preview_tile()
	_preview_tile.definition = active_definition
	_preview_tile.rotation_steps = rotation_steps
	_preview_tile.tile_size = _map.tile_size
	_preview_tile.position = _map.grid_to_world(preview_position)
	_preview_tile.visible = true

	var tile_data := _roads.make_tile_data(active_definition, rotation_steps)
	_placement_valid = _is_valid_placement(preview_position, tile_data.get("connections", {}))
	_preview_tile.tile_tint = Color(1.0, 1.0, 1.0, 0.72)
	_preview_tile.set_highlight(true, VALID_COLOR if _placement_valid else INVALID_COLOR)
	_prompt_label.visible = false
	_confirm_button.disabled = not _placement_valid
	_controls.visible = true
	_position_controls()
	set_process(true)


func _is_valid_placement(grid_position: Vector2i, connections: Dictionary) -> bool:
	var delta: Vector2i = grid_position - _player.grid_position
	if abs(delta.x) + abs(delta.y) != 1:
		return false
	return _map.can_place_tile(grid_position, connections)


func _end_placement(keep_card_focused: bool) -> void:
	var ending_card := active_card
	active_card = null
	active_definition = null
	preview_position = Vector2i(-1, -1)
	rotation_steps = 0
	_placement_valid = false
	_player.input_enabled = true
	if keep_card_focused and ending_card != null:
		_hand.focus_card(ending_card)
	elif not keep_card_focused:
		_hand.clear_focus()
	_restore_hand_after_placement()
	_hide_preview()


func _ensure_preview_tile() -> void:
	if _preview_tile != null:
		return
	_preview_tile = tile_scene.instantiate() as RoadTile
	add_child(_preview_tile)


func _hide_preview() -> void:
	if _preview_tile != null:
		_preview_tile.visible = false
	if _controls != null:
		_controls.visible = false
	if _prompt_label != null:
		_prompt_label.visible = false
	if _confirm_button != null:
		_confirm_button.disabled = true
	set_process(false)


func _build_controls() -> void:
	_controls_layer = CanvasLayer.new()
	_controls_layer.name = "PlacementControls"
	_controls_layer.layer = 20
	add_child(_controls_layer)

	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.text = "Place tile"
	_prompt_label.visible = false
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0.10, 0.08, 0.05, 0.75))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_prompt_label.custom_minimum_size = Vector2(160.0, 36.0)
	_controls_layer.add_child(_prompt_label)

	_controls = HBoxContainer.new()
	_controls.name = "Buttons"
	_controls.visible = false
	_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls.add_theme_constant_override("separation", 10)
	_controls_layer.add_child(_controls)

	_rotate_button = _make_button("Rotate")
	_rotate_button.pressed.connect(rotate_preview)
	_controls.add_child(_rotate_button)

	_confirm_button = _make_button("Confirm")
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(confirm_placement)
	_controls.add_child(_confirm_button)

	_cancel_button = _make_button("Cancel")
	_cancel_button.pressed.connect(cancel_placement)
	_controls.add_child(_cancel_button)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.name = "%sButton" % text
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96.0, 44.0)
	return button


func _show_prompt() -> void:
	_prompt_label.visible = true
	_position_prompt()
	set_process(true)


func _position_prompt() -> void:
	if _prompt_label == null or not _prompt_label.visible or not is_inside_tree():
		return

	var prompt_size := _prompt_label.custom_minimum_size
	var viewport_size := get_viewport_rect().size
	var hand_offset := _hand.card_size.y * hand_placement_offset_ratio
	_prompt_label.size = prompt_size
	_prompt_label.position = Vector2((viewport_size.x - prompt_size.x) * 0.5, viewport_size.y - hand_offset - prompt_size.y - 40.0)


func _shift_hand_for_placement() -> void:
	if _hand_shifted:
		return
	_hand_rest_position = _hand.position
	_tween_hand_to(_hand_rest_position + Vector2.DOWN * _hand.card_size.y * hand_placement_offset_ratio)
	_hand_shifted = true


func _restore_hand_after_placement() -> void:
	if not _hand_shifted:
		return
	_tween_hand_to(_hand_rest_position)
	_hand_shifted = false


func _tween_hand_to(target_position: Vector2) -> void:
	if _hand_tween != null:
		_hand_tween.kill()
		_hand_tween = null

	if hand_placement_tween_duration <= 0.0:
		_hand.position = target_position
		return

	_hand_tween = create_tween()
	_hand_tween.set_trans(Tween.TRANS_SINE)
	_hand_tween.set_ease(Tween.EASE_OUT)
	_hand_tween.tween_property(_hand, "position", target_position, hand_placement_tween_duration)


func _position_controls() -> void:
	_position_prompt()
	if _controls == null or not _controls.visible or _map == null or preview_position.x < 0:
		return
	if not is_inside_tree():
		return

	var controls_size := _controls.size
	var minimum_size := _controls.get_combined_minimum_size()
	if controls_size.x < minimum_size.x or controls_size.y < minimum_size.y:
		_controls.size = minimum_size
		controls_size = minimum_size

	var preview_world := _map.grid_to_world(preview_position)
	var canvas_position: Vector2 = _map.get_global_transform_with_canvas() * preview_world
	var preferred_position := canvas_position + Vector2(-controls_size.x * 0.5, _map.tile_size * 0.56)
	var viewport_size := get_viewport_rect().size
	preferred_position.x = clampf(preferred_position.x, 8.0, maxf(8.0, viewport_size.x - controls_size.x - 8.0))
	preferred_position.y = clampf(preferred_position.y, 8.0, maxf(8.0, viewport_size.y - controls_size.y - 8.0))
	_controls.position = preferred_position
