class_name EventActivationFX
extends Control

const CARD_SCENE := preload("res://ui/card.tscn")
const CARD_SIZE := Vector2(174.0, 250.0)

@export var deck_controller_path: NodePath

var _card: CardView
var _label: Label
var _active_tween: Tween
var _pulse_radius := 90.0:
	set(value):
		_pulse_radius = value
		queue_redraw()
var _pulse_alpha := 0.0:
	set(value):
		_pulse_alpha = value
		queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card = CARD_SCENE.instantiate() as CardView
	_card.custom_minimum_size = CARD_SIZE
	_card.size = CARD_SIZE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 21)
	_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.76))
	_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.01, 0.96))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	var deck_controller := get_node_or_null(deck_controller_path) as DeckController
	if deck_controller != null:
		deck_controller.event_card_activated.connect(play)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _card != null:
		_layout_effect()


func _draw() -> void:
	if visible and _pulse_alpha > 0.0:
		draw_circle(size * 0.5, _pulse_radius, Color(1.0, 0.73, 0.20, _pulse_alpha))


func play(card_data: Dictionary) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_card.configure(card_data)
	_label.text = str(card_data.get("detail", ""))
	visible = true
	_layout_effect()
	modulate = Color.WHITE
	_card.scale = Vector2(0.68, 0.68)
	_card.rotation = deg_to_rad(-4.0)
	_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_pulse_radius = 90.0
	_pulse_alpha = 0.18
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_card, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_card, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_label, "modulate:a", 1.0, 0.13).set_delay(0.08)
	_active_tween.tween_property(self, "_pulse_radius", 165.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "_pulse_alpha", 0.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.chain().tween_property(_card, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD)
	_active_tween.chain().tween_interval(1.15)
	_active_tween.chain().tween_property(self, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.chain().tween_callback(_finish)


func _layout_effect() -> void:
	var center := size * 0.5
	_card.position = center - CARD_SIZE * 0.5
	_card.pivot_offset = CARD_SIZE * 0.5
	var text_width := minf(size.x - 48.0, 420.0)
	_label.position = Vector2((size.x - text_width) * 0.5, center.y + CARD_SIZE.y * 0.5 + 10.0)
	_label.size = Vector2(text_width, 62.0)


func _finish() -> void:
	visible = false
	modulate = Color.WHITE
