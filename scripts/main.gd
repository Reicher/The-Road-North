extends Node

const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://levels/level_001.tscn"),
	preload("res://levels/level_002.tscn"),
]
const SHOP_SCENE := preload("res://ui/shop.tscn")
const LEVEL_NAMES := ["", "3 bridges"]

const DEBUG_LABEL_TEXT := "Debug"
const DEBUG_HAND_SHORTCUTS := {
	KEY_Q: "likely",
	KEY_W: "roads",
	KEY_E: "enemies",
	KEY_R: "rewards",
	KEY_T: "events",
}

var _current_level_index := 0
var _current_level: Node
var _level_start_progression: Dictionary = {}
var _debug_mode_enabled := false
var _debug_layer: CanvasLayer
var _debug_label: Label
var _shop: Control
var _shop_layer: CanvasLayer


func _ready() -> void:
	_ensure_debug_overlay()
	_load_level(0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_D:
		_set_debug_mode_enabled(not _debug_mode_enabled)
		get_viewport().set_input_as_handled()
		return
	if not _debug_mode_enabled:
		return
	if event.keycode == KEY_1:
		_level_start_progression.clear()
		_load_level(0)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_2:
		_level_start_progression.clear()
		_load_level(1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_complete_current_level()
		get_viewport().set_input_as_handled()
	elif DEBUG_HAND_SHORTCUTS.has(event.keycode):
		_show_debug_hand(DEBUG_HAND_SHORTCUTS[event.keycode])
		get_viewport().set_input_as_handled()


func _load_level(level_index: int) -> void:
	_close_shop()
	if _current_level != null:
		remove_child(_current_level)
		_current_level.queue_free()

	_current_level_index = clampi(level_index, 0, LEVEL_SCENES.size() - 1)
	_current_level = LEVEL_SCENES[_current_level_index].instantiate()
	_current_level.name = "Level"
	add_child(_current_level)
	if not _level_start_progression.is_empty():
		_apply_progression(_level_start_progression)
	_configure_player_deck(_level_start_progression)
	_level_start_progression = _capture_progression_with_extras(_level_start_progression)
	_configure_level_end_screen()


func _configure_level_end_screen() -> void:
	var end_screen := _current_level.get_node_or_null("UI/GameOver") as GameOverUI
	if end_screen == null:
		return
	end_screen.has_next_level = _current_level_index < LEVEL_SCENES.size() - 1
	if not end_screen.next_level_requested.is_connected(_on_next_level_requested):
		end_screen.next_level_requested.connect(_on_next_level_requested)
	if not end_screen.restart_level_requested.is_connected(_on_restart_level_requested):
		end_screen.restart_level_requested.connect(_on_restart_level_requested)
	if not end_screen.restart_game_requested.is_connected(_on_restart_game_requested):
		end_screen.restart_game_requested.connect(_on_restart_game_requested)
	var player := _current_level.get_node_or_null("Player") as GamePlayer
	if player != null and not player.run_won.is_connected(_on_level_won):
		player.run_won.connect(_on_level_won)


func _ensure_debug_overlay() -> void:
	if _debug_layer != null:
		return
	_debug_layer = CanvasLayer.new()
	_debug_layer.name = "DebugOverlay"
	_debug_layer.layer = 100
	add_child(_debug_layer)

	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.text = DEBUG_LABEL_TEXT
	_debug_label.visible = false
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_font_size_override("font_size", 18)
	_debug_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_debug_label.position = Vector2(8.0, -28.0)
	_debug_layer.add_child(_debug_label)


func _set_debug_mode_enabled(enabled: bool) -> void:
	_debug_mode_enabled = enabled
	if _debug_label != null:
		_debug_label.visible = _debug_mode_enabled


func _complete_current_level() -> void:
	if _current_level == null:
		return
	var map := _current_level.get_node_or_null("Map") as GameMap
	var player := _current_level.get_node_or_null("Player") as GamePlayer
	if map == null or player == null:
		return
	player.grid_position = map.get_goal_position()
	player.call("_check_run_won")


func _show_debug_hand(kind: String) -> void:
	if _current_level == null:
		return
	var deck_controller := _current_level.get_node_or_null("DeckController") as DeckController
	if deck_controller != null:
		deck_controller.show_debug_hand(kind)


func _on_next_level_requested() -> void:
	_open_shop()


func _on_level_won() -> void:
	_open_shop()


func _on_restart_level_requested() -> void:
	_load_level(_current_level_index)


func _on_restart_game_requested() -> void:
	_close_shop()
	_level_start_progression.clear()
	_load_level(0)


func _capture_progression() -> Dictionary:
	if _current_level == null:
		return {}
	var player := _current_level.get_node_or_null("Player") as GamePlayer
	var inventory := _current_level.get_node_or_null("UI/Inventory") as InventoryUI
	if player == null or inventory == null:
		return {}
	var progression := player.get_progression_state()
	progression["inventory"] = inventory.get_items()
	return progression


func _capture_progression_with_extras(extras: Dictionary) -> Dictionary:
	var progression := _capture_progression()
	for key in ["player_removed_base_cards", "player_special_cards", "active_power_bonus", "active_max_health_bonus"]:
		if extras.has(key):
			progression[key] = extras[key].duplicate(true) if extras[key] is Array or extras[key] is Dictionary else extras[key]
	return progression


func _apply_progression(progression: Dictionary) -> void:
	if _current_level == null:
		return
	var player := _current_level.get_node_or_null("Player") as GamePlayer
	var inventory := _current_level.get_node_or_null("UI/Inventory") as InventoryUI
	var stats := _current_level.get_node_or_null("UI/PlayerStats") as PlayerStatsUI
	var applied := progression.duplicate(true)
	var pending_power := int(applied.get("pending_power_bonus", 0))
	var pending_max_health := int(applied.get("pending_max_health_bonus", 0))
	if pending_power > 0:
		applied["base_power"] = int(applied.get("base_power", 0)) + pending_power
		applied["active_power_bonus"] = pending_power
	if pending_max_health > 0:
		applied["max_health"] = int(applied.get("max_health", 1)) + pending_max_health
		applied["health"] = int(applied.get("health", 0)) + pending_max_health
		applied["active_max_health_bonus"] = pending_max_health
	applied.erase("pending_power_bonus")
	applied.erase("pending_max_health_bonus")
	if player != null:
		player.apply_progression_state(applied, false)
	if inventory != null:
		inventory.set_items(applied.get("inventory", []), false)
	if stats != null:
		stats.sync_without_feedback()
	_level_start_progression = applied


func _configure_player_deck(progression: Dictionary) -> void:
	var deck_controller := _current_level.get_node_or_null("DeckController") as DeckController
	if deck_controller == null:
		return
	deck_controller.set_player_deck_modifiers(
		progression.get("player_removed_base_cards", []),
		progression.get("player_special_cards", [])
	)
	if not deck_controller.restart_level_requested.is_connected(_on_dream_restart_level_requested):
		deck_controller.restart_level_requested.connect(_on_dream_restart_level_requested)
	deck_controller.start_run()


func _on_dream_restart_level_requested() -> void:
	_on_restart_level_requested.call_deferred()


func _open_shop() -> void:
	if _shop != null or _current_level_index >= LEVEL_SCENES.size() - 1:
		return
	var progression := _capture_progression_with_extras(_level_start_progression)
	var active_power := int(progression.get("active_power_bonus", 0))
	var active_max_health := int(progression.get("active_max_health_bonus", 0))
	progression["base_power"] = int(progression.get("base_power", 0)) - active_power
	progression["max_health"] = maxi(1, int(progression.get("max_health", 1)) - active_max_health)
	progression["health"] = mini(int(progression.get("health", 0)), int(progression["max_health"]))
	progression.erase("active_power_bonus")
	progression.erase("active_max_health_bonus")
	progression.erase("removed_base_card_this_shop")
	var deck_controller := _current_level.get_node_or_null("DeckController") as DeckController
	var available_base_cards: Array = deck_controller.deck_components.get(DeckBuilder.DECK_SOURCE_BASE, []) if deck_controller != null else []
	var next_scene := LEVEL_SCENES[_current_level_index + 1].instantiate()
	var next_map := next_scene.get_node("Map") as GameMap
	var map_size := mini(next_map.playable_width, next_map.playable_height)
	next_scene.free()
	_shop = SHOP_SCENE.instantiate() as Control
	_shop_layer = CanvasLayer.new()
	_shop_layer.name = "ShopLayer"
	_shop_layer.layer = 50
	add_child(_shop_layer)
	_shop_layer.add_child(_shop)
	_shop.setup(progression, LEVEL_NAMES[_current_level_index + 1], map_size, available_base_cards)
	_shop.play_next_requested.connect(_on_shop_play_next_requested)
	var level_ui := _current_level.get_node_or_null("UI") as CanvasLayer
	if level_ui != null:
		level_ui.visible = false


func _on_shop_play_next_requested(progression: Dictionary) -> void:
	_level_start_progression = progression.duplicate(true)
	_close_shop()
	_load_level(_current_level_index + 1)


func _close_shop() -> void:
	if _shop == null:
		return
	_shop.queue_free()
	_shop = null
	if _shop_layer != null:
		_shop_layer.queue_free()
		_shop_layer = null
