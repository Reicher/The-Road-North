extends SceneTree


func _initialize() -> void:
	var handler := CameraInputHandler.new()
	var zoom_requests: Array = []
	var pan_requests: Array = []
	handler.zoom_requested.connect(func(target_size: float, anchor: Vector2) -> void:
		zoom_requests.append([target_size, anchor])
	)
	handler.pan_requested.connect(func(delta: Vector2) -> void:
		pan_requests.append(delta)
	)

	handler.handle_screen_touch(_touch(0, Vector2(100.0, 200.0), true))
	handler.handle_screen_touch(_touch(1, Vector2(200.0, 200.0), true))
	handler.handle_screen_drag(_drag(1, Vector2(220.0, 200.0)), 600.0)

	_assert(zoom_requests.size() == 1, "Expected the first two-finger drag to zoom without an ignored setup step")
	_assert(is_equal_approx(float(zoom_requests[0][0]), 500.0), "Expected pinch zoom to use the initial finger distance")
	_assert((zoom_requests[0][1] as Vector2).is_equal_approx(Vector2(160.0, 200.0)), "Expected pinch zoom to stay anchored between the fingers")
	_assert(pan_requests.size() == 1 and (pan_requests[0] as Vector2).is_equal_approx(Vector2(-10.0, 0.0)), "Expected two-finger movement to pan by the center delta")

	handler.reset_touch_gesture()
	handler.handle_screen_drag(_drag(1, Vector2(240.0, 200.0)), 600.0)
	_assert(zoom_requests.size() == 1, "Expected reset touch state to ignore stale drag events")
	_assert(pan_requests.size() == 1, "Expected reset touch state to prevent stale panning")

	handler.handle_screen_touch(_touch(0, Vector2(120.0, 220.0), true))
	handler.handle_screen_drag(_drag(0, Vector2(140.0, 220.0)), 600.0)
	_assert(zoom_requests.size() == 1 and pan_requests.size() == 1, "Expected one-finger drags not to move the camera")

	quit()


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
