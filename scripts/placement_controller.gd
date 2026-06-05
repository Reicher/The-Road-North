class_name PlacementController
extends Node3D

signal placement_started(card: CardView)
signal placement_cancelled(card: CardView)
signal placement_confirmed(grid_position: Vector2i, card: CardView)
signal tile_destroyed(grid_position: Vector2i, card: CardView)
signal tile_rotated(grid_position: Vector2i, card: CardView)

const VALID_COLOR := Color(0.10, 0.95, 0.28, 0.34)
const INVALID_COLOR := Color(1.00, 0.10, 0.08, 0.38)
const TARGET_COLOR := Color(0.98, 0.83, 0.24, 0.62)
const PLACEMENT_HINT_COLOR := Color(0.24, 0.88, 0.38, 0.58)
const MODE_NONE := ""
const MODE_ROAD_PLACEMENT := "road_placement"
const MODE_DESTROY_TARGETING := "destroy_targeting"
const MODE_ROTATE_TARGETING := "rotate_targeting"


class PlacementHint extends Node3D:
	var tile_size := 96.0:
		set(value):
			tile_size = value
			_rebuild()
	var hint_color := PLACEMENT_HINT_COLOR:
		set(value):
			hint_color = value
			_rebuild()
	var _visual: MeshInstance3D

	func _ready() -> void:
		_rebuild()

	func _rebuild() -> void:
		if not is_inside_tree():
			return
		if _visual != null:
			_visual.queue_free()
		var mesh := CylinderMesh.new()
		mesh.top_radius = tile_size * 0.17
		mesh.bottom_radius = tile_size * 0.17
		mesh.height = tile_size * 0.025
		mesh.radial_segments = 24
		_visual = MeshInstance3D.new()
		_visual.name = "Hint"
		_visual.mesh = mesh
		_visual.position = Vector3(0.0, tile_size * 0.05, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = hint_color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_visual.material_override = material
		add_child(_visual)

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
var _hidden_preview_trees_position := Vector2i(-1, -1)
var _hidden_preview_hint_position := Vector2i(-1, -1)
var _rotate_original_position := Vector2i(-1, -1)
var _rotate_original_tile_data: Dictionary = {}
var _rotate_original_rotation := 0


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
	if active_card == null or preview_position.x < 0:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		if _map.screen_to_grid(event.position) == preview_position:
			rotate_preview()
	elif event is InputEventScreenTouch and event.pressed and event.double_tap:
		if _map.screen_to_grid(event.position) == preview_position:
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
	if card == null or card.category != DeckController.EVENT_CATEGORY or card.event_type != DeckController.EVENT_DESTROY_TILE:
		return false

	return _begin_tile_targeting(card, MODE_DESTROY_TARGETING)


func begin_rotate_targeting(card: CardView) -> bool:
	if card == null or card.category != DeckController.EVENT_CATEGORY or card.event_type != DeckController.EVENT_ROTATE_TILE:
		return false

	return _begin_tile_targeting(card, MODE_ROTATE_TARGETING)


func _begin_tile_targeting(card: CardView, mode: String) -> bool:
	active_card = card
	active_definition = null
	active_mode = mode
	preview_position = Vector2i(-1, -1)
	rotation_steps = 0
	_placement_valid = false
	_player.input_enabled = false
	_hand.clear_focus()
	_hide_preview()
	_highlight_tile_targets()
	_controls_layer.show_tile_targeting(_hand)
	_show_prompt()
	placement_started.emit(card)
	return true


func rotate_preview() -> void:
	if active_card == null:
		return
	if active_mode == MODE_ROTATE_TARGETING:
		_rotate_selected_target()
		return
	if active_mode != MODE_ROAD_PLACEMENT:
		return
	rotation_steps = posmod(rotation_steps + 1, 4)
	_refresh_preview()


func confirm_placement() -> bool:
	if active_card == null or not _placement_valid:
		return false
	if active_mode == MODE_DESTROY_TARGETING:
		return _confirm_destroy_target()
	if active_mode == MODE_ROTATE_TARGETING:
		return _confirm_rotate_target()
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
	_restore_rotate_target()
	_end_placement(false)
	placement_cancelled.emit(cancelled_card)


func has_valid_preview() -> bool:
	return _placement_valid


func _on_card_use_requested(card: CardView) -> void:
	if card.category == DeckController.ROAD_CATEGORY:
		begin_placement(card)
	elif card.event_type == DeckController.EVENT_DESTROY_TILE:
		begin_destroy_targeting(card)
	elif card.event_type == DeckController.EVENT_ROTATE_TILE:
		begin_rotate_targeting(card)


func _on_tile_pressed(grid_position: Vector2i) -> void:
	if active_card == null:
		return
	if active_mode == MODE_ROTATE_TARGETING:
		_restore_rotate_target()
	preview_position = grid_position
	_refresh_preview()


func _refresh_preview() -> void:
	if active_card == null or preview_position.x < 0:
		_hide_preview()
		return
	if active_mode == MODE_DESTROY_TARGETING or active_mode == MODE_ROTATE_TARGETING:
		_restore_preview_trees()
		_restore_preview_hint()
		_refresh_tile_target()
		return

	_hide_preview_trees(preview_position)
	_hide_preview_hint(preview_position)
	_ensure_preview_tile()
	_preview_tile.definition = active_definition
	_preview_tile.rotation_steps = rotation_steps
	_preview_tile.tile_size = _map.tile_size
	_preview_tile.position = _map.grid_to_world(preview_position) + Vector3(0.0, _map.tile_size * 0.04, 0.0)
	_preview_tile.scale = Vector3(1.03, 1.0, 1.03)
	_preview_tile.visible = true

	var tile_data := _roads.make_tile_data(active_definition, rotation_steps)
	_placement_valid = _is_valid_placement(preview_position, tile_data.get("connections", {}))
	_preview_tile.tile_tint = Color(1.08, 1.08, 1.04, 0.98)
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


func _is_valid_rotate_target(grid_position: Vector2i) -> bool:
	if not _is_valid_destroy_target(grid_position):
		return false
	var tile_data: Variant = _map.get_tile(grid_position)
	return tile_data is Dictionary and tile_data.get("definition") != null


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


func _confirm_rotate_target() -> bool:
	var rotated_card := active_card
	var rotated_position := preview_position
	if not _rotate_target_has_changed():
		_refresh_tile_target()
		return false
	if _deck_controller != null:
		_deck_controller.consume_card(rotated_card)
	else:
		_hand.remove_card(rotated_card)
	_end_placement(false)
	tile_rotated.emit(rotated_position, rotated_card)
	return true


func _refresh_tile_target() -> void:
	var valid_target := _is_valid_tile_target(preview_position)
	if active_mode == MODE_ROTATE_TARGETING and valid_target:
		_capture_rotate_target()
		_placement_valid = _rotate_target_has_changed()
		_controls_layer.show_preview_controls(preview_position, _map, _hand, _placement_valid, true)
	else:
		_placement_valid = valid_target
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
	_clear_rotate_target_snapshot()
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
	_preview_tile = get_node_or_null("PreviewTile") as RoadTile
	if _preview_tile == null:
		_preview_tile = tile_scene.instantiate() as RoadTile
		_preview_tile.name = "PreviewTile"
		add_child(_preview_tile)


func _hide_preview() -> void:
	_restore_preview_trees()
	_restore_preview_hint()
	if _preview_tile != null:
		_preview_tile.visible = false
	if _controls_layer != null:
		_controls_layer.hide_all()
	set_process(false)


func _hide_preview_trees(grid_position: Vector2i) -> void:
	if grid_position == _hidden_preview_trees_position:
		return
	_restore_preview_trees()
	_map.set_cell_trees_visible(grid_position, false)
	_hidden_preview_trees_position = grid_position


func _restore_preview_trees() -> void:
	if _hidden_preview_trees_position.x < 0:
		return
	_map.set_cell_trees_visible(_hidden_preview_trees_position, true)
	_hidden_preview_trees_position = Vector2i(-1, -1)


func _hide_preview_hint(grid_position: Vector2i) -> void:
	if grid_position == _hidden_preview_hint_position:
		return
	_restore_preview_hint()
	var hint: Node3D = _placement_hints.get(grid_position) as Node3D
	if hint != null:
		hint.visible = false
		_hidden_preview_hint_position = grid_position


func _restore_preview_hint() -> void:
	if _hidden_preview_hint_position.x < 0:
		return
	var hint: Node3D = _placement_hints.get(_hidden_preview_hint_position) as Node3D
	if hint != null:
		hint.visible = true
	_hidden_preview_hint_position = Vector2i(-1, -1)


func _ensure_controls() -> void:
	_controls_layer = get_node_or_null("PlacementControls") as CanvasLayer
	if _controls_layer == null:
		_controls_layer = controls_scene.instantiate() as CanvasLayer
		add_child(_controls_layer)

	_controls_layer.bind_actions(rotate_preview, confirm_placement, cancel_placement)


func _show_prompt() -> void:
	if active_mode == MODE_DESTROY_TARGETING:
		_controls_layer.show_prompt("Choose tile", _hand)
	elif active_mode == MODE_ROTATE_TARGETING:
		_controls_layer.show_prompt("Rotate tile", _hand)
	else:
		_controls_layer.show_prompt("Place tile", _hand)
	set_process(true)


func _show_idle_placement_controls() -> void:
	_controls_layer.show_idle_placement(_hand)
	set_process(true)


func _highlight_tile_targets() -> void:
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
		var valid := _is_valid_tile_target(grid_position)
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


func _is_valid_tile_target(grid_position: Vector2i) -> bool:
	if active_mode == MODE_ROTATE_TARGETING:
		return _is_valid_rotate_target(grid_position)
	return _is_valid_destroy_target(grid_position)


func _capture_rotate_target() -> void:
	if _rotate_original_position == preview_position:
		return
	var tile_data: Variant = _map.get_tile(preview_position)
	if not (tile_data is Dictionary):
		return
	_rotate_original_position = preview_position
	_rotate_original_tile_data = tile_data.duplicate(true)
	_rotate_original_rotation = int(tile_data.get("rotation_steps", 0))
	rotation_steps = _rotate_original_rotation


func _rotate_selected_target() -> void:
	if active_mode != MODE_ROTATE_TARGETING or not _is_valid_rotate_target(preview_position):
		return
	_capture_rotate_target()
	rotation_steps = posmod(rotation_steps + 1, 4)
	_apply_rotate_target_rotation(rotation_steps)
	_placement_valid = _rotate_target_has_changed()
	_controls_layer.show_preview_controls(preview_position, _map, _hand, _placement_valid, true)
	_refresh_target_highlights()


func _apply_rotate_target_rotation(new_rotation: int) -> void:
	var tile_data: Variant = _map.get_tile(preview_position)
	if not (tile_data is Dictionary):
		return
	var definition: Resource = tile_data.get("definition")
	if definition == null or not definition.has_method("get_rotated_openings"):
		return
	tile_data = tile_data.duplicate(true)
	tile_data["rotation_steps"] = posmod(new_rotation, 4)
	tile_data["connections"] = definition.get_rotated_openings(tile_data["rotation_steps"])
	_map.set_tile(preview_position, tile_data)
	var visual_tile := _roads.get_visual_tile(preview_position)
	if visual_tile != null:
		visual_tile.rotation_steps = tile_data["rotation_steps"]


func _restore_rotate_target() -> void:
	if active_mode != MODE_ROTATE_TARGETING or _rotate_original_position.x < 0 or _rotate_original_tile_data.is_empty():
		return
	_map.set_tile(_rotate_original_position, _rotate_original_tile_data.duplicate(true))
	var visual_tile := _roads.get_visual_tile(_rotate_original_position)
	if visual_tile != null:
		visual_tile.rotation_steps = int(_rotate_original_tile_data.get("rotation_steps", 0))
	_clear_rotate_target_snapshot()


func _rotate_target_has_changed() -> bool:
	if _rotate_original_position != preview_position:
		return false
	return posmod(rotation_steps, 4) != posmod(_rotate_original_rotation, 4)


func _clear_rotate_target_snapshot() -> void:
	_rotate_original_position = Vector2i(-1, -1)
	_rotate_original_tile_data.clear()
	_rotate_original_rotation = 0


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
	_hidden_preview_hint_position = Vector2i(-1, -1)
	for hint in _placement_hints.values():
		if hint is Node:
			(hint as Node3D).visible = false
			hint.queue_free()
	_placement_hints.clear()


func get_placement_hint_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for grid_position in _placement_hints:
		positions.append(grid_position)
	return positions
