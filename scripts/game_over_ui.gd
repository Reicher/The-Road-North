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
	_build_overlay()


func _gui_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		accept_event()
	elif visible and event is InputEventScreenTouch:
		accept_event()


func _draw() -> void:
	if visible:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.03, 0.52), true)


func _build_overlay() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Prompt"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)

	var top_spacer := Control.new()
	top_spacer.name = "TopSpacer"
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(top_spacer)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Game over"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", UIStyle.text(self))
	stack.add_child(_title_label)

	var bottom_spacer := Control.new()
	bottom_spacer.name = "BottomSpacer"
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(bottom_spacer)

	_action_button = Button.new()
	_action_button.name = "RestartButton"
	_action_button.text = "Restart"
	_action_button.focus_mode = Control.FOCUS_NONE
	_action_button.custom_minimum_size = Vector2(188.0, 52.0)
	_action_button.pressed.connect(_on_action_button_pressed)
	stack.add_child(_action_button)

	resized.connect(_layout_overlay)
	_layout_overlay()


func _layout_overlay() -> void:
	if _panel == null:
		return
	_panel.size = size
	_panel.position = Vector2.ZERO


func _on_game_over(_reason: String) -> void:
	_show_end_screen("You loose", "Restart level", "restart_level")


func _on_run_won() -> void:
	if has_next_level:
		_show_end_screen("Level completed", "Next level", "next_level")
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
	_layout_overlay()


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
