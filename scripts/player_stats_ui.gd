class_name PlayerStatsUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

@export var player_path: NodePath
@export var top_margin := 18.0
@export var left_margin := 18.0
@export var icon_size := 34.0
@export var row_height := 44.0
@export var panel_color := Color.TRANSPARENT
@export var border_color := Color.TRANSPARENT

var _player: GamePlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_node_or_null(player_path) as GamePlayer
	custom_minimum_size = Vector2(112.0, row_height * 5.0 + 16.0)
	size = custom_minimum_size
	position = Vector2(left_margin, top_margin)
	if _player != null and not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	if _player != null and not _player.food_changed.is_connected(_on_player_food_changed):
		_player.food_changed.connect(_on_player_food_changed)
	if _player != null and not _player.gold_changed.is_connected(_on_player_gold_changed):
		_player.gold_changed.connect(_on_player_gold_changed)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var fill := panel_color if panel_color != Color.TRANSPARENT else UIStyle.panel_fill(self)
	var border := border_color if border_color != Color.TRANSPARENT else UIStyle.panel_border(self)
	UIStyle.draw_panel(self, rect, fill, border)
	_draw_stat_row(0, "food", _get_food())
	_draw_stat_row(1, "gold", _get_gold())
	_draw_stat_row(2, "health", _get_health())
	_draw_stat_row(3, "attack", _get_attack())
	_draw_stat_row(4, "armor", _get_armor())


func _draw_stat_row(index: int, stat_name: String, value: int) -> void:
	var row_center := Vector2(24.0, 8.0 + row_height * float(index) + row_height * 0.5)
	if stat_name == "food":
		StatIconPainter.draw_food(self, row_center, icon_size)
	elif stat_name == "gold":
		StatIconPainter.draw_gold(self, row_center, icon_size)
	elif stat_name == "health":
		StatIconPainter.draw_heart(self, row_center, icon_size)
	elif stat_name == "attack":
		StatIconPainter.draw_sword(self, row_center, icon_size)
	elif stat_name == "armor":
		StatIconPainter.draw_shield(self, row_center, icon_size)

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


func _get_attack() -> int:
	if _player == null:
		return 0
	return _player.get_total_attack()


func _get_armor() -> int:
	if _player == null:
		return 0
	return _player.get_total_armor()


func _on_player_health_changed(_health: int) -> void:
	queue_redraw()


func _on_player_food_changed(_food: int) -> void:
	queue_redraw()


func _on_player_gold_changed(_gold: int) -> void:
	queue_redraw()
