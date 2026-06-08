## Shared UI utility functions used by inventory and loot panels.
class_name UIUtils
extends RefCounted


static func event_canvas_position(event: InputEvent, source_button: Button) -> Vector2:
	if source_button == null:
		return Vector2.ZERO
	if event is InputEventMouse:
		return source_button.get_global_position() + event.position
	return source_button.get_global_rect().get_center()


static func mark_input_handled(control: Control) -> void:
	var viewport := control.get_viewport() if control.is_inside_tree() else null
	if viewport != null:
		viewport.set_input_as_handled()
