extends Camera3D

@export var map_path: NodePath
@export var player_path: NodePath
@export var reserved_bottom_path: NodePath
@export var initial_visible_tile_width := 5.0
@export var zoom_in_visible_tile_width := 4.0
@export_range(0.0, 10.0, 0.1) var start_zoom_hold_duration := 2.0
@export_range(0.0, 5.0, 0.05) var start_zoom_duration := 0.85
@export_range(0.0, 2.0, 0.01) var move_focus_duration := 0.18
@export var zoom_step := 0.10
@export var mouse_pan_threshold := 4.0
@export_range(20.0, 80.0, 1.0) var camera_angle_degrees := 55.0
@export_range(0.0, 3.0, 0.05) var pan_margin_x_tiles := 0.0
@export_range(0.0, 3.0, 0.05) var pan_margin_z_tiles := 0.0

var _map: GameMap
var _player: GamePlayer
var _reserved_bottom_control: Control
var _input_handler: CameraInputHandler
var _target_xz := Vector2.ZERO
var _start_zoom_tween: Tween
var _move_focus_tween: Tween
var _following_player := false


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_player = get_node_or_null(player_path) as GamePlayer
	_reserved_bottom_control = get_node_or_null(reserved_bottom_path) as Control
	_input_handler = CameraInputHandler.new()
	_input_handler.mouse_pan_threshold = mouse_pan_threshold
	_input_handler.zoom_requested.connect(_on_input_zoom_requested)
	_input_handler.pan_requested.connect(_on_input_pan_requested)
	get_viewport().size_changed.connect(_refresh_limits)
	if _reserved_bottom_control != null:
		_reserved_bottom_control.resized.connect(_refresh_limits)
	if _player != null and not _player.move_started.is_connected(_on_player_move_started):
		_player.move_started.connect(_on_player_move_started)
	if _player != null and not _player.moved.is_connected(_on_player_moved):
		_player.moved.connect(_on_player_moved)
	if _map != null:
		size = _get_zoom_out_limit()
		_target_xz = _world_to_xz(_get_full_map_position())
		_clamp_target()
		_apply_camera_transform()
		call_deferred("_play_start_zoom_sequence")


func _process(_delta: float) -> void:
	if _following_player:
		_follow_player_position()


func _exit_tree() -> void:
	if _start_zoom_tween != null:
		_start_zoom_tween.kill()
		_start_zoom_tween = null
	if _move_focus_tween != null:
		_move_focus_tween.kill()
		_move_focus_tween = null


