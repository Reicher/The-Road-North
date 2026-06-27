class_name PlacementController
extends Node3D

signal placement_started(card: CardView)
signal placement_cancelled(card: CardView)
signal placement_confirmed(grid_position: Vector2i, card: CardView)
signal tile_destroyed(grid_position: Vector2i, card: CardView)
signal tile_rotated(grid_position: Vector2i, card: CardView)
signal encounter_changed(grid_position: Vector2i, card: CardView)

const VALID_COLOR := Color(0.18, 0.88, 0.34, 0.82)
const INVALID_COLOR := Color(0.96, 0.16, 0.12, 0.86)
const MODE_NONE := ""
const MODE_ROAD_PLACEMENT := "road_placement"
const MODE_DESTROY_TARGETING := "destroy_targeting"
const MODE_ROTATE_TARGETING := "rotate_targeting"
const MODE_ENCOUNTER_TARGETING := "encounter_targeting"
const SIGHT_FOG_COLOR := Color(0.008, 0.012, 0.016, 0.75)
const SIGHT_MASK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 player_grid;
uniform vec2 map_size;
uniform float tile_size;
uniform float sight;
uniform vec4 fog_color : source_color;

const float EDGE_SOFTNESS = 0.20;

float grid_distance(vec2 a, vec2 b) {
	return abs(a.x - b.x) + abs(a.y - b.y);
}

