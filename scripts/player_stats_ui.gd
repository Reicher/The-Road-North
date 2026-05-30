class_name PlayerStatsUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

@export var player_path: NodePath
@export var top_margin := 10.0
@export var left_margin := 10.0
@export var icon_size := 34.0
@export var row_height := 44.0
@export var panel_color := Color.TRANSPARENT
@export var border_color := Color.TRANSPARENT

var _player: GamePlayer
var _last_values: Dictionary = {}
var _pulse_strength: Dictionary = {}
var _pulse_sign: Dictionary = {}
var _pulse_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_node_or_null(player_path) as GamePlayer
	custom_minimum_size = Vector2(112.0, row_height * 4.0 + 16.0)
	size = custom_minimum_size
	position = Vector2(left_margin, top_margin)
	if _player != null and not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	if _player != null and not _player.food_changed.is_connected(_on_player_food_changed):
		_player.food_changed.connect(_on_player_food_changed)
	if _player != null and not _player.gold_changed.is_connected(_on_player_gold_changed):
		_player.gold_changed.connect(_on_player_gold_changed)
	var inventory := _get_inventory()
	if inventory != null and not inventory.stats_changed.is_connected(_on_inventory_stats_changed):
		inventory.stats_changed.connect(_on_inventory_stats_changed)
	_last_values = _get_current_values()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var fill := panel_color if panel_color != Color.TRANSPARENT else UIStyle.panel_fill(self)
	var border := border_color if border_color != Color.TRANSPARENT else UIStyle.panel_border(self)
	UIStyle.draw_panel(self, rect, fill, border)
	_draw_stat_row(0, "food", _get_food())
	_draw_stat_row(1, "gold", _get_gold())
	_draw_stat_row(2, "health", _get_health())
	_draw_stat_row(3, "power", _get_power())


func _draw_stat_row(index: int, stat_name: String, value: int) -> void:
	var row_center := Vector2(24.0, 8.0 + row_height * float(index) + row_height * 0.5)
	var pulse := float(_pulse_strength.get(stat_name, 0.0))
	if pulse > 0.0:
		var row_rect := Rect2(Vector2(6.0, row_center.y - row_height * 0.43), Vector2(size.x - 12.0, row_height * 0.86))
		var sign := int(_pulse_sign.get(stat_name, 1))
		var glow := _get_stat_glow_color(stat_name, sign)
		glow.a = 0.16 + pulse * 0.44
		draw_rect(row_rect, glow, true)
		draw_arc(row_center, icon_size * (0.60 + pulse * 0.16), 0.0, TAU, 28, glow.lightened(0.20), maxf(2.0, 5.0 * pulse))

	if stat_name == "food":
		StatIconPainter.draw_food(self, row_center, icon_size)
	elif stat_name == "gold":
		StatIconPainter.draw_gold(self, row_center, icon_size)
	elif stat_name == "health":
		StatIconPainter.draw_heart(self, row_center, icon_size)
	elif stat_name == "power":
		StatIconPainter.draw_sword(self, row_center, icon_size)

	var font: Font = ThemeDB.fallback_font
	var text_position := Vector2(56.0, row_center.y + 10.0)
	draw_string_outline(font, text_position, str(value), HORIZONTAL_ALIGNMENT_LEFT, 42.0, 24, 4, UIStyle.panel_fill(self))
	draw_string(font, text_position, str(value), HORIZONTAL_ALIGNMENT_LEFT, 42.0, 24, UIStyle.text(self))


func _get_food() -> int:
	if _player == null:
		return 0
	return _player.food


func _get_gold() -> int:
	if _player == null:
		return 0
	return _player.gold


func _get_health() -> int:
	if _player == null:
		return 0
	return _player.health


func _get_power() -> int:
	if _player == null:
		return 0
	return _player.get_total_power()


func _on_player_health_changed(_health: int) -> void:
	_handle_value_change("health", _health)


func _on_player_food_changed(_food: int) -> void:
	_handle_value_change("food", _food)


func _on_player_gold_changed(_gold: int) -> void:
	_handle_value_change("gold", _gold)


func _on_inventory_stats_changed() -> void:
	var current_values := _get_current_values()
	_handle_value_change("power", int(current_values.get("power", 0)))


func _handle_value_change(stat_name: String, value: int) -> void:
	var previous := int(_last_values.get(stat_name, value))
	_last_values[stat_name] = value
	if value == previous:
		queue_redraw()
		return
	_start_pulse(stat_name, 1 if value > previous else -1)


func _start_pulse(stat_name: String, sign: int) -> void:
	_pulse_strength[stat_name] = 1.0
	_pulse_sign[stat_name] = sign
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_method(_set_all_pulses, 1.0, 0.0, 0.48)
	queue_redraw()


func _set_all_pulses(value: float) -> void:
	for key in _pulse_strength.keys():
		_pulse_strength[key] = value
	queue_redraw()


func _get_current_values() -> Dictionary:
	return {
		"food": _get_food(),
		"gold": _get_gold(),
		"health": _get_health(),
		"power": _get_power(),
	}


func _get_inventory() -> InventoryUI:
	if _player == null or _player.inventory_path.is_empty():
		return null
	return _player.get_node_or_null(_player.inventory_path) as InventoryUI


func _get_stat_glow_color(stat_name: String, sign: int) -> Color:
	if sign < 0:
		return Color(1.0, 0.32, 0.22)
	if stat_name == "food":
		return Color(1.0, 0.74, 0.28)
	if stat_name == "gold":
		return Color(1.0, 0.86, 0.20)
	if stat_name == "health":
		return Color(1.0, 0.24, 0.32)
	if stat_name == "power":
		return Color(0.92, 0.92, 0.76)
	return UIStyle.focus(self)
