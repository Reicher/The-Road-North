class_name PlayerStatsUI
extends VBoxContainer

const STAT_ICON_SIZE := 54.0
const STAT_VALUE_FONT_SIZE := 38
const STAT_ROW_HEIGHT := 64.0
const ICON_PATHS := GameConstants.STAT_ICON_PATHS

@export var player_path: NodePath
@export var deck_controller_path: NodePath
@export var top_margin := 10.0
@export var left_margin := 10.0
@export var icon_size := STAT_ICON_SIZE
@export var row_height := STAT_ROW_HEIGHT
@export var gain_pulse_duration := 2.0

var _player: GamePlayer
var _deck_controller: DeckController
var _last_values: Dictionary = {}
var _deck_row: StatRow
var _food_row: StatRow
var _gold_row: StatRow
var _health_row: StatRow
var _power_row: StatRow

## Backward-compatible accessors for tests
var _pulse_strength: Dictionary:
	get:
		var d := {}
		for stat_name in ["food", "gold", "health", "power"]:
			d[stat_name] = _get_row(stat_name)._pulse_strength
		return d
var _pulse_sign: Dictionary:
	get:
		var d := {}
		for stat_name in ["food", "gold", "health", "power"]:
			d[stat_name] = _get_row(stat_name)._pulse_sign
		return d
var _gain_amounts: Dictionary:
	get:
		var d := {}
		for stat_name in ["food", "gold", "health", "power"]:
			d[stat_name] = _get_row(stat_name)._gain_amount
		return d


func _ready() -> void:
	position = Vector2(left_margin, top_margin)
	_deck_row = $DeckRow as StatRow
	_food_row = $FoodRow as StatRow
	_gold_row = $GoldRow as StatRow
	_health_row = $HealthRow as StatRow
	_power_row = $PowerRow as StatRow
	_food_row.low_warning_threshold = 3
	_health_row.low_warning_threshold = 3
	_player = get_node_or_null(player_path) as GamePlayer
	_deck_controller = get_node_or_null(deck_controller_path) as DeckController
	if _player != null and not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	if _player != null and not _player.base_power_changed.is_connected(_on_player_base_power_changed):
		_player.base_power_changed.connect(_on_player_base_power_changed)
	if _player != null and not _player.food_changed.is_connected(_on_player_food_changed):
		_player.food_changed.connect(_on_player_food_changed)
	if _player != null and not _player.gold_changed.is_connected(_on_player_gold_changed):
		_player.gold_changed.connect(_on_player_gold_changed)
	if _deck_controller != null and not _deck_controller.deck_count_changed.is_connected(_on_deck_count_changed):
		_deck_controller.deck_count_changed.connect(_on_deck_count_changed)
	var inventory := _get_inventory()
	if inventory != null and not inventory.stats_changed.is_connected(_on_inventory_stats_changed):
		inventory.stats_changed.connect(_on_inventory_stats_changed)
	_last_values = _get_current_values()
	_refresh_all_displays()


func sync_without_feedback() -> void:
	_deck_row.sync_without_feedback()
	_food_row.sync_without_feedback()
	_gold_row.sync_without_feedback()
	_health_row.sync_without_feedback()
	_power_row.sync_without_feedback()
	_last_values = _get_current_values()
	_refresh_all_displays()


func _refresh_all_displays() -> void:
	_deck_row.set_display_value(_get_deck_display())
	_food_row.set_display_value(_get_food())
	_gold_row.set_display_value(_get_gold())
	_health_row.set_display_value(_get_health_display())
	_power_row.set_display_value(_get_power())
	_food_row.check_low_warning(_get_food())
	_health_row.check_low_warning(_get_health())


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


func _get_deck_display() -> String:
	if _deck_controller == null:
		return "0/0"
	return "%d/%d" % [_deck_controller.cards_remaining(), _deck_controller.total_cards()]


func _on_player_health_changed(_health: int) -> void:
	_handle_value_change("health", _health)
	_health_row.check_low_warning(_health)


func _on_player_food_changed(_food: int) -> void:
	_handle_value_change("food", _food)
	_food_row.check_low_warning(_food)


func _on_player_gold_changed(_gold: int) -> void:
	_handle_value_change("gold", _gold)


func _on_deck_count_changed(_cards_remaining: int, _total_cards: int) -> void:
	_deck_row.set_display_value(_get_deck_display())


func _on_inventory_stats_changed() -> void:
	_handle_value_change("power", _get_power())


func _on_player_base_power_changed(_base_power: int) -> void:
	_handle_value_change("power", _get_power())


func _handle_value_change(stat_name: String, value: int) -> void:
	var previous := int(_last_values.get(stat_name, value))
	_last_values[stat_name] = value
	_get_row(stat_name).set_display_value(_get_display_for(stat_name))
	if value != previous:
		_get_row(stat_name).trigger_pulse(value - previous)


func _get_row(stat_name: String) -> StatRow:
	match stat_name:
		"deck":
			return _deck_row
		"food":
			return _food_row
		"gold":
			return _gold_row
		"health":
			return _health_row
		"power":
			return _power_row
	return _food_row


func _get_display_for(stat_name: String) -> Variant:
	match stat_name:
		"deck":
			return _get_deck_display()
		"food":
			return _get_food()
		"gold":
			return _get_gold()
		"health":
			return _get_health_display()
		"power":
			return _get_power()
	return 0


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


## Backward-compatible icon loader for tests.
func _get_stat_icon(stat_name: String) -> Texture2D:
	var path := str(ICON_PATHS.get(stat_name, ""))
	if path.is_empty():
		return null
	return load(path) as Texture2D


## Backward-compatible glow color for tests.
static func _get_stat_glow_color(_stat_name: String, sign: int) -> Color:
	if sign < 0:
		return Color(1.0, 0.32, 0.22)
	return Color(0.32, 1.0, 0.38)
