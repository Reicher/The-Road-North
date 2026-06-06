class_name GameOverUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

signal next_level_requested
signal restart_level_requested
signal restart_game_requested

@export var player_path: NodePath
@export var hand_path: NodePath = NodePath("../Hand")
@export var has_next_level := false

var _player: GamePlayer
var _hand: Control
var _panel: PanelContainer
var _title_label: Label
var _action_button: Button
var _ready_completed := false


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


func _draw() -> void:
	if visible:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.03, 0.52), true)


func _bind_scene_nodes() -> void:
	_panel = get_node("Prompt") as PanelContainer
	_title_label = get_node("Prompt/ContentMargin/Stack/Title") as Label
	_action_button = get_node("Prompt/ContentMargin/Stack/RestartButton") as Button
	_title_label.add_theme_color_override("font_color", UIStyle.text(self))
	if not _action_button.pressed.is_connected(_on_action_button_pressed):
		_action_button.pressed.connect(_on_action_button_pressed)

func _on_game_over(_reason: String) -> void:
	_show_end_screen("You lose", "Restart level", "restart_level")


func _on_run_won() -> void:
	if has_next_level:
		_show_end_screen("Nån typ av shop", "Next level", "next_level")
	else:
		_show_end_screen("You won", "Restart game", "restart_game")


func _show_end_screen(title: String, button_text: String, action: String) -> void:
	if _title_label != null:
		_title_label.text = title
	if _action_button != null:
		_action_button.text = button_text
		_action_button.set_meta("action", action)
	if _hand != null:
		_hand.visible = false
	visible = true
	queue_redraw()


func _on_action_button_pressed() -> void:
	var action := ""
	if _action_button != null:
		action = str(_action_button.get_meta("action", ""))
	if action == "next_level":
		next_level_requested.emit()
	elif action == "restart_game":
		if restart_game_requested.get_connections().is_empty():
			get_tree().reload_current_scene()
		else:
			restart_game_requested.emit()
	else:
		if restart_level_requested.get_connections().is_empty():
			get_tree().reload_current_scene()
		else:
			restart_level_requested.emit()
