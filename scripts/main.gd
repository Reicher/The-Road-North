extends Node

const ItemCatalog = preload("res://scripts/item_catalog.gd")
const SHOP_SCENE := preload("res://ui/shop.tscn")
const START_SCREEN_SCENE := preload("res://ui/start_screen.tscn")
const EXPEDITION_NAME_POPUP_SCENE := preload("res://ui/expedition_name_popup.tscn")
const TouchFeedback = preload("res://scripts/touch_feedback.gd")
const RunStats = preload("res://scripts/run_stats.gd")
const RunStatsTrackerScript = preload("res://scripts/run_stats_tracker.gd")

const DEBUG_LABEL_TEXT := "Debug"
const DEBUG_HAND_ACTIONS := {
	"debug_hand_likely": "likely",
	"debug_hand_roads": "roads",
	"debug_hand_enemies": "enemies",
	"debug_hand_rewards": "rewards",
	"debug_hand_events": "events",
}

@export var level_catalog: Resource = preload("res://data/level_catalog.tres")
@export var debug_label_path: NodePath = NodePath("DebugOverlay/DebugLabel")
@export var shop_layer_path: NodePath = NodePath("ShopLayer")
@export var transition_shade_path: NodePath = NodePath("TransitionLayer/ForestFade")
@export var transition_label_path: NodePath = NodePath("TransitionLayer/ForestFade/TransitionLabel")

var _current_level_index := 0
var _current_level: Node
var _level_start_progression: Dictionary = {}
var _debug_mode_enabled := false
var _debug_label: Label
var _shop: Control
var _shop_layer: CanvasLayer
var _shop_start_gold := 0
var _start_screen: StartScreen
var _expedition_popup: CanvasLayer
var _run_stats_tracker := RunStatsTrackerScript.new()
var _transition_shade: ColorRect
var _transition_label: Label
var _transition_running := false

const FOREST_TRANSITION_COLOR := Color(0.045, 0.10, 0.075, 1.0)
const SHOP_TRANSITION_COLOR := Color.BLACK
const SHOP_TRANSITION_HOLD := 1.4
const LEVEL_COMPLETION_GOLD_REWARD := 5
const LEVEL_COMPLETE_TEXT := "Road complete!\n+%d Gold" % LEVEL_COMPLETION_GOLD_REWARD


func _ready() -> void:
	ItemCatalog.initialize()
	assert(level_catalog != null and level_catalog.size() > 0, "At least one level must be configured")
	_bind_scene_nodes()
	_run_stats_tracker.name = "RunStatsTracker"
	add_child(_run_stats_tracker)
	_show_start_screen()


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("debug_toggle"):
		var enabling_debug := not _debug_mode_enabled
		_set_debug_mode_enabled(enabling_debug)
		if enabling_debug:
			_begin_new_run(RunStats.DEFAULT_EXPEDITION_NAME)
		get_viewport().set_input_as_handled()
		return

	if not _debug_mode_enabled:
		return

	var debug_level_index := _debug_level_index_from_event(event)
	if debug_level_index >= 0:
		_level_start_progression.clear()
		_load_level(debug_level_index)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_complete_level"):
		_complete_current_level()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_add_gold"):
		_debug_add_gold()
		get_viewport().set_input_as_handled()
	else:
		for action in DEBUG_HAND_ACTIONS:
			if event.is_action_pressed(action):
				_show_debug_hand(DEBUG_HAND_ACTIONS[action])
				get_viewport().set_input_as_handled()
				return


func _debug_level_index_from_event(event: InputEvent) -> int:
	if not event is InputEventKey:
		return -1
	var key_event := event as InputEventKey
	var keycode := key_event.keycode
	if keycode == KEY_0 or key_event.physical_keycode == KEY_0:
		return 9 if _level_count() >= 10 else -1
	if keycode < KEY_1 or keycode > KEY_9:
		keycode = key_event.physical_keycode
	if keycode < KEY_1 or keycode > KEY_9:
		return -1
	var level_index := int(keycode - KEY_1)
	return level_index if level_index < _level_count() else -1


