class_name GameOverUI
extends Control

const RunStats = preload("res://scripts/run_stats.gd")
const LocalRecords = preload("res://scripts/local_records.gd")
const UIStyle = preload("res://scripts/ui_style.gd")

signal next_level_requested
signal restart_level_requested
signal restart_game_requested

@export var player_path: NodePath
@export var hand_path: NodePath = NodePath("../Hand")
@export var has_next_level := false
@export var show_level_complete_prompt := true
@export var level_complete_gold_reward := 5

var run_stats_tracker: Node

var _player: GamePlayer
var _hand: Control
var _panel: PanelContainer
var _title_label: Label
var _reward_label: Label
var _action_button: Button
var _stack: VBoxContainer
var _grid: GridContainer
var _secondary_button: Button
var _ready_completed := false
var _action := ""
var _secondary_action := ""
var _run_finalized := false


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	_player = get_node_or_null(player_path) as GamePlayer
	_hand = get_node_or_null(hand_path) as Control
	if _player != null and not _player.game_over.is_connected(_on_game_over):
		_player.game_over.connect(_on_game_over)
	if _player != null and not _player.run_won.is_connected(_on_run_won):
		_player.run_won.connect(_on_run_won)
	_bind_scene_nodes()


func _gui_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		accept_event()
	elif visible and event is InputEventScreenTouch:
		accept_event()


func _bind_scene_nodes() -> void:
	_panel = get_node("Prompt") as PanelContainer
	_stack = get_node("Prompt/ContentMargin/Stack") as VBoxContainer
	_title_label = get_node("Prompt/ContentMargin/Stack/Title") as Label
	_reward_label = get_node("Prompt/ContentMargin/Stack/Reward") as Label
	_action_button = get_node("Prompt/ContentMargin/Stack/RestartButton") as Button
	if not _action_button.pressed.is_connected(_on_action_button_pressed):
		_action_button.pressed.connect(_on_action_button_pressed)
	_build_report_nodes()
	_apply_styles()

func _on_game_over(reason: String) -> void:
	if run_stats_tracker != null:
		var death_reason := _normalized_death_reason(reason)
		run_stats_tracker.finalize_run("died", death_reason)
		_show_report(run_stats_tracker.stats, LocalRecords.update_with_run(run_stats_tracker.stats), "restart_level")
		return
	var stats := RunStats.new()
	stats.reset(RunStats.DEFAULT_EXPEDITION_NAME)
	stats.final_result = "died"
	stats.death_reason = _normalized_death_reason(reason)
	_show_report(stats, {}, "restart_level")


func _on_run_won() -> void:
	if has_next_level:
		if not show_level_complete_prompt:
			return
		_show_end_screen("Road complete!", "+%d Gold" % level_complete_gold_reward, "Open shop", "next_level")
	else:
		if run_stats_tracker != null:
			run_stats_tracker.finalize_run("won", "")
			_show_report(run_stats_tracker.stats, LocalRecords.update_with_run(run_stats_tracker.stats), "restart_level")
			return
		var stats := RunStats.new()
		stats.reset(RunStats.DEFAULT_EXPEDITION_NAME)
		stats.final_result = "won"
		_show_report(stats, {}, "restart_level")


func _show_end_screen(title: String, reward_text: String, button_text: String, action: String) -> void:
	_set_report_visible(false)
	if _title_label != null:
		_title_label.text = title
	if _reward_label != null:
		_reward_label.text = reward_text
		_reward_label.visible = not reward_text.is_empty()
	if _action_button != null:
		_action_button.text = button_text
	_action = action
	_secondary_action = ""
	if _secondary_button != null:
		_secondary_button.visible = false
	if _hand != null:
		_hand.visible = false
	visible = true


func _show_report(stats: RunStats, new_records: Dictionary, primary_action: String) -> void:
	if _run_finalized:
		return
	_run_finalized = true
	_set_report_visible(true)
	_title_label.text = "The %s Expedition" % stats.expedition_name
	_reward_label.visible = true
	_reward_label.text = _result_line(stats)
	_populate_stat_cards(stats, new_records)
	_action_button.text = "Try Again"
	_action = primary_action
	_secondary_button.text = "New Expedition"
	_secondary_action = "restart_game"
	_secondary_button.visible = true
	if _hand != null:
		_hand.visible = false
	visible = true


func _build_report_nodes() -> void:
	if _grid != null:
		return
	_grid = GridContainer.new()
	_grid.name = "StatGrid"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 16)
	_stack.add_child(_grid)
	_stack.move_child(_grid, _reward_label.get_index() + 1)

	_secondary_button = Button.new()
	_secondary_button.name = "NewExpeditionButton"
	_secondary_button.custom_minimum_size = Vector2(232, 58)
	_secondary_button.focus_mode = Control.FOCUS_NONE
	_secondary_button.pressed.connect(_on_secondary_button_pressed)
	_stack.add_child(_secondary_button)
	_stack.move_child(_secondary_button, _action_button.get_index() + 1)


