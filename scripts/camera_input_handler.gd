## Handles touch and mouse gesture input state for the map camera.
## Extracts input tracking from the camera to keep it focused on viewport logic.
class_name CameraInputHandler
extends RefCounted

signal zoom_requested(target_size_factor: float, screen_anchor: Vector2)
signal pan_requested(screen_delta: Vector2)

var mouse_pan_threshold := 4.0

var _touch_points: Dictionary = {}
var _last_pinch_distance := 0.0
var _last_pinch_center := Vector2.ZERO
var _mouse_pan_button := MOUSE_BUTTON_NONE
var _mouse_pan_start_position := Vector2.ZERO
var _mouse_pan_dragging := false


func handle_scroll_zoom(event: InputEvent, is_in_map_area: Callable, current_size: float, zoom_step: float) -> bool:
	if not (event is InputEventMouseButton) or not event.pressed:
		return false
	if not is_in_map_area.call(event.position):
		return false

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_requested.emit(current_size * (1.0 - zoom_step), event.position)
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_requested.emit(current_size * (1.0 + zoom_step), event.position)
		return true
	return false


func handle_trackpad_zoom(event: InputEvent, current_size: float, mouse_position: Vector2) -> bool:
	if not (event is InputEventMagnifyGesture):
		return false
	zoom_requested.emit(current_size / maxf(event.factor, 0.01), mouse_position)
	return true


func handle_trackpad_pan(event: InputEvent) -> bool:
	if not (event is InputEventPanGesture):
		return false
	pan_requested.emit(event.delta)
	return true


func handle_mouse_pan(event: InputEvent, is_in_map_area: Callable) -> bool:
	if event is InputEventMouseButton:
		if not _is_pan_mouse_button(event.button_index):
			return false
		if event.pressed:
			if not is_in_map_area.call(event.position):
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
		pan_requested.emit(event.relative)
		return true

	return false


func handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
	else:
		_touch_points.erase(event.index)

	if _touch_points.size() == 2:
		_last_pinch_center = _get_touch_center()
		_last_pinch_distance = _get_touch_distance()
	else:
		_last_pinch_distance = 0.0


func reset_touch_gesture() -> void:
	_touch_points.clear()
	_last_pinch_distance = 0.0
	_last_pinch_center = Vector2.ZERO


func handle_screen_drag(event: InputEventScreenDrag, current_size: float) -> void:
	if not _touch_points.has(event.index):
		return

	_touch_points[event.index] = event.position
	if _touch_points.size() != 2:
		return

	var center := _get_touch_center()
	var distance := _get_touch_distance()
	pan_requested.emit(_last_pinch_center - center)

	if _last_pinch_distance > 0.0 and distance > 0.0:
		zoom_requested.emit(current_size * _last_pinch_distance / distance, center)

	_last_pinch_center = center
	_last_pinch_distance = distance


func _get_touch_center() -> Vector2:
	var points: Array = _touch_points.values()
	return (points[0] as Vector2 + points[1] as Vector2) * 0.5


func _get_touch_distance() -> float:
	var points: Array = _touch_points.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


static func _is_pan_mouse_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_RIGHT or button_index == MOUSE_BUTTON_MIDDLE


static func _get_mouse_button_mask(button_index: int) -> int:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return MOUSE_BUTTON_MASK_LEFT
		MOUSE_BUTTON_RIGHT:
			return MOUSE_BUTTON_MASK_RIGHT
		MOUSE_BUTTON_MIDDLE:
			return MOUSE_BUTTON_MASK_MIDDLE
		_:
			return 0