func _load_level(level_index: int) -> void:
	_dismiss_start_screen()
	_dismiss_expedition_popup()
	_close_shop()
	if _current_level != null:
		remove_child(_current_level)
		_current_level.queue_free()

	_current_level_index = clampi(level_index, 0, _level_count() - 1)
	var level_scene := _level_data(_current_level_index).get("scene") as PackedScene
	assert(level_scene != null, "Every configured level needs a PackedScene")
	_current_level = level_scene.instantiate()
	_current_level.name = "Level"
	_configure_level_intro()
	add_child(_current_level)
	if not _level_start_progression.is_empty():
		_apply_progression(_level_start_progression)
	_configure_player_deck(_level_start_progression)
	_sync_stats_without_feedback()
	_level_start_progression = _capture_progression_with_extras(_level_start_progression)
	_configure_level_end_screen()
	_run_stats_tracker.attach_level(_current_level, _current_level_index + 1)


func _configure_level_intro() -> void:
	if _current_level is Level:
		(_current_level as Level).play_intro_sequence = not _debug_mode_enabled
	var camera := _current_level.get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		camera.set("play_start_zoom_sequence", not _debug_mode_enabled)


func _configure_level_end_screen() -> void:
	var end_screen := _current_level.get_node_or_null("UI/GameOver") as GameOverUI
	if end_screen == null:
		return
	end_screen.has_next_level = _current_level_index < _level_count() - 1
	end_screen.show_level_complete_prompt = false
	end_screen.run_stats_tracker = _run_stats_tracker
	if not end_screen.next_level_requested.is_connected(_on_next_level_requested):
		end_screen.next_level_requested.connect(_on_next_level_requested)
	if not end_screen.restart_level_requested.is_connected(_on_restart_level_requested):
		end_screen.restart_level_requested.connect(_on_restart_level_requested)
	if not end_screen.restart_game_requested.is_connected(_on_restart_game_requested):
		end_screen.restart_game_requested.connect(_on_restart_game_requested)
	var player := _current_level.get_node_or_null("Player") as GamePlayer
	if player != null and not player.run_won.is_connected(_on_level_won):
		player.run_won.connect(_on_level_won)
	if _current_level.has_signal("goal_arrival_finished") and not _current_level.is_connected("goal_arrival_finished", Callable(self, "_on_goal_arrival_finished")):
		_current_level.connect("goal_arrival_finished", Callable(self, "_on_goal_arrival_finished"))


func _bind_scene_nodes() -> void:
	_debug_label = get_node_or_null(debug_label_path) as Label
	_shop_layer = get_node_or_null(shop_layer_path) as CanvasLayer
	_transition_shade = get_node_or_null(transition_shade_path) as ColorRect
	_transition_label = get_node_or_null(transition_label_path) as Label
	if _debug_label == null:
		push_warning("Main needs a DebugOverlay/DebugLabel scene node.")
	if _shop_layer == null:
		push_warning("Main needs a ShopLayer scene node.")
	if _transition_shade == null or _transition_label == null:
		push_warning("Main needs TransitionLayer/ForestFade/TransitionLabel scene nodes.")


func _set_debug_mode_enabled(enabled: bool) -> void:
	_debug_mode_enabled = enabled
	if _debug_label != null:
		_debug_label.visible = _debug_mode_enabled


func _show_start_screen() -> void:
	if _start_screen != null:
		return
	_start_screen = START_SCREEN_SCENE.instantiate() as StartScreen
	_start_screen.play_requested.connect(_start_new_game)
	add_child(_start_screen)


func _dismiss_start_screen() -> void:
	if _start_screen == null:
		return
	_start_screen.hide()
	_start_screen.queue_free()
	_start_screen = null


func _start_new_game() -> void:
	_show_expedition_popup()


func _show_expedition_popup() -> void:
	if _expedition_popup != null:
		return
	_level_start_progression.clear()
	_expedition_popup = EXPEDITION_NAME_POPUP_SCENE.instantiate() as CanvasLayer
	add_child(_expedition_popup)
	_expedition_popup.expedition_named.connect(_begin_new_run)


func _dismiss_expedition_popup() -> void:
	if _expedition_popup == null:
		return
	_expedition_popup.queue_free()
	_expedition_popup = null


func _begin_new_run(expedition_name: String) -> void:
	_dismiss_expedition_popup()
	_level_start_progression.clear()
	_run_stats_tracker.start_new_run(expedition_name)
	_transition_to_level(0, _level_transition_text(0))


