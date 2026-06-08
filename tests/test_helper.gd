## Shared test utilities for headless GDScript tests.
## Usage: const TestHelper = preload("res://tests/test_helper.gd")
##        then call TestHelper.assert_true(condition, message)
class_name TestHelper
extends RefCounted


static func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		var context := message if not message.is_empty() else "Assertion failed"
		push_error("ASSERT FAILED: %s" % context)
		_get_tree().quit(1)


static func assert_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		var context := message if not message.is_empty() else "Values not equal"
		push_error("ASSERT FAILED: %s — expected: %s, got: %s" % [context, str(expected), str(actual)])
		_get_tree().quit(1)


static func assert_not_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		var context := message if not message.is_empty() else "Values should differ"
		push_error("ASSERT FAILED: %s — both are: %s" % [context, str(actual)])
		_get_tree().quit(1)


static func assert_greater(actual: Variant, threshold: Variant, message: String = "") -> void:
	if not (actual > threshold):
		var context := message if not message.is_empty() else "Value not greater"
		push_error("ASSERT FAILED: %s — %s is not > %s" % [context, str(actual), str(threshold)])
		_get_tree().quit(1)


static func assert_less(actual: Variant, threshold: Variant, message: String = "") -> void:
	if not (actual < threshold):
		var context := message if not message.is_empty() else "Value not less"
		push_error("ASSERT FAILED: %s — %s is not < %s" % [context, str(actual), str(threshold)])
		_get_tree().quit(1)


static func assert_in_range(actual: float, min_val: float, max_val: float, message: String = "") -> void:
	if actual < min_val or actual > max_val:
		var context := message if not message.is_empty() else "Value out of range"
		push_error("ASSERT FAILED: %s — %s not in [%s, %s]" % [context, str(actual), str(min_val), str(max_val)])
		_get_tree().quit(1)


static func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		var context := message if not message.is_empty() else "Value is null"
		push_error("ASSERT FAILED: %s" % context)
		_get_tree().quit(1)


static func assert_empty(value: Variant, message: String = "") -> void:
	var is_empty := false
	if value is Array or value is Dictionary or value is String:
		is_empty = value.is_empty()
	elif value == null:
		is_empty = true
	if not is_empty:
		var context := message if not message.is_empty() else "Value should be empty"
		push_error("ASSERT FAILED: %s — got: %s" % [context, str(value)])
		_get_tree().quit(1)


static func assert_not_empty(value: Variant, message: String = "") -> void:
	var is_empty := true
	if value is Array or value is Dictionary or value is String:
		is_empty = value.is_empty()
	elif value != null:
		is_empty = false
	if is_empty:
		var context := message if not message.is_empty() else "Value should not be empty"
		push_error("ASSERT FAILED: %s" % context)
		_get_tree().quit(1)


static func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
