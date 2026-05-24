extends Camera2D

@export var map_path: NodePath
@export var zoom_in_limit := 2.0
@export var zoom_step := 0.1

var _map: Node
var _touch_points: Dictionary = {}
var _last_pinch_distance := 0.0
var _last_pinch_center := Vector2.ZERO


func _ready() -> void:
	_map = get_node_or_null(map_path)
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	get_viewport().size_changed.connect(_refresh_limits)
	_refresh_limits()
	if _map != null:
		position = _map.get_padded_world_rect().get_center()
		zoom = Vector2.ONE * _get_zoom_out_limit()
		_clamp_position()

func _unhandled_input(event: InputEvent) -> void:
	if _map == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(zoom.x + zoom_step, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(zoom.x - zoom_step, get_global_mouse_position())
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		position -= event.relative / zoom
		_clamp_position()
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


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
	zoom = Vector2.ONE * clampf(zoom.x, _get_zoom_out_limit(), zoom_in_limit)
	_clamp_position()


func _apply_zoom(target_zoom: float, world_anchor: Vector2) -> void:
	var previous_zoom: float = zoom.x
	var next_zoom: float = clampf(target_zoom, _get_zoom_out_limit(), zoom_in_limit)
	if is_equal_approx(previous_zoom, next_zoom):
		return

	zoom = Vector2.ONE * next_zoom
	position = world_anchor + (position - world_anchor) * previous_zoom / next_zoom
	_clamp_position()


func _clamp_position() -> void:
	if _map == null:
		return

	var padded_rect: Rect2 = _map.get_padded_world_rect()
	var visible_size: Vector2 = get_viewport_rect().size / zoom
	var half_visible_size: Vector2 = visible_size * 0.5
	var min_position: Vector2 = padded_rect.position + half_visible_size
	var max_position: Vector2 = padded_rect.end - half_visible_size

	if min_position.x > max_position.x:
		position.x = padded_rect.get_center().x
	else:
		position.x = clampf(position.x, min_position.x, max_position.x)

	if min_position.y > max_position.y:
		position.y = padded_rect.get_center().y
	else:
		position.y = clampf(position.y, min_position.y, max_position.y)


func _get_zoom_out_limit() -> float:
	if _map == null:
		return 1.0

	var viewport_size: Vector2 = get_viewport_rect().size
	var padded_size: Vector2 = _map.get_padded_world_rect().size
	return minf(viewport_size.x / padded_size.x, viewport_size.y / padded_size.y)


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
