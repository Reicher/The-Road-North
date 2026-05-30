class_name PlacementController
extends Node2D

signal placement_started(card: CardView)
signal placement_cancelled(card: CardView)
signal placement_confirmed(grid_position: Vector2i, card: CardView)
signal tile_destroyed(grid_position: Vector2i, card: CardView)

const VALID_COLOR := Color(0.20, 0.90, 0.32, 0.46)
const INVALID_COLOR := Color(0.95, 0.18, 0.14, 0.50)
const TARGET_COLOR := Color(0.98, 0.83, 0.24, 0.62)
const PLACEMENT_HINT_COLOR := Color(0.24, 0.88, 0.38, 0.58)
const MODE_NONE := ""
const MODE_ROAD_PLACEMENT := "road_placement"
const MODE_DESTROY_TARGETING := "destroy_targeting"


class PlacementHint extends Node2D:
	var tile_size := 96.0:
		set(value):
			tile_size = value
			queue_redraw()
	var hint_color := PLACEMENT_HINT_COLOR:
		set(value):
			hint_color = value
			queue_redraw()

	func _draw() -> void:
		var radius := tile_size * 0.17
		draw_circle(Vector2.ZERO, radius, hint_color)
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 32, hint_color.lightened(0.35), 3.0)

@export var map_path: NodePath
@export var roads_path: NodePath
@export var player_path: NodePath
@export var hand_path: NodePath
@export var deck_controller_path: NodePath
@export var tile_scene: PackedScene = preload("res://scenes/tile.tscn")
@export var controls_scene: PackedScene = preload("res://ui/placement_controls.tscn")

var active_card: CardView
var active_definition: Resource
var preview_position := Vector2i(-1, -1)
var rotation_steps := 0
var active_mode := MODE_NONE

var _map: GameMap
var _roads: Roads
var _player: GamePlayer
var _hand: HandUI
var _deck_controller: DeckController
var _preview_tile: RoadTile
var _targeted_tiles: Array[Vector2i] = []
var _controls_layer
var _placement_valid := false
var _placement_hints: Dictionary = {}


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

	_ensure_controls()
	_hide_preview()

	if not _hand.card_use_requested.is_connected(_on_card_use_requested):
		_hand.card_use_requested.connect(_on_card_use_requested)
	if not _map.tile_pressed.is_connected(_on_tile_pressed):
		_map.tile_pressed.connect(_on_tile_pressed)

	set_process_unhandled_input(true)
	set_process(false)


func _process(_delta: float) -> void:
	if _controls_layer != null:
		_controls_layer.position_buttons(preview_position, _map, _hand)


func _unhandled_input(event: InputEvent) -> void:
	if active_card == null or active_mode != MODE_ROAD_PLACEMENT or preview_position.x < 0:
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
	active_mode = MODE_ROAD_PLACEMENT
	preview_position = Vector2i(-1, -1)
	rotation_steps = 0
	_placement_valid = false
	_player.input_enabled = false
	_hand.clear_focus()
	_hide_preview()
	_refresh_placement_hints()
	_show_idle_placement_controls()
	_show_prompt()
	placement_started.emit(card)
	return true


func begin_destroy_targeting(card: CardView) -> bool:
	if card == null or card.category != DeckController.EVENT_CATEGORY or card.event_type != DeckController.EVENT_DESTROY_NEIGHBOR:
		return false

	active_card = card
	active_definition = null
	active_mode = MODE_DESTROY_TARGETING
	preview_position = Vector2i(-1, -1)
	rotation_steps = 0
	_placement_valid = false
	_player.input_enabled = false
	_hand.clear_focus()
	_hide_preview()
	_highlight_destroy_targets()
	_show_destroy_controls()
	_show_prompt()
	placement_started.emit(card)
	return true


func rotate_preview() -> void:
	if active_card == null or active_mode != MODE_ROAD_PLACEMENT:
		return
	rotation_steps = posmod(rotation_steps + 1, 4)
	_refresh_preview()


func confirm_placement() -> bool:
	if active_card == null or not _placement_valid:
		return false
	if active_mode == MODE_DESTROY_TARGETING:
		return _confirm_destroy_target()
	if active_mode != MODE_ROAD_PLACEMENT:
		return false

	var placed := _roads.place_tile(preview_position, active_definition, rotation_steps, active_card.encounter_data)
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
	if card.category == DeckController.ROAD_CATEGORY:
		begin_placement(card)
	elif card.event_type == DeckController.EVENT_DESTROY_NEIGHBOR:
		begin_destroy_targeting(card)


func _on_tile_pressed(grid_position: Vector2i) -> void:
	if active_card == null:
		return
	preview_position = grid_position
	_refresh_preview()


func _refresh_preview() -> void:
	if active_card == null or preview_position.x < 0:
		_hide_preview()
		return
	if active_mode == MODE_DESTROY_TARGETING:
		_refresh_destroy_target()
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
	_controls_layer.show_preview_controls(preview_position, _map, _hand, _placement_valid)
	set_process(true)