float distance_to_cell(vec2 point, vec2 cell) {
	vec2 distance_to_box = max(abs(point - (cell + vec2(0.5))) - vec2(0.5), vec2(0.0));
	return length(distance_to_box);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	if (depth <= 0.00001) {
		discard;
	}
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_position.xyz /= view_position.w;
	vec3 world_position = (INV_VIEW_MATRIX * vec4(view_position.xyz, 1.0)).xyz;
	vec2 grid_position = floor(world_position.xz / tile_size);
	bool inside_map = grid_position.x >= 0.0 && grid_position.y >= 0.0
		&& grid_position.x < map_size.x && grid_position.y < map_size.y;
	float distance_from_player = grid_distance(grid_position, player_grid);
	if (inside_map && distance_from_player <= sight) {
		discard;
	}

	float edge_alpha = 1.0;
	if (inside_map) {
		vec2 continuous_grid_position = world_position.xz / tile_size;
		float distance_to_clear_area = 2.0;
		for (int offset_y = -1; offset_y <= 1; offset_y++) {
			for (int offset_x = -1; offset_x <= 1; offset_x++) {
				vec2 candidate = grid_position + vec2(float(offset_x), float(offset_y));
				if (grid_distance(candidate, player_grid) <= sight) {
					distance_to_clear_area = min(distance_to_clear_area, distance_to_cell(continuous_grid_position, candidate));
				}
			}
		}
		float edge_noise = sin(world_position.x * 0.075 + TIME * 0.28)
			* sin(world_position.z * 0.061 - TIME * 0.19) * 0.018;
		edge_alpha = smoothstep(0.0, EDGE_SOFTNESS, distance_to_clear_area + edge_noise);
		edge_alpha = mix(0.22, 1.0, edge_alpha);
	}
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * edge_alpha;
}
"""

class TargetPreview extends Node3D:
	var preview_color := Color.TRANSPARENT
	var _mesh_instance: MeshInstance3D


	func configure(tile_size: float, color: Color) -> void:
		preview_color = color
		if _mesh_instance == null:
			_mesh_instance = MeshInstance3D.new()
			_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_mesh_instance)

		var mesh := BoxMesh.new()
		mesh.size = Vector3(tile_size * 0.88, tile_size * 0.025, tile_size * 0.88)
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = material
		_mesh_instance.mesh = mesh


class SightFog extends Node3D:
	var fogged_positions: Array[Vector2i] = []
	var _mask: MeshInstance3D
	var _mask_material: ShaderMaterial


	func show_for(map: GameMap, origin: Vector2i, sight: int) -> void:
		_ensure_mask()
		fogged_positions.clear()
		for y in map.playable_height:
			for x in map.playable_width:
				var grid_position := Vector2i(x, y)
				if _manhattan_distance(origin, grid_position) <= sight:
					continue
				fogged_positions.append(grid_position)
		_mask_material.set_shader_parameter("player_grid", Vector2(origin))
		_mask_material.set_shader_parameter("map_size", Vector2(map.playable_width, map.playable_height))
		_mask_material.set_shader_parameter("tile_size", map.tile_size)
		_mask_material.set_shader_parameter("sight", float(sight))
		_mask_material.set_shader_parameter("fog_color", SIGHT_FOG_COLOR)
		visible = true


	func hide_fog() -> void:
		visible = false


	func _ensure_mask() -> void:
		if _mask != null:
			return
		var shader := Shader.new()
		shader.code = SIGHT_MASK_SHADER
		_mask_material = ShaderMaterial.new()
		_mask_material.shader = shader
		_mask_material.render_priority = 127
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		quad.material = _mask_material
		_mask = MeshInstance3D.new()
		_mask.name = "FullscreenMask"
		_mask.mesh = quad
		_mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mask.extra_cull_margin = 16384.0
		add_child(_mask)


	func _manhattan_distance(from: Vector2i, to: Vector2i) -> int:
		var delta := to - from
		return absi(delta.x) + absi(delta.y)


@export var map_path: NodePath
@export var roads_path: NodePath
@export var player_path: NodePath
@export var hand_path: NodePath
@export var inventory_path: NodePath
@export var deck_controller_path: NodePath
@export var tile_scene: PackedScene = preload("res://scenes/tile.tscn")
@export var controls_scene: PackedScene = preload("res://ui/placement_controls.tscn")
@export_range(1, 8, 1) var base_sight := 2

var active_card: CardView
var active_definition: Resource
var preview_position := Vector2i(-1, -1)
var rotation_steps := 0
var active_mode := MODE_NONE

var _map: GameMap
var _roads: Roads
var _player: GamePlayer
var _hand: HandUI
var _inventory: InventoryUI
var _deck_controller: DeckController
var _validator: PlacementValidator
var _preview_tile: RoadTile
var _target_preview: TargetPreview
var _sight_fog: SightFog
var _controls_layer: PlacementControlsUI
var _placement_valid := false
var _hidden_preview_trees_position := Vector2i(-1, -1)
var _rotate_original_position := Vector2i(-1, -1)
var _rotate_original_tile_data: Dictionary = {}
var _rotate_original_rotation := 0
var _card_drag_in_progress := false
var _preview_drag_pointer_id := -2


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_roads = get_node_or_null(roads_path) as Roads
	_player = get_node_or_null(player_path) as GamePlayer
	_hand = get_node_or_null(hand_path) as HandUI
	_inventory = get_node_or_null(inventory_path) as InventoryUI
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

	_validator = PlacementValidator.new()
	_validator.setup(_map, _player, get_sight)
	_ensure_controls()
	_hide_preview()

	if not _hand.card_drag_moved.is_connected(_on_card_drag_moved):
		_hand.card_drag_moved.connect(_on_card_drag_moved)
	if not _hand.card_drag_finished.is_connected(_on_card_drag_finished):
		_hand.card_drag_finished.connect(_on_card_drag_finished)
	set_process_unhandled_input(true)
	set_process(false)


func _process(_delta: float) -> void:
	if _controls_layer != null:
		_controls_layer.position_buttons(preview_position, _map, _hand)


func _unhandled_input(event: InputEvent) -> void:
	if active_card == null or preview_position.x < 0:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_grid_position := _map.screen_to_grid(event.position)
		if event.pressed:
			if event.double_click and mouse_grid_position == preview_position:
				rotate_preview()
			else:
				_try_start_preview_drag(mouse_grid_position, -1)
		elif _preview_drag_pointer_id == -1:
			_finish_preview_drag()
	elif event is InputEventMouseMotion and _preview_drag_pointer_id == -1:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move_preview_drag(_map.screen_to_grid(event.position))
		else:
			_finish_preview_drag()
	elif event is InputEventScreenTouch:
		var touch_grid_position := _map.screen_to_grid(event.position)
		if event.pressed:
			if event.double_tap and touch_grid_position == preview_position:
				rotate_preview()
			else:
				_try_start_preview_drag(touch_grid_position, event.index)
		elif _preview_drag_pointer_id == event.index:
			_finish_preview_drag()
	elif event is InputEventScreenDrag and _preview_drag_pointer_id == event.index:
		_move_preview_drag(_map.screen_to_grid(event.position))


func is_placing() -> bool:
	return active_card != null


func begin_placement(card: CardView) -> bool:
	if card == null or card.category != GameConstants.ROAD_CATEGORY or card.tile_definition == null:
		return false

	_begin_mode(card, MODE_ROAD_PLACEMENT, card.tile_definition)
	if not _card_drag_in_progress:
		_show_idle_placement_controls()
		_show_prompt()
	return true


func begin_destroy_targeting(card: CardView) -> bool:
	if card == null or card.category != GameConstants.EVENT_CATEGORY or card.event_type != GameConstants.EVENT_DESTROY_TILE:
		return false

	return _begin_tile_targeting(card, MODE_DESTROY_TARGETING)


func begin_rotate_targeting(card: CardView) -> bool:
	if card == null or card.category != GameConstants.EVENT_CATEGORY or card.event_type != GameConstants.EVENT_ROTATE_TILE:
		return false

	return _begin_tile_targeting(card, MODE_ROTATE_TARGETING)


func begin_encounter_targeting(card: CardView) -> bool:
	if card == null or card.category != GameConstants.EVENT_CATEGORY or not _is_encounter_event(card.event_type):
		return false

	return _begin_tile_targeting(card, MODE_ENCOUNTER_TARGETING)


func _begin_tile_targeting(card: CardView, mode: String) -> bool:
	_begin_mode(card, mode)
	if not _card_drag_in_progress:
		_controls_layer.show_tile_targeting(_hand)
		_show_prompt()
	return true


func _begin_mode(card: CardView, mode: String, definition: Resource = null) -> void:
	active_card = card
	active_definition = definition
	active_mode = mode
	preview_position = Vector2i(-1, -1)
	rotation_steps = card.rotation_steps if mode == MODE_ROAD_PLACEMENT else 0
	_placement_valid = false
	_player.input_enabled = false
	_hand.interaction_enabled = false
	_hand.clear_focus()
	_hide_preview()
	_show_sight_fog()
	placement_started.emit(card)


func rotate_preview() -> void:
	if active_card == null:
		return
	if active_mode == MODE_ROTATE_TARGETING:
		_rotate_selected_target()
		return
	if active_mode != MODE_ROAD_PLACEMENT:
		return
	if active_card.rotation_locked:
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
	if active_mode == MODE_ENCOUNTER_TARGETING:
		return _confirm_encounter_target()
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
	_end_placement()
	placement_confirmed.emit(confirmed_position, confirmed_card)
	return true


func cancel_placement() -> void:
	if active_card == null:
		return
	var cancelled_card := active_card
	_restore_rotate_target()
	_end_placement()
	placement_cancelled.emit(cancelled_card)


func has_valid_preview() -> bool:
	return _placement_valid


func _begin_for_dragged_card(card: CardView) -> bool:
	if card.category == GameConstants.ROAD_CATEGORY:
		return begin_placement(card)
	elif card.event_type == GameConstants.EVENT_DESTROY_TILE:
		return begin_destroy_targeting(card)
	elif card.event_type == GameConstants.EVENT_ROTATE_TILE:
		return begin_rotate_targeting(card)
	elif _is_encounter_event(card.event_type):
		return begin_encounter_targeting(card)
	return false


func _on_card_drag_moved(card: CardView, canvas_position: Vector2, activated: bool) -> void:
	if not activated:
		if active_card == card:
			cancel_placement()
		return
	if active_card == null:
		_card_drag_in_progress = true
		if not _begin_for_dragged_card(card):
			_card_drag_in_progress = false
			return
	if active_card != card:
		return
	var grid_position := _map.screen_to_grid(canvas_position)
	if _map.is_inside_playable_area(grid_position):
		if active_mode == MODE_ROTATE_TARGETING:
			_restore_rotate_target()
		preview_position = grid_position
		_refresh_preview()


func _on_card_drag_finished(card: CardView, canvas_position: Vector2, activated: bool, released_over_hand: bool) -> void:
	if active_card != card:
		return
	var grid_position := _map.screen_to_grid(canvas_position)
	if released_over_hand or not activated or not _map.is_inside_playable_area(grid_position):
		cancel_placement()
		return
	_card_drag_in_progress = false
	_refresh_preview()


func _try_start_preview_drag(grid_position: Vector2i, pointer_id: int) -> bool:
	if active_card == null or preview_position != grid_position or _preview_drag_pointer_id != -2:
		return false
	_preview_drag_pointer_id = pointer_id
	add_to_group("ui_item_drag_active")
	return true


func _move_preview_drag(grid_position: Vector2i) -> void:
	if _preview_drag_pointer_id == -2 or not _map.is_inside_playable_area(grid_position):
		return
	if grid_position == preview_position:
		return
	if active_mode == MODE_ROTATE_TARGETING:
		_restore_rotate_target()
	preview_position = grid_position
	_refresh_preview()


func _finish_preview_drag() -> void:
	if _preview_drag_pointer_id == -2:
		return
	_preview_drag_pointer_id = -2
	remove_from_group("ui_item_drag_active")


func _refresh_preview() -> void:
	if active_card == null or preview_position.x < 0:
		_hide_preview()
		return
	if active_mode in [MODE_DESTROY_TARGETING, MODE_ROTATE_TARGETING, MODE_ENCOUNTER_TARGETING]:
		_restore_preview_trees()
		_refresh_tile_target()
		return

	_hide_preview_trees(preview_position)
	_ensure_preview_tile()
	_preview_tile.definition = active_definition
	_preview_tile.rotation_steps = rotation_steps
	_preview_tile.tile_size = _map.tile_size
	_preview_tile.encounter_power_visible = false
	_preview_tile.set_preview_encounter_data(_get_preview_encounter_data())
	_preview_tile.position = _map.grid_to_world(preview_position)
	_preview_tile.scale = Vector3.ONE
	_preview_tile.visible = true

	var tile_data := _roads.make_tile_data(active_definition, rotation_steps)
	var connections: Dictionary = tile_data.get("connections", {})
	var invalid_hint := _get_road_placement_hint(preview_position, connections)
	_placement_valid = invalid_hint.is_empty()
	_preview_tile.tile_tint = Color(1.08, 1.08, 1.04, 0.98)
	_preview_tile.set_highlight(true, VALID_COLOR if _placement_valid else INVALID_COLOR)
	if not _card_drag_in_progress:
		_controls_layer.show_preview_controls(preview_position, _map, _hand, _placement_valid, not active_card.rotation_locked, invalid_hint)
	else:
		_controls_layer.show_hint(invalid_hint, _hand, preview_position, _map)
	set_process(true)


func _get_preview_encounter_data() -> Dictionary:
	var encounter := active_card.encounter_data.duplicate(true) if active_card != null else {}
	if str(encounter.get("type", "")) == GameMap.ENCOUNTER_ENEMY:
		encounter["revealed"] = true
	return encounter


func get_sight() -> int:
	var inventory_bonus := _inventory.get_sight_bonus() if _inventory != null else 0
	return base_sight + inventory_bonus


func is_in_sight(grid_position: Vector2i) -> bool:
	var delta := grid_position - _player.grid_position
	return absi(delta.x) + absi(delta.y) <= get_sight()


func _confirm_destroy_target() -> bool:
	var destroyed_card := active_card
	var destroyed_position := preview_position
	_roads.remove_tile(destroyed_position)
	if _deck_controller != null:
		_deck_controller.consume_card(destroyed_card)
	else:
		_hand.remove_card(destroyed_card)
	_end_placement()
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
	_end_placement()
	tile_rotated.emit(rotated_position, rotated_card)
	return true


func _confirm_encounter_target() -> bool:
	var event_card := active_card
	var target_position := preview_position
	var changed := false
	if event_card.event_type == GameConstants.EVENT_CLEAR_PATH:
		changed = _roads.clear_encounter(target_position)
	else:
		changed = _roads.set_encounter(target_position, event_card.encounter_data)
	if not changed:
		_refresh_tile_target()
		return false
	if _deck_controller != null:
		_deck_controller.consume_card(event_card)
	else:
		_hand.remove_card(event_card)
	_end_placement()
	encounter_changed.emit(target_position, event_card)
	return true


func _refresh_tile_target() -> void:
	var valid_target := _is_valid_tile_target(preview_position)
	var invalid_hint := _get_tile_target_hint(preview_position)
	if active_mode == MODE_ROTATE_TARGETING and valid_target:
		_capture_rotate_target()
		_placement_valid = _rotate_target_has_changed()
		if not _card_drag_in_progress:
			_controls_layer.show_preview_controls(preview_position, _map, _hand, _placement_valid, true)
	else:
		_placement_valid = valid_target
		if not _card_drag_in_progress:
			_controls_layer.show_preview_controls(preview_position, _map, _hand, _placement_valid, false, invalid_hint)
	if _card_drag_in_progress:
		_controls_layer.show_hint(invalid_hint, _hand, preview_position, _map)
	_refresh_target_preview(valid_target)
	set_process(true)


func _end_placement() -> void:
	active_card = null
	active_definition = null
	active_mode = MODE_NONE
	preview_position = Vector2i(-1, -1)
	rotation_steps = 0
	_placement_valid = false
	_card_drag_in_progress = false
	_finish_preview_drag()
	_clear_rotate_target_snapshot()
	_player.input_enabled = true
	_hand.interaction_enabled = true
	_hand.set_inactive(false)
	_hand.clear_focus()
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
	if _preview_tile != null:
		_preview_tile.visible = false
	if _target_preview != null:
		_target_preview.visible = false
	if _sight_fog != null:
		_sight_fog.hide_fog()
	if _controls_layer != null:
		_controls_layer.hide_all()
	set_process(false)


func _show_sight_fog() -> void:
	if _sight_fog == null:
		_sight_fog = SightFog.new()
		_sight_fog.name = "SightFog"
		add_child(_sight_fog)
	_sight_fog.show_for(_map, _player.grid_position, get_sight())


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


func _ensure_controls() -> void:
	_controls_layer = get_node_or_null("PlacementControls") as PlacementControlsUI
	if _controls_layer == null:
		_controls_layer = controls_scene.instantiate() as PlacementControlsUI
		add_child(_controls_layer)

	_controls_layer.bind_actions(rotate_preview, confirm_placement, cancel_placement)


func _show_prompt() -> void:
	if active_mode == MODE_DESTROY_TARGETING:
		_controls_layer.show_prompt("Choose tile", _hand)
	elif active_mode == MODE_ROTATE_TARGETING:
		_controls_layer.show_prompt("Rotate tile", _hand)
	elif active_mode == MODE_ENCOUNTER_TARGETING:
		_controls_layer.show_prompt("Choose road", _hand)
	else:
		_controls_layer.show_prompt("Place tile", _hand)
	set_process(true)


func _show_idle_placement_controls() -> void:
	_controls_layer.show_idle_placement(_hand)
	set_process(true)


func _refresh_target_preview(valid_target: bool) -> void:
	if _target_preview == null:
		_target_preview = TargetPreview.new()
		_target_preview.name = "TargetPreview"
		add_child(_target_preview)
	_target_preview.position = _map.grid_to_world(preview_position) + Vector3(0.0, _map.tile_size * 0.07, 0.0)
	_target_preview.configure(_map.tile_size, VALID_COLOR if valid_target else INVALID_COLOR)
	_target_preview.visible = true


func _is_valid_tile_target(grid_position: Vector2i) -> bool:
	var event_type := active_card.event_type if active_card != null else ""
	if active_mode == MODE_ROTATE_TARGETING:
		return _validator.is_valid_rotate_target(grid_position)
	if active_mode == MODE_ENCOUNTER_TARGETING:
		return _validator.is_valid_encounter_target(grid_position, event_type)
	return _validator.is_valid_destroy_target(grid_position)


func _get_road_placement_hint(grid_position: Vector2i, connections: Dictionary) -> String:
	var allow_river: bool = active_definition != null and active_definition.get("placeable_on_river") == true
	return _validator.get_road_placement_hint(grid_position, connections, allow_river)


func _get_tile_target_hint(grid_position: Vector2i) -> String:
	var event_type := active_card.event_type if active_card != null else ""
	return _validator.get_tile_target_hint(grid_position, event_type)


func _is_encounter_event(event_type: String) -> bool:
	return event_type in GameConstants.ENCOUNTER_EVENT_TYPES


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
	if active_mode != MODE_ROTATE_TARGETING or not _validator.is_valid_rotate_target(preview_position):
		return
	_capture_rotate_target()
	var valid_rotations := _validator.get_valid_alternative_rotations(preview_position)
	var next_index := 0
	for index in valid_rotations.size():
		if valid_rotations[index] == rotation_steps:
			next_index = posmod(index + 1, valid_rotations.size())
			break
	rotation_steps = valid_rotations[next_index]
	_apply_rotate_target_rotation(rotation_steps)
	_placement_valid = _rotate_target_has_changed()
	_controls_layer.show_preview_controls(preview_position, _map, _hand, _placement_valid, true)
	_refresh_target_preview(true)


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
