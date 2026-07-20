class_name SafeArea
extends RefCounted

static var _test_insets := Vector4(-1.0, -1.0, -1.0, -1.0)


static func set_test_insets(insets: Vector4) -> void:
	_test_insets = insets


static func clear_test_insets() -> void:
	_test_insets = Vector4(-1.0, -1.0, -1.0, -1.0)


static func get_insets(viewport_size: Vector2) -> Vector4:
	if _test_insets.x >= 0.0:
		return _test_insets
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO

	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return Vector4.ZERO

	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return Vector4.ZERO

	var scale := Vector2(viewport_size.x / float(screen_size.x), viewport_size.y / float(screen_size.y))
	var left := float(safe_area.position.x) * scale.x
	var top := float(safe_area.position.y) * scale.y
	var right := float(screen_size.x - (safe_area.position.x + safe_area.size.x)) * scale.x
	var bottom := float(screen_size.y - (safe_area.position.y + safe_area.size.y)) * scale.y
	return Vector4(
		maxf(0.0, left),
		maxf(0.0, top),
		maxf(0.0, right),
		maxf(0.0, bottom)
	)