func _apply_styles() -> void:
	if _panel != null:
		_panel.add_theme_stylebox_override("panel", UIStyle.menu_panel_style())
	if _stack != null:
		_stack.add_theme_constant_override("separation", 14)
	if _title_label != null:
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
		_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		_title_label.add_theme_constant_override("shadow_offset_x", 2)
		_title_label.add_theme_constant_override("shadow_offset_y", 3)
		_title_label.add_theme_font_size_override("font_size", 48)
	if _reward_label != null:
		_reward_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.26))
		_reward_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.96))
		_reward_label.add_theme_constant_override("shadow_offset_x", 2)
		_reward_label.add_theme_constant_override("shadow_offset_y", 3)
		_reward_label.add_theme_font_size_override("font_size", 38)
	if _action_button != null:
		_action_button.custom_minimum_size = Vector2(232, 58)
		_action_button.add_theme_font_size_override("font_size", 29)
		UIStyle.apply_menu_button_style(_action_button)
	if _secondary_button != null:
		_secondary_button.add_theme_font_size_override("font_size", 29)
		UIStyle.apply_menu_button_style(_secondary_button)


func _set_report_visible(report_visible: bool) -> void:
	if _grid != null:
		_grid.visible = report_visible


func _populate_stat_cards(stats: RunStats, new_records: Dictionary) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.free()
	for stat in _summary_stat_cards(stats):
		_grid.add_child(_make_stat_card(stat, new_records.get(str(stat["id"]), {})))


func _make_stat_card(stat: Dictionary, record: Dictionary) -> Control:
	var is_record := not record.is_empty()
	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(0.0, 126.0)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 0)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	var label := Label.new()
	label.text = str(stat["label"])
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.96))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 30)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(label)
	var value := Label.new()
	value.text = str(stat["value"])
	value.add_theme_color_override("font_color", Color(1.0, 0.98, 0.82))
	value.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	value.add_theme_constant_override("shadow_offset_x", 3)
	value.add_theme_constant_override("shadow_offset_y", 3)
	value.add_theme_font_size_override("font_size", 52)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(value)
	if is_record:
		var badge := Label.new()
		badge.text = "NEW RECORD"
		badge.add_theme_color_override("font_color", Color(1.0, 0.20, 0.08))
		badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.96))
		badge.add_theme_constant_override("shadow_offset_x", 2)
		badge.add_theme_constant_override("shadow_offset_y", 2)
		badge.add_theme_font_size_override("font_size", 21)
		stack.add_child(badge)
		if record.has("previous_value"):
			var old := Label.new()
			old.text = "Old: %s, by %s" % [str(record["previous_value"]), str(record.get("previous_expedition_name", "unknown"))]
			old.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50))
			old.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.90))
			old.add_theme_constant_override("shadow_offset_x", 1)
			old.add_theme_constant_override("shadow_offset_y", 2)
			old.add_theme_font_size_override("font_size", 18)
			old.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stack.add_child(old)
	return margin


func _summary_stat_cards(stats: RunStats) -> Array[Dictionary]:
	return [
		{"id": "highest_level_reached", "label": "Level", "value": str(stats.highest_level_reached)},
		{"id": "tiles_placed", "label": "Tiles", "value": str(stats.tiles_placed)},
		{"id": "cards_played", "label": "Cards", "value": str(stats.cards_played)},
		{"id": "food_spent", "label": "Food Spent", "value": str(stats.food_spent)},
		{"id": "enemies_defeated", "label": "Enemies", "value": str(stats.enemies_defeated)},
		{"id": "gold_gained", "label": "Gold Found", "value": str(stats.gold_gained)},
		{"id": "best_weapon_power", "label": "Best Weapon", "value": "%s +%d" % [stats.best_weapon_name, stats.best_weapon_power]},
		{"id": "distance_from_goal_on_death", "label": "From Goal", "value": "%d tiles" % stats.distance_from_goal_on_death},
	]


func _result_line(stats: RunStats) -> String:
	if stats.final_result == "won":
		return "Reached the final road"
	match stats.death_reason:
		"starvation":
			return "Ended by starvation on Level %d" % stats.highest_level_reached
		"death":
			return "Collapsed in the wilderness"
		"exhaustion":
			return "Buried under administrative card exhaustion"
		_:
			return "Filed as missing on Level %d" % stats.highest_level_reached


func _normalized_death_reason(reason: String) -> String:
	match reason:
		"food":
			return "starvation"
		"health":
			return "death"
		"exhaustion":
			return "exhaustion"
		_:
			return "unknown"


func _on_action_button_pressed() -> void:
	if _action == "next_level":
		next_level_requested.emit()
	elif _action == "restart_game":
		if restart_game_requested.get_connections().is_empty():
			get_tree().reload_current_scene()
		else:
			restart_game_requested.emit()
	else:
		if restart_level_requested.get_connections().is_empty():
			get_tree().reload_current_scene()
		else:
			restart_level_requested.emit()


func _on_secondary_button_pressed() -> void:
	if _secondary_action == "restart_game":
		restart_game_requested.emit()
