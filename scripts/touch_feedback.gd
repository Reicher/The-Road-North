class_name TouchFeedback
extends RefCounted

const PRESS_SCALE := Vector2(0.975, 0.975)
const RELEASE_SCALE := Vector2.ONE
const PRESS_OFFSET := Vector2(0.0, 3.0)
const PRESS_DURATION := 0.055
const RELEASE_DURATION := 0.12


static func apply_to_tree(root: Node) -> void:
	if root == null:
		return
	if root is Button:
		apply_to_button(root as Button)
	for child in root.get_children():
		apply_to_tree(child)


static func apply_to_button(button: Button) -> void:
	if button == null or button.has_meta("touch_feedback_bound"):
		return
	button.set_meta("touch_feedback_bound", true)
	button.pivot_offset = button.size * 0.5
	if not button.resized.is_connected(_on_control_resized.bind(button)):
		button.resized.connect(_on_control_resized.bind(button))
	if not button.button_down.is_connected(_press_control.bind(button)):
		button.button_down.connect(_press_control.bind(button))
	if not button.button_up.is_connected(_release_control.bind(button)):
		button.button_up.connect(_release_control.bind(button))
	if not button.pressed.is_connected(_release_control.bind(button)):
		button.pressed.connect(_release_control.bind(button))


static func press_control(control: Control) -> void:
	_press_control(control)


static func release_control(control: Control) -> void:
	_release_control(control)


static func _on_control_resized(control: Control) -> void:
	if control != null:
		control.pivot_offset = control.size * 0.5


static func _press_control(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	_animate_control(control, PRESS_SCALE, PRESS_OFFSET, PRESS_DURATION, Tween.TRANS_SINE, Tween.EASE_OUT)


static func _release_control(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	_animate_control(control, RELEASE_SCALE, Vector2.ZERO, RELEASE_DURATION, Tween.TRANS_BACK, Tween.EASE_OUT)


static func _animate_control(control: Control, target_scale: Vector2, target_position_offset: Vector2, duration: float, transition: Tween.TransitionType, easing: Tween.EaseType) -> void:
	var tween_meta: Variant = control.get_meta("touch_feedback_tween") if control.has_meta("touch_feedback_tween") else null
	if tween_meta is Tween and tween_meta.is_valid():
		tween_meta.kill()
	var base_position: Vector2 = control.get_meta("touch_feedback_base_position", control.position)
	if control.scale == Vector2.ONE and target_scale != Vector2.ONE:
		control.set_meta("touch_feedback_base_position", control.position)
		base_position = control.position
	var tween := control.create_tween()
	control.set_meta("touch_feedback_tween", tween)
	tween.set_parallel(true)
	tween.set_trans(transition)
	tween.set_ease(easing)
	tween.tween_property(control, "scale", target_scale, duration)
	tween.tween_property(control, "position", base_position + target_position_offset, duration)
	if target_scale == Vector2.ONE:
		tween.tween_callback(func() -> void:
			if control != null:
				control.remove_meta("touch_feedback_base_position")
		)
