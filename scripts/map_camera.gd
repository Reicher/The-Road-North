extends Camera2D

@export var map_path: NodePath
@export var player_path: NodePath
@export var reserved_bottom_path: NodePath
@export var initial_visible_tile_width := 5.0
@export var zoom_in_visible_tile_width := 3.0
@export_range(0.0, 10.0, 0.1) var start_zoom_hold_duration := 2.0
@export_range(0.0, 5.0, 0.05) var start_zoom_duration := 0.85
@export_range(0.0, 2.0, 0.01) var move_focus_duration := 0.18
@export var zoom_step := 0.1

var _map: Node
var _player: Node2D
var _reserved_bottom_control: Control
var _touch_points: Dictionary = {}
var _last_pinch_distance := 0.0
var _last_pinch_center := Vector2.ZERO
var _start_zoom_tween: Tween
var _move_focus_tween: Tween


func _ready() -> void:
	_map = get_node_or_null(map_path)
	_player = get_node_or_null(player_path) as Node2D
	_reserved_bottom_control = get_node_or_null(reserved_bottom_path) as Control
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	get_viewport().size_changed.connect(_refresh_limits)
	if _reserved_bottom_control != null:
		_reserved_bottom_control.resized.connect(_refresh_limits)
	var moved_callback := Callable(self, "_on_player_moved")
	if _player != null and _player.has_signal("moved") and not _player.is_connected("moved", moved_callback):
		_player.connect("moved", moved_callback)
	if _map != null:
		zoom = Vector2.ONE * _get_zoom_out_limit()
		position = _get_full_map_position()
		_clamp_position()
		_play_start_zoom_sequence()


