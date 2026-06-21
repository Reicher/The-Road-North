class_name StatRow
extends HBoxContainer

const ICON_PATHS := GameConstants.STAT_ICON_PATHS

@export var stat_name := "food":
	set(value):
		stat_name = value
		_load_icon()

@export var icon_size := 54.0:
	set(value):
		icon_size = value
		if _icon != null:
			_icon.custom_minimum_size = Vector2(icon_size, icon_size)
			queue_redraw()

@export var gain_pulse_duration := 2.0
@export var low_warning_threshold := 0

var _pulse_strength := 0.0
var _pulse_sign := 1
var _gain_amount := 0
var _pulse_tween: Tween
var _low_blink_tween: Tween
var _low_blink_strength := 0.0
var _icon: TextureRect
var _value_label: Label
var _gain_label: Label


func _ready() -> void:
	_icon = $Icon as TextureRect
	_value_label = $Value as Label
	_gain_label = $Gain as Label
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_load_icon()


func _draw() -> void:
	if _pulse_strength <= 0.0 or _icon == null:
		return
	var icon_center := _icon.position + _icon.size * 0.5
	var glow_color := _get_glow_color()
	glow_color.a = 0.22 + _pulse_strength * 0.46
	draw_circle(icon_center, icon_size * (0.48 + _pulse_strength * 0.16), glow_color)
	draw_arc(icon_center, icon_size * (0.64 + _pulse_strength * 0.15), 0.0, TAU, 28, glow_color.lightened(0.20), maxf(2.0, 5.0 * _pulse_strength))


func set_display_value(value: Variant) -> void:
	if _value_label != null:
		_value_label.text = str(value)


func trigger_pulse(change: int) -> void:
	var is_same_sign := signi(_gain_amount) == signi(change) and _pulse_strength > 0.0
	_pulse_strength = 1.0
	_pulse_sign = 1 if change > 0 else -1
	_gain_amount = _gain_amount + change if is_same_sign else change

	if _gain_label != null:
		_gain_label.text = "%+d" % _gain_amount
		_gain_label.add_theme_color_override("font_color", _get_glow_color())
		_gain_label.visible = true

	_update_value_color()

	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, gain_pulse_duration)
	_pulse_tween.finished.connect(_finish_pulse)
	queue_redraw()


func sync_without_feedback() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_pulse_strength = 0.0
	_gain_amount = 0
	if _gain_label != null:
		_gain_label.visible = false
	_update_value_color()
	queue_redraw()


func _set_pulse(value: float) -> void:
	_pulse_strength = value
	_update_value_color()
	if _gain_label != null:
		_gain_label.modulate.a = value
	queue_redraw()


func _finish_pulse() -> void:
	_pulse_strength = 0.0
	_gain_amount = 0
	_pulse_tween = null
	if _gain_label != null:
		_gain_label.visible = false
	_update_value_color()
	queue_redraw()


func _update_value_color() -> void:
	if _value_label == null:
		return
	var base_color := Color(0.20, 0.14, 0.09)
	var low_red := Color(0.78, 0.08, 0.06)
	if _pulse_strength > 0.0:
		_value_label.add_theme_color_override("font_color", base_color.lerp(_get_glow_color(), 0.86 * _pulse_strength))
	elif _low_blink_strength > 0.0:
		_value_label.add_theme_color_override("font_color", base_color.lerp(low_red, _low_blink_strength))
	else:
		_value_label.add_theme_color_override("font_color", base_color)
	if _icon != null:
		if _pulse_strength > 0.0:
			_icon.modulate = Color.WHITE.lerp(_get_glow_color(), 0.62 * _pulse_strength)
		elif _low_blink_strength > 0.0:
			_icon.modulate = Color.WHITE.lerp(low_red, 0.5 * _low_blink_strength)
		else:
			_icon.modulate = Color.WHITE


func _get_glow_color() -> Color:
	if _pulse_sign < 0:
		return Color(0.84, 0.12, 0.08)
	return Color(0.08, 0.52, 0.18)


func check_low_warning(value: int) -> void:
	if low_warning_threshold > 0 and value < low_warning_threshold and value > 0:
		_start_low_blink()
	else:
		_stop_low_blink()


func _start_low_blink() -> void:
	if _low_blink_tween != null:
		return
	_low_blink_tween = create_tween()
	_low_blink_tween.set_loops()
	_low_blink_tween.tween_method(_set_low_blink, 0.0, 1.0, 0.5)
	_low_blink_tween.tween_method(_set_low_blink, 1.0, 0.0, 0.5)


func _stop_low_blink() -> void:
	if _low_blink_tween != null:
		_low_blink_tween.kill()
		_low_blink_tween = null
	_low_blink_strength = 0.0
	_update_value_color()


func _set_low_blink(value: float) -> void:
	_low_blink_strength = value
	_update_value_color()


func _load_icon() -> void:
	if _icon == null:
		return
	var path := str(ICON_PATHS.get(stat_name, ""))
	if path.is_empty():
		_icon.texture = null
	else:
		_icon.texture = load(path) as Texture2D
