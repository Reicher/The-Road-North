extends Camera3D

@export var map_path: NodePath
@export var player_path: NodePath
@export var reserved_bottom_path: NodePath
@export var initial_visible_tile_width := 5.0
@export var zoom_in_visible_tile_width := 3.0
@export_range(0.0, 10.0, 0.1) var start_zoom_hold_duration := 2.0
@export_range(0.0, 5.0, 0.05) var start_zoom_duration := 0.85
@export_range(0.0, 2.0, 0.01) var move_focus_duration := 0.18
@export var zoom_step := 0.10
@export var mouse_pan_threshold := 4.0
@export_range(20.0, 80.0, 1.0) var camera_angle_degrees := 55.0
@export_range(0.0, 3.0, 0.05) var pan_margin_x_tiles := 0.0
@export_range(0.0, 3.0, 0.05) var pan_margin_z_tiles := 0.0

var _map: GameMap
var _player: Node3D
var _reserved_bottom_control: Control
var _touch_points: Dictionary = {}
var _last_pinch_distance := 0.0
var _last_pinch_center := Vector2.ZERO
var _target_xz := Vector2.ZERO
var _start_zoom_tween: Tween
var _move_focus_tween: Tween
var _mouse_pan_button := MOUSE_BUTTON_NONE
var _mouse_pan_start_position := Vector2.ZERO
var _mouse_pan_dragging := false


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_player = get_node_or_null(player_path) as Node3D
	_reserved_bottom_control = get_node_or_null(reserved_bottom_path) as Control
	projection = Camera3D.PROJECTION_ORTHOGONAL
	current = true
	get_viewport().size_changed.connect(_refresh_limits)
	if _reserved_bottom_control != null:
		_reserved_bottom_control.resized.connect(_refresh_limits)
	var moved_callback := Callable(self, "_on_player_moved")
	if _player != null and _player.has_signal("moved") and not _player.is_connected("moved", moved_callback):
		_player.connect("moved", moved_callback)
	if _map != null:
		size = _get_zoom_out_limit()
		_target_xz = _world_to_xz(_get_full_map_position())
		_clamp_target()
		_apply_camera_transform()
		call_deferred("_play_start_zoom_sequence")


func _exit_tree() -> void:
	if _start_zoom_tween != null:
		_start_zoom_tween.kill()
		_start_zoom_tween = null
	if _move_focus_tween != null:
		_move_focus_tween.kill()
		_move_focus_tween = null


func _input(event: InputEvent) -> void:
	if _handle_scroll_zoom(event):
		get_viewport().set_input_as_handled()
	elif _handle_mouse_pan(event):
		get_viewport().set_input_as_handled()
	elif _handle_trackpad_zoom(event):
		get_viewport().set_input_as_handled()
	elif _handle_trackpad_pan(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _map == null:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_scroll_zoom(event: InputEvent) -> bool:
	if _map == null or not (event is InputEventMouseButton) or not event.pressed:
		return false
	if not _is_in_map_screen_area(event.position):
		return false

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_apply_zoom(size * (1.0 - zoom_step), event.position)
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_apply_zoom(size * (1.0 + zoom_step), event.position)
		return true
	return false


func _handle_trackpad_zoom(event: InputEvent) -> bool:
	if _map == null or not (event is InputEventMagnifyGesture):
		return false
	_apply_zoom(size / maxf(event.factor, 0.01), get_viewport().get_mouse_position())
	return true


func _handle_trackpad_pan(event: InputEvent) -> bool:
	if _map == null or not (event is InputEventPanGesture):
		return false
	_pan_by_screen_delta(event.delta)
	return true


func _handle_mouse_pan(event: InputEvent) -> bool:
	if _map == null:
		return false

	if event is InputEventMouseButton:
		if not _is_pan_mouse_button(event.button_index):
			return false
		if event.pressed:
			if not _is_in_map_screen_area(event.position):
				return false
			_mouse_pan_button = event.button_index
			_mouse_pan_start_position = event.position
			_mouse_pan_dragging = false
			return false
		if event.button_index == _mouse_pan_button:
			var was_dragging := _mouse_pan_dragging
			_mouse_pan_button = MOUSE_BUTTON_NONE
			_mouse_pan_dragging = false
			return was_dragging
		return false

	if event is InputEventMouseMotion and _mouse_pan_button != MOUSE_BUTTON_NONE:
		var button_mask := _get_mouse_button_mask(_mouse_pan_button)
		if (event.button_mask & button_mask) == 0:
			_mouse_pan_button = MOUSE_BUTTON_NONE
			_mouse_pan_dragging = false
			return false
		if not _mouse_pan_dragging:
			if _mouse_pan_start_position.distance_to(event.position) < mouse_pan_threshold:
				return false
			_mouse_pan_dragging = true
		_pan_by_screen_delta(event.relative)
		return true

	return false


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
	else:
		_touch_points.erase(event.index)

	_last_pinch_distance = 0.0
	if _touch_points.size() == 2:
		_last_pinch_center = _get_touch_center()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _touch_points.has(event.index):
		return

	_touch_points[event.index] = event.position
	if _touch_points.size() != 2:
		return

	var center: Vector2 = _get_touch_center()
	var distance: float = _get_touch_distance()
	_pan_by_screen_delta(_last_pinch_center - center)

	if _last_pinch_distance > 0.0 and distance > 0.0:
		_apply_zoom(size * _last_pinch_distance / distance, center)

	_last_pinch_center = center
	_last_pinch_distance = distance


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
	var wanted_size := _map.tile_size * initial_visible_tile_width / maxf(aspect, 0.01)
	return clampf(wanted_size, _get_zoom_in_limit(), _get_zoom_out_limit())


func _get_camera_boundary_rect() -> Rect2:
	var map_rect := _map.get_padded_world_rect()
	var margin := Vector2(_map.tile_size * pan_margin_x_tiles, _map.tile_size * pan_margin_z_tiles)
	return Rect2(map_rect.position - margin, map_rect.size + margin * 2.0)


func _get_ground_size_for_vertical_map_span(map_depth: float) -> float:
	var angle := deg_to_rad(camera_angle_degrees)
	return map_depth * maxf(sin(angle), 0.25)


func _get_visible_ground_size() -> Vector2:
	return _get_visible_ground_size_for_size(size)


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


func _get_player_tile_position() -> Vector3:
	if _map == null:
		return Vector3.ZERO
	if _player != null:
		var player_grid_position: Variant = _player.get("grid_position")
		if player_grid_position is Vector2i:
			return _map.grid_to_world(player_grid_position)
		return _player.global_position
	return _map.grid_to_world(_map.get_start_position())


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


func _on_player_moved(grid_position: Vector2i) -> void:
	_focus_on_grid_position(grid_position)


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


func _get_touch_center() -> Vector2:
	var points: Array = _touch_points.values()
	var first_point: Vector2 = points[0]
	var second_point: Vector2 = points[1]
	return (first_point + second_point) * 0.5


func _get_touch_distance() -> float:
	var points: Array = _touch_points.values()
	var first_point: Vector2 = points[0]
	var second_point: Vector2 = points[1]
	return first_point.distance_to(second_point)


func _is_pan_mouse_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_RIGHT or button_index == MOUSE_BUTTON_MIDDLE


func _get_mouse_button_mask(button_index: int) -> int:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return MOUSE_BUTTON_MASK_LEFT
		MOUSE_BUTTON_RIGHT:
			return MOUSE_BUTTON_MASK_RIGHT
		MOUSE_BUTTON_MIDDLE:
			return MOUSE_BUTTON_MASK_MIDDLE
		_:
			return 0