func _input(event: InputEvent) -> void:
	if _handle_scroll_zoom(event):
		get_viewport().set_input_as_handled()
	elif _handle_trackpad_zoom(event):
		get_viewport().set_input_as_handled()
	elif _handle_trackpad_pan(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _map == null:
		return

	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		position -= event.relative / zoom
		_clamp_position()
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_scroll_zoom(event: InputEvent) -> bool:
	if _map == null or not (event is InputEventMouseButton) or not event.pressed:
		return false
	if not _is_in_map_screen_area(event.position):
		return false

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_apply_zoom(zoom.x + zoom_step, get_global_mouse_position())
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_apply_zoom(zoom.x - zoom_step, get_global_mouse_position())
		return true

	return false


func _handle_trackpad_zoom(event: InputEvent) -> bool:
	if _map == null or not (event is InputEventMagnifyGesture):
		return false

	_apply_zoom(zoom.x * event.factor, get_global_mouse_position())
	return true


func _handle_trackpad_pan(event: InputEvent) -> bool:
	if _map == null or not (event is InputEventPanGesture):
		return false

	position -= event.delta / zoom
	_clamp_position()
	return true


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
	position -= (center - _last_pinch_center) / zoom

	if _last_pinch_distance > 0.0 and distance > 0.0:
		_apply_zoom(zoom.x * distance / _last_pinch_distance, get_screen_center_position())

	_last_pinch_center = center
	_last_pinch_distance = distance
	_clamp_position()


func _refresh_limits() -> void:
	if _map == null:
		return

	var padded_rect: Rect2 = _map.get_padded_world_rect()
	limit_left = floori(padded_rect.position.x)
	limit_top = floori(padded_rect.position.y)
	limit_right = ceili(padded_rect.end.x)
	limit_bottom = ceili(padded_rect.end.y)
	zoom = Vector2.ONE * clampf(zoom.x, _get_zoom_out_limit(), _get_zoom_in_limit())
	_clamp_position()


func _apply_zoom(target_zoom: float, world_anchor: Vector2) -> void:
	var previous_zoom: float = zoom.x
	var next_zoom: float = clampf(target_zoom, _get_zoom_out_limit(), _get_zoom_in_limit())
	if is_equal_approx(previous_zoom, next_zoom):
		return

	zoom = Vector2.ONE * next_zoom
	position = world_anchor + (position - world_anchor) * previous_zoom / next_zoom
	_clamp_position()


func _clamp_position() -> void:
	if _map == null:
		return

	var padded_rect: Rect2 = _map.get_padded_world_rect()
	var visible_size: Vector2 = _get_map_viewport_size() / zoom
	var half_visible_size: Vector2 = visible_size * 0.5
	var min_position: Vector2 = padded_rect.position + half_visible_size
	var max_position: Vector2 = padded_rect.end - half_visible_size
	var map_area_center := position - _get_map_area_center_offset()

	if min_position.x > max_position.x:
		map_area_center.x = padded_rect.get_center().x
	else:
		map_area_center.x = clampf(map_area_center.x, min_position.x, max_position.x)

	if min_position.y > max_position.y:
		map_area_center.y = padded_rect.get_center().y
	else:
		map_area_center.y = clampf(map_area_center.y, min_position.y, max_position.y)

	position = map_area_center + _get_map_area_center_offset()


func _get_zoom_out_limit() -> float:
	if _map == null:
		return 1.0

	var viewport_size: Vector2 = _get_map_viewport_size()
	var padded_size: Vector2 = _map.get_padded_world_rect().size
	return maxf(viewport_size.x / padded_size.x, viewport_size.y / padded_size.y)


func _get_zoom_in_limit() -> float:
	return maxf(_get_zoom_for_visible_tile_width(zoom_in_visible_tile_width), _get_zoom_out_limit())


func _get_initial_zoom_target() -> float:
	return _get_zoom_for_visible_tile_width(initial_visible_tile_width)


func _get_zoom_for_visible_tile_width(visible_tile_width: float) -> float:
	if _map == null:
		return 1.0

	var viewport_width: float = _get_map_viewport_size().x
	var tile_width: float = maxf(_map.tile_size * maxf(visible_tile_width, 1.0), 1.0)
	return viewport_width / tile_width


func _get_full_map_position() -> Vector2:
	if _map == null:
		return Vector2.ZERO

	return _map.get_padded_world_rect().get_center() + _get_map_area_center_offset()


func _get_player_tile_position() -> Vector2:
	if _map == null:
		return Vector2.ZERO
	if _player != null:
		var player_grid_position: Variant = _player.get("grid_position")
		if player_grid_position is Vector2i:
			return _map.grid_to_world(player_grid_position)
		return _player.global_position
	if _map.has_method("get_start_position"):
		return _map.grid_to_world(_map.get_start_position())
	return _map.get_padded_world_rect().get_center()


func _play_start_zoom_sequence() -> void:
	if _start_zoom_tween != null:
		_start_zoom_tween.kill()

	zoom = Vector2.ONE * _get_zoom_out_limit()
	position = _get_full_map_position()
	_clamp_position()

	await get_tree().create_timer(start_zoom_hold_duration).timeout
	if _map == null or not is_inside_tree():
		return

	zoom = Vector2.ONE * _get_zoom_in_limit()
	position = _get_player_tile_position()
	_clamp_position()
	var target_zoom := zoom
	var target_position := position

	zoom = Vector2.ONE * _get_zoom_out_limit()
	position = _get_full_map_position()
	_clamp_position()

	_start_zoom_tween = create_tween()
	_start_zoom_tween.set_trans(Tween.TRANS_SINE)
	_start_zoom_tween.set_ease(Tween.EASE_IN_OUT)
	_start_zoom_tween.set_parallel(true)
	_start_zoom_tween.tween_property(self, "zoom", target_zoom, start_zoom_duration)
	_start_zoom_tween.tween_property(self, "position", target_position, start_zoom_duration)
	_start_zoom_tween.chain().tween_callback(_clamp_position)


func _on_player_moved(grid_position: Vector2i) -> void:
	_focus_on_grid_position(grid_position)


func _focus_on_grid_position(grid_position: Vector2i) -> void:
	if _map == null:
		return
	if _move_focus_tween != null:
		_move_focus_tween.kill()

	var target_position := _get_clamped_camera_position_for_world_position(_map.grid_to_world(grid_position))
	if move_focus_duration <= 0.0:
		position = target_position
		return

	_move_focus_tween = create_tween()
	_move_focus_tween.set_trans(Tween.TRANS_SINE)
	_move_focus_tween.set_ease(Tween.EASE_OUT)
	_move_focus_tween.tween_property(self, "position", target_position, move_focus_duration)
	_move_focus_tween.tween_callback(_clamp_position)


func _get_clamped_camera_position_for_world_position(world_position: Vector2) -> Vector2:
	var previous_position := position
	position = world_position
	_clamp_position()
	var clamped_position := position
	position = previous_position
	return clamped_position


func _get_map_viewport_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	viewport_size.y = maxf(1.0, viewport_size.y - _get_reserved_bottom_height())
	return viewport_size


func _get_reserved_bottom_height() -> float:
	if _reserved_bottom_control == null:
		return 0.0
	return maxf(0.0, _reserved_bottom_control.size.y)


func _get_map_area_center_offset() -> Vector2:
	return Vector2(0.0, _get_reserved_bottom_height() * 0.5 / maxf(zoom.x, 0.001))


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