func _is_valid_placement(grid_position: Vector2i, connections: Dictionary) -> bool:
	var delta: Vector2i = grid_position - _player.grid_position
	if abs(delta.x) + abs(delta.y) != 1:
		return false
	return _map.can_place_tile(grid_position, connections)


func _is_valid_destroy_target(grid_position: Vector2i) -> bool:
	if _map.get_tile(grid_position) == null:
		return false
	if grid_position == _map.get_start_position() or grid_position == _map.get_goal_position():
		return false
	if grid_position == _player.grid_position:
		return false
	return true


func _confirm_destroy_target() -> bool:
	var destroyed_card := active_card
	var destroyed_position := preview_position
	_roads.remove_tile(destroyed_position)
	if _deck_controller != null:
		_deck_controller.consume_card(destroyed_card)
	else:
		_hand.remove_card(destroyed_card)
	_end_placement(false)
	tile_destroyed.emit(destroyed_position, destroyed_card)
	return true


func _refresh_destroy_target() -> void:
	_placement_valid = _is_valid_destroy_target(preview_position)
	_controls_layer.show_preview_controls(preview_position, _map, _hand, _placement_valid, false)
	_refresh_target_highlights()
	set_process(true)


func _end_placement(keep_card_focused: bool) -> void:
	var ending_card := active_card
	active_card = null
	active_definition = null
	active_mode = MODE_NONE
	preview_position = Vector2i(-1, -1)
	rotation_steps = 0
	_placement_valid = false
	_player.input_enabled = true
	if keep_card_focused and ending_card != null:
		_hand.focus_card(ending_card)
	elif not keep_card_focused:
		_hand.clear_focus()
	_clear_placement_hints()
	_clear_target_highlights()
	_hide_preview()


func _ensure_preview_tile() -> void:
	if _preview_tile != null:
		return
	_preview_tile = tile_scene.instantiate() as RoadTile
	add_child(_preview_tile)


func _hide_preview() -> void:
	if _preview_tile != null:
		_preview_tile.visible = false
	if _controls_layer != null:
		_controls_layer.hide_all()
	set_process(false)


func _ensure_controls() -> void:
	_controls_layer = get_node_or_null("PlacementControls") as CanvasLayer
	if _controls_layer == null:
		_controls_layer = controls_scene.instantiate() as CanvasLayer
		add_child(_controls_layer)

	_controls_layer.bind_actions(rotate_preview, confirm_placement, cancel_placement)


func _show_prompt() -> void:
	if active_mode == MODE_DESTROY_TARGETING:
		_controls_layer.show_prompt("Choose tile", _hand)
	else:
		_controls_layer.show_prompt("Place tile", _hand)
	set_process(true)


func _show_idle_placement_controls() -> void:
	_controls_layer.show_idle_placement(_hand)
	set_process(true)


func _show_destroy_controls() -> void:
	_controls_layer.show_destroy_targeting(_hand)
	set_process(true)


func _highlight_destroy_targets() -> void:
	_targeted_tiles.clear()
	for grid_position in _map.tiles:
		if grid_position is Vector2i:
			_targeted_tiles.append(grid_position)
	_refresh_target_highlights()


func _refresh_target_highlights() -> void:
	for grid_position in _targeted_tiles:
		var visual_tile := _roads.get_visual_tile(grid_position)
		if visual_tile == null:
			continue
		var valid := _is_valid_destroy_target(grid_position)
		var color := VALID_COLOR if valid else INVALID_COLOR
		if grid_position == preview_position:
			color = VALID_COLOR if valid else INVALID_COLOR
		elif valid:
			color = TARGET_COLOR
		visual_tile.set_highlight(true, color)


func _clear_target_highlights() -> void:
	for grid_position in _targeted_tiles:
		var visual_tile := _roads.get_visual_tile(grid_position)
		if visual_tile != null:
			visual_tile.set_highlight(false)
	_targeted_tiles.clear()


func _refresh_placement_hints() -> void:
	_clear_placement_hints()
	if active_mode != MODE_ROAD_PLACEMENT or active_definition == null:
		return
	for grid_position in _map.get_neighbors(_player.grid_position):
		if _has_valid_rotation_for_hint(grid_position):
			_add_placement_hint(grid_position)


func _has_valid_rotation_for_hint(grid_position: Vector2i) -> bool:
	for test_rotation in 4:
		var tile_data := _roads.make_tile_data(active_definition, test_rotation)
		if _is_valid_placement(grid_position, tile_data.get("connections", {})):
			return true
	return false


func _add_placement_hint(grid_position: Vector2i) -> void:
	var hint := PlacementHint.new()
	hint.name = "PlacementHint_%d_%d" % [grid_position.x, grid_position.y]
	hint.tile_size = _map.tile_size
	hint.hint_color = PLACEMENT_HINT_COLOR
	hint.position = _map.grid_to_world(grid_position)
	add_child(hint)
	_placement_hints[grid_position] = hint


func _clear_placement_hints() -> void:
	for hint in _placement_hints.values():
		if hint is Node:
			hint.queue_free()
	_placement_hints.clear()


func get_placement_hint_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for grid_position in _placement_hints:
		positions.append(grid_position)
	return positions