func _input(event: InputEvent) -> void:
	if _map == null or _is_ui_item_drag_active():
		return
	if _input_handler.handle_scroll_zoom(event, _is_in_map_screen_area, size, zoom_step):
		get_viewport().set_input_as_handled()
	elif _input_handler.handle_mouse_pan(event, _is_in_map_screen_area):
		get_viewport().set_input_as_handled()
	elif _input_handler.handle_trackpad_zoom(event, size, get_viewport().get_mouse_position()):
		get_viewport().set_input_as_handled()
	elif _input_handler.handle_trackpad_pan(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _map == null:
		return
	if _is_ui_item_drag_active():
		return

	if event is InputEventScreenTouch:
		_input_handler.handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_input_handler.handle_screen_drag(event, size)


func _is_ui_item_drag_active() -> bool:
	return get_tree().get_node_count_in_group("ui_item_drag_active") > 0


func _on_input_zoom_requested(target_size: float, screen_anchor: Vector2) -> void:
	_apply_zoom(target_size, screen_anchor)


func _on_input_pan_requested(screen_delta: Vector2) -> void:
	_pan_by_screen_delta(screen_delta)


func _refresh_limits() -> void:
	if _map == null:
		return
	size = clampf(size, _get_zoom_in_limit(), _get_zoom_out_limit())
	_clamp_target()
	_apply_camera_transform()


func _apply_zoom(target_size: float, screen_anchor: Vector2) -> void:
	var previous_world := _screen_to_ground(screen_anchor)
	size = clampf(target_size, _get_zoom_in_limit(), _get_zoom_out_limit())
	_apply_camera_transform()
	var next_world := _screen_to_ground(screen_anchor)
	if previous_world != Vector3.INF and next_world != Vector3.INF:
		var delta := previous_world - next_world
		_target_xz += Vector2(delta.x, delta.z)
	_clamp_target()
	_apply_camera_transform()


func _pan_by_screen_delta(delta: Vector2) -> void:
	var viewport_size := _get_map_viewport_size()
	var world_per_pixel := size / maxf(viewport_size.y, 1.0)
	var right := global_transform.basis.x
	var up := global_transform.basis.y
	var right_xz := Vector2(right.x, right.z).normalized()
	var up_xz := Vector2(up.x, up.z).normalized()
	_target_xz -= right_xz * delta.x * world_per_pixel
	_target_xz += up_xz * delta.y * world_per_pixel
	_clamp_target()
	_apply_camera_transform()


func _clamp_target() -> void:
	if _map == null:
		return
	_target_xz = _clamp_xz_for_size(_target_xz, size)


func _apply_camera_transform() -> void:
	var angle := deg_to_rad(camera_angle_degrees)
	var distance := maxf(_map.tile_size * 7.0 if _map != null else 700.0, size * 1.8)
	var target := Vector3(_target_xz.x, 0.0, _target_xz.y)
	var offset := Vector3(0.0, sin(angle) * distance, cos(angle) * distance)
	global_position = target + offset
	rotation_degrees = Vector3(-camera_angle_degrees, 0.0, 0.0)


func _get_zoom_out_limit() -> float:
	if _map == null:
		return 640.0
	var viewport_size := _get_map_viewport_size()
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var padded_size := _map.get_padded_world_rect().size
	return maxf(_get_ground_size_for_vertical_map_span(padded_size.y), padded_size.x / maxf(aspect, 0.01))


func _get_zoom_in_limit() -> float:
	if _map == null:
		return 240.0
	var viewport_size := _get_map_viewport_size()
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	return maxf(_map.tile_size * zoom_in_visible_tile_width / maxf(aspect, 0.01), _map.tile_size * 1.2)


func _get_initial_zoom_target() -> float:
	if _map == null:
		return size
	var viewport_size := _get_map_viewport_size()
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var wanted_size := _map.tile_size * initial_visible_tile_width / maxf(aspect, 1.0)
	return clampf(wanted_size, _get_zoom_in_limit(), _get_zoom_out_limit())


func _get_camera_boundary_rect() -> Rect2:
	var map_rect := _map.get_padded_world_rect()
	var margin := Vector2(_map.tile_size * pan_margin_x_tiles, _map.tile_size * pan_margin_z_tiles)
	return Rect2(map_rect.position - margin, map_rect.size + margin * 2.0)


func _get_ground_size_for_vertical_map_span(map_depth: float) -> float:
	var angle := deg_to_rad(camera_angle_degrees)
	return map_depth * maxf(sin(angle), 0.25)


func _get_visible_ground_size_for_size(camera_size: float) -> Vector2:
	var viewport_size := _get_map_viewport_size()
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var angle := deg_to_rad(camera_angle_degrees)
	return Vector2(camera_size * aspect, camera_size / maxf(sin(angle), 0.25))


func _get_full_map_position() -> Vector3:
	if _map == null:
		return Vector3.ZERO
	var center := _map.get_padded_world_rect().get_center()
	return Vector3(center.x, 0.0, center.y)


func _play_start_zoom_sequence() -> void:
	if _start_zoom_tween != null:
		_start_zoom_tween.kill()

	size = _get_zoom_out_limit()
	_target_xz = _world_to_xz(_get_full_map_position())
	_clamp_target()
	_apply_camera_transform()

	var target_size := _get_initial_zoom_target()
	var start_world_position := _get_start_focus_position()
	var start_size := size
	var start_xz := _target_xz

	_start_zoom_tween = create_tween()
	_start_zoom_tween.set_trans(Tween.TRANS_SINE)
	_start_zoom_tween.set_ease(Tween.EASE_IN_OUT)
	if start_zoom_hold_duration > 0.0:
		_start_zoom_tween.tween_interval(start_zoom_hold_duration)
	_start_zoom_tween.tween_method(func(value: float) -> void:
		size = lerpf(start_size, target_size, value)
		var target_xz := _get_clamped_target_for_world_position(start_world_position, size)
		_target_xz = start_xz.lerp(target_xz, value)
		_clamp_target()
		_apply_camera_transform()
	, 0.0, 1.0, start_zoom_duration)


func _on_player_move_started(_target_position: Vector2i) -> void:
	_following_player = true
	if _start_zoom_tween != null:
		_start_zoom_tween.kill()
		_start_zoom_tween = null
	if _move_focus_tween != null:
		_move_focus_tween.kill()
		_move_focus_tween = null
	_follow_player_position()


func _on_player_moved(grid_position: Vector2i) -> void:
	_following_player = false
	_focus_on_grid_position(grid_position)


func _follow_player_position() -> void:
	if _map == null or _player == null:
		return
	_target_xz = _get_clamped_target_for_world_position(_player.global_position)
	_apply_camera_transform()


func _focus_on_grid_position(grid_position: Vector2i) -> void:
	if _map == null:
		return
	if _move_focus_tween != null:
		_move_focus_tween.kill()

	var target_xz := _get_clamped_target_for_world_position(_map.grid_to_world(grid_position))
	if move_focus_duration <= 0.0:
		_target_xz = target_xz
		_apply_camera_transform()
		return

	var start_xz := _target_xz
	_move_focus_tween = create_tween()
	_move_focus_tween.set_trans(Tween.TRANS_SINE)
	_move_focus_tween.set_ease(Tween.EASE_OUT)
	_move_focus_tween.tween_method(func(value: float) -> void:
		_target_xz = start_xz.lerp(target_xz, value)
		_clamp_target()
		_apply_camera_transform()
	, 0.0, 1.0, move_focus_duration)


func _get_clamped_target_for_world_position(world_position: Vector3, camera_size := -1.0) -> Vector2:
	var size_for_clamp := size if camera_size <= 0.0 else camera_size
	return _clamp_xz_for_size(_world_to_xz(world_position), size_for_clamp)


func _clamp_xz_for_size(target_xz: Vector2, camera_size: float) -> Vector2:
	if _map == null:
		return target_xz
	var boundary_rect := _get_camera_boundary_rect()
	var visible_ground_size := _get_visible_ground_size_for_size(camera_size)
	var half_visible := visible_ground_size * 0.5
	var clamped := target_xz

	if visible_ground_size.x >= boundary_rect.size.x:
		clamped.x = boundary_rect.get_center().x
	else:
		clamped.x = clampf(target_xz.x, boundary_rect.position.x + half_visible.x, boundary_rect.end.x - half_visible.x)

	if visible_ground_size.y >= boundary_rect.size.y:
		clamped.y = boundary_rect.get_center().y
	else:
		clamped.y = clampf(target_xz.y, boundary_rect.position.y + half_visible.y, boundary_rect.end.y - half_visible.y)

	return clamped


func _get_start_focus_position() -> Vector3:
	if _map == null:
		return Vector3.ZERO
	return _map.grid_to_world(_map.get_start_position())


func _screen_to_ground(screen_position: Vector2) -> Vector3:
	var origin := project_ray_origin(screen_position)
	var direction := project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return Vector3.INF
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return Vector3.INF
	return origin + direction * distance


func _world_to_xz(world_position: Vector3) -> Vector2:
	return Vector2(world_position.x, world_position.z)


func _get_map_viewport_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	viewport_size.y = maxf(1.0, viewport_size.y - _get_reserved_bottom_height())
	return viewport_size


func _get_reserved_bottom_height() -> float:
	if _reserved_bottom_control == null:
		return 0.0
	return maxf(0.0, _reserved_bottom_control.size.y)


func _is_in_map_screen_area(screen_position: Vector2) -> bool:
	return screen_position.y < _get_map_viewport_size().y