func _complete_current_level() -> void:
	if _current_level == null:
		return
	var map := _current_level.get_node_or_null("Map") as GameMap
	var player := _current_level.get_node_or_null("Player") as GamePlayer
	if map == null or player == null:
		return
	player.grid_position = map.get_goal_position()
	player.check_run_won()


func _debug_add_gold() -> void:
	if _shop != null:
		_shop.debug_add_gold(5)
		return
	if _current_level == null:
		return
	var player := _current_level.get_node_or_null("Player") as GamePlayer
	if player != null:
		player.add_gold(5)


func _show_debug_hand(kind: String) -> void:
	if _current_level == null:
		return
	var deck_controller := _current_level.get_node_or_null("DeckController") as DeckController
	if deck_controller != null:
		deck_controller.show_debug_hand(kind)


func _on_next_level_requested() -> void:
	_open_shop()


func _on_level_won() -> void:
	pass


func _on_goal_arrival_finished() -> void:
	if _current_level_index < _level_count() - 1:
		_open_shop_with_transition()


func _on_restart_level_requested() -> void:
	if _current_level != null:
		var end_screen := _current_level.get_node_or_null("UI/GameOver") as GameOverUI
		if end_screen != null and end_screen.visible:
			_run_stats_tracker.start_new_run(_run_stats_tracker.stats.expedition_name)
	_transition_to_level(_current_level_index, _level_transition_text(_current_level_index))


func _on_restart_game_requested() -> void:
	_close_shop()
	_level_start_progression.clear()
	_show_expedition_popup()


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
	for key in ["player_removed_base_cards", "player_removed_card_count", "player_special_cards", "player_locked_base_cards", "active_power_bonus", "active_max_health_bonus"]:
		if extras.has(key):
			progression[key] = extras[key].duplicate(true) if extras[key] is Array or extras[key] is Dictionary else extras[key]
	var deck_controller := _current_level.get_node_or_null("DeckController") as DeckController if _current_level != null else null
	if deck_controller != null:
		progression["player_special_cards"] = deck_controller.player_special_cards.duplicate(true)
		progression["player_locked_base_cards"] = deck_controller.player_locked_base_cards.duplicate(true)
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
	if inventory != null:
		inventory.set_items(applied.get("inventory", []), false)
	if player != null:
		player.apply_progression_state(applied, false)
	if stats != null:
		stats.sync_without_feedback()
	_level_start_progression = applied


func _sync_stats_without_feedback() -> void:
	if _current_level == null:
		return
	var stats := _current_level.get_node_or_null("UI/PlayerStats") as PlayerStatsUI
	if stats != null:
		stats.sync_without_feedback()


func _configure_player_deck(progression: Dictionary) -> void:
	var deck_controller := _current_level.get_node_or_null("DeckController") as DeckController
	if deck_controller == null:
		return
	deck_controller.set_player_deck_modifiers(
		progression.get("player_removed_base_cards", []),
		progression.get("player_special_cards", []),
		progression.get("player_locked_base_cards", [])
	)
	if not deck_controller.restart_level_requested.is_connected(_on_dream_restart_level_requested):
		deck_controller.restart_level_requested.connect(_on_dream_restart_level_requested)
	deck_controller.start_run()


func _on_dream_restart_level_requested() -> void:
	_on_restart_level_requested.call_deferred()


func _open_shop() -> void:
	if _shop != null or _current_level_index >= _level_count() - 1:
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
	progression["gold"] = int(progression.get("gold", 0)) + LEVEL_COMPLETION_GOLD_REWARD
	_run_stats_tracker.stats.gold_gained += LEVEL_COMPLETION_GOLD_REWARD
	_shop_start_gold = int(progression.get("gold", 0))
	var deck_controller := _current_level.get_node_or_null("DeckController") as DeckController
	var available_base_cards: Array = deck_controller.deck_components.get(DeckBuilder.DECK_SOURCE_BASE, []) if deck_controller != null else []
	var next_level: Dictionary = _level_data(_current_level_index + 1)
	var map_size := int(next_level.get("map_size", 5))
	_shop = SHOP_SCENE.instantiate() as Control
	if _shop_layer == null:
		push_warning("Cannot open shop without a ShopLayer node.")
		_shop.queue_free()
		_shop = null
		return
	_shop_layer.add_child(_shop)
	_shop.setup(progression, str(next_level.get("name", "Level %d" % (_current_level_index + 2))), map_size, available_base_cards)
	TouchFeedback.apply_to_tree(_shop)
	_shop.play_next_requested.connect(_on_shop_play_next_requested)
	var level_ui := _current_level.get_node_or_null("UI") as CanvasLayer
	if level_ui != null:
		var hand := level_ui.get_node_or_null("Hand") as Control
		if hand != null:
			hand.visible = false
		level_ui.visible = false


