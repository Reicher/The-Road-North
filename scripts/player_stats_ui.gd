class_name PlayerStatsUI
extends Control

const ICON_PATHS := {
	"food": "res://assets/images/stat_food.png",
	"gold": "res://assets/images/stat_gold.png",
	"health": "res://assets/images/stat_health.png",
	"power": "res://assets/images/stat_power.png",
}

@export var player_path: NodePath
@export var top_margin := 10.0
@export var left_margin := 10.0
@export var icon_size := 48.0
@export var row_height := 58.0
@export var panel_color := Color.TRANSPARENT
@export var border_color := Color.TRANSPARENT
@export var gain_pulse_duration := 2.0

var _player: GamePlayer
var _last_values: Dictionary = {}
var _pulse_strength: Dictionary = {}
var _pulse_sign: Dictionary = {}
var _gain_amounts: Dictionary = {}
var _pulse_tweens: Dictionary = {}
var _icon_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_node_or_null(player_path) as GamePlayer
	custom_minimum_size = Vector2(210.0, row_height * 4.0 + 10.0)
	size = custom_minimum_size
	position = Vector2(left_margin, top_margin)
	if _player != null and not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	if _player != null and not _player.base_power_changed.is_connected(_on_player_base_power_changed):
		_player.base_power_changed.connect(_on_player_base_power_changed)
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
	_draw_stat_row(0, "food", _get_food())
	_draw_stat_row(1, "gold", _get_gold())
	_draw_stat_row(2, "health", _get_health_display())
	_draw_stat_row(3, "power", _get_power())


func _draw_stat_row(index: int, stat_name: String, value: Variant) -> void:
	var row_center := Vector2(31.0, 5.0 + row_height * float(index) + row_height * 0.5)
	var pulse := float(_pulse_strength.get(stat_name, 0.0))
	var sign := int(_pulse_sign.get(stat_name, 1))
	var change_amount := int(_gain_amounts.get(stat_name, 0))
	var change_color := _get_stat_glow_color(stat_name, sign)
	if pulse > 0.0:
		var glow := _get_stat_glow_color(stat_name, sign)
		glow.a = 0.22 + pulse * 0.46
		draw_circle(row_center, icon_size * (0.48 + pulse * 0.16), glow)
		draw_arc(row_center, icon_size * (0.64 + pulse * 0.15), 0.0, TAU, 28, glow.lightened(0.20), maxf(2.0, 5.0 * pulse))

	var icon := _get_stat_icon(stat_name)
	if icon != null:
		var icon_rect := Rect2(row_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
		var icon_color := Color.WHITE
		if pulse > 0.0:
			icon_color = Color.WHITE.lerp(change_color, 0.62 * pulse)
		draw_texture_rect(icon, icon_rect, false, icon_color)

	var font: Font = ThemeDB.fallback_font
	var font_size := 34
	var text_position := Vector2(70.0, row_center.y + 13.0)
	draw_string_outline(font, text_position, str(value), HORIZONTAL_ALIGNMENT_LEFT, 72.0, font_size, 7, Color(0.10, 0.08, 0.05, 0.92))
	var value_color := Color(1.0, 0.96, 0.84)
	if pulse > 0.0:
		value_color = value_color.lerp(change_color, 0.86 * pulse)
	draw_string(font, text_position, str(value), HORIZONTAL_ALIGNMENT_LEFT, 72.0, font_size, value_color)
	if pulse > 0.0 and change_amount != 0:
		var value_width := font.get_string_size(str(value), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var gain_position := text_position + Vector2(value_width + 8.0, 0.0)
		var change_text := "%+d" % change_amount
		draw_string_outline(font, gain_position, change_text, HORIZONTAL_ALIGNMENT_LEFT, 76.0, font_size, 7, Color(0.10, 0.08, 0.05, 0.94))
		draw_string(font, gain_position, change_text, HORIZONTAL_ALIGNMENT_LEFT, 76.0, font_size, change_color)


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


func _get_health_display() -> String:
	if _player == null:
		return "0/0"
	return "%d/%d" % [_player.health, _player.max_health]


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


func _on_player_base_power_changed(_base_power: int) -> void:
	_handle_value_change("power", _get_power())


func sync_without_feedback() -> void:
	for tween in _pulse_tweens.values():
		if tween is Tween:
			(tween as Tween).kill()
	_pulse_tweens.clear()
	_pulse_strength.clear()
	_pulse_sign.clear()
	_gain_amounts.clear()
	_last_values = _get_current_values()
	queue_redraw()


func _handle_value_change(stat_name: String, value: int) -> void:
	var previous := int(_last_values.get(stat_name, value))
	_last_values[stat_name] = value
	if value == previous:
		queue_redraw()
		return
	_start_pulse(stat_name, value - previous)


func _start_pulse(stat_name: String, change: int) -> void:
	var existing_change := int(_gain_amounts.get(stat_name, 0))
	var is_same_active_change := signi(existing_change) == signi(change) and float(_pulse_strength.get(stat_name, 0.0)) > 0.0
	_pulse_strength[stat_name] = 1.0
	_pulse_sign[stat_name] = 1 if change > 0 else -1
	_gain_amounts[stat_name] = existing_change + change if is_same_active_change else change
	var existing_tween := _pulse_tweens.get(stat_name) as Tween
	if existing_tween != null:
		existing_tween.kill()
	var tween := create_tween()
	_pulse_tweens[stat_name] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_pulse.bind(stat_name), 1.0, 0.0, gain_pulse_duration)
	tween.finished.connect(_finish_pulse.bind(stat_name))
	queue_redraw()


func _set_pulse(value: float, stat_name: String) -> void:
	_pulse_strength[stat_name] = value
	queue_redraw()


func _finish_pulse(stat_name: String) -> void:
	_pulse_strength[stat_name] = 0.0
	_gain_amounts[stat_name] = 0
	_pulse_tweens.erase(stat_name)
	queue_redraw()


func _get_current_values() -> Dictionary:
	return {
		"food": _get_food(),
		"gold": _get_gold(),
		"health": _get_health(),
		"power": _get_power(),
	}


func _get_stat_icon(stat_name: String) -> Texture2D:
	if _icon_cache.has(stat_name):
		return _icon_cache[stat_name]
	var path := str(ICON_PATHS.get(stat_name, ""))
	if path.is_empty():
		return null
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if error != OK or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_icon_cache[stat_name] = texture
	return texture


func _get_inventory() -> InventoryUI:
	if _player == null or _player.inventory_path.is_empty():
		return null
	return _player.get_node_or_null(_player.inventory_path) as InventoryUI


func _get_stat_glow_color(stat_name: String, sign: int) -> Color:
	if sign < 0:
		return Color(1.0, 0.32, 0.22)
	return Color(0.32, 1.0, 0.38)