func _on_shop_play_next_requested(progression: Dictionary) -> void:
	var next_gold := int(progression.get("gold", 0))
	if next_gold < _shop_start_gold:
		_run_stats_tracker.stats.gold_spent += _shop_start_gold - next_gold
	elif next_gold > _shop_start_gold:
		_run_stats_tracker.stats.gold_gained += next_gold - _shop_start_gold
	_level_start_progression = progression.duplicate(true)
	_close_shop()
	_transition_to_level(_current_level_index + 1, _level_transition_text(_current_level_index + 1))


func _close_shop() -> void:
	if _shop == null:
		return
	_shop.queue_free()
	_shop = null


func _transition_to_level(level_index: int, label_text: String) -> void:
	if _transition_running:
		return
	_transition_running = true
	_begin_transition_cover(label_text)
	_load_level(level_index)
	_transition_running = false
	_finish_transition_async()


func _transition_to_level_async(level_index: int, label_text: String) -> void:
	await _fade_transition_in(label_text)
	if not is_inside_tree():
		return
	_load_level(level_index)
	await get_tree().create_timer(0.12).timeout
	await _fade_transition_out()
	_transition_running = false


func _open_shop_with_transition() -> void:
	if _transition_running:
		return
	_transition_running = true
	_begin_transition_cover(LEVEL_COMPLETE_TEXT, SHOP_TRANSITION_COLOR)
	_open_shop()
	_transition_running = false
	_finish_transition_async(SHOP_TRANSITION_HOLD)


func _open_shop_with_transition_async() -> void:
	await _fade_transition_in(LEVEL_COMPLETE_TEXT, SHOP_TRANSITION_COLOR)
	if not is_inside_tree():
		return
	_open_shop()
	await get_tree().create_timer(SHOP_TRANSITION_HOLD).timeout
	await _fade_transition_out()
	_transition_running = false


func _begin_transition_cover(label_text: String, shade_color := FOREST_TRANSITION_COLOR) -> void:
	if _transition_shade == null or _transition_label == null:
		return
	_transition_label.text = label_text
	_transition_label.modulate.a = 1.0
	_transition_label.scale = Vector2.ONE
	_transition_shade.visible = true
	_transition_shade.color = shade_color


func _finish_transition_async(hold_duration := 0.0) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
		if not is_inside_tree():
			return
	await _fade_transition_out()


func _fade_transition_in(label_text: String, shade_color := FOREST_TRANSITION_COLOR) -> void:
	if _transition_shade == null or _transition_label == null:
		return
	_transition_label.text = label_text
	_transition_label.modulate.a = 0.0
	_transition_label.scale = Vector2(0.98, 0.98)
	_transition_shade.visible = true
	_transition_shade.color = Color(shade_color, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_transition_shade, "color:a", shade_color.a, 0.30)
	tween.tween_property(_transition_label, "modulate:a", 1.0, 0.30)
	tween.tween_property(_transition_label, "scale", Vector2.ONE, 0.30)
	await tween.finished
	await get_tree().create_timer(0.18).timeout


func _fade_transition_out() -> void:
	if _transition_shade == null or _transition_label == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_transition_shade, "color:a", 0.0, 0.34)
	tween.tween_property(_transition_label, "modulate:a", 0.0, 0.20)
	await tween.finished
	_transition_shade.visible = false


func _level_transition_text(level_index: int) -> String:
	var clamped_index := clampi(level_index, 0, _level_count() - 1)
	var level_data := _level_data(clamped_index)
	return "%s\n%dx%d map" % [
		str(level_data.get("name", "Level %d" % (clamped_index + 1))),
		int(level_data.get("map_size", 5)),
		int(level_data.get("map_size", 5)),
	]


func _level_count() -> int:
	return level_catalog.size() if level_catalog != null else 0


func _level_data(level_index: int) -> Dictionary:
	return level_catalog.get_level(level_index) if level_catalog != null else {}
