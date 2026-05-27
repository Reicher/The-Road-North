class_name GameOverUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")

@export var player_path: NodePath

var _player: GamePlayer
var _panel: PanelContainer
var _restart_button: Button
var _ready_completed := false


func _ready() -> void:
	if _ready_completed:
		return
	_ready_completed = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player = get_node_or_null(player_path) as GamePlayer
	if _player != null and not _player.game_over.is_connected(_on_game_over):
		_player.game_over.connect(_on_game_over)
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
	margin.add_child(stack)

	var title := Label.new()
	title.name = "Title"
	title.text = "Game over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UIStyle.text(self))
	stack.add_child(title)

	_restart_button = Button.new()
	_restart_button.name = "RestartButton"
	_restart_button.text = "Restart"
	_restart_button.focus_mode = Control.FOCUS_NONE
	_restart_button.custom_minimum_size = Vector2(144.0, 48.0)
	_restart_button.pressed.connect(_restart_level)
	stack.add_child(_restart_button)

	resized.connect(_layout_overlay)
	_layout_overlay()


func _layout_overlay() -> void:
	if _panel == null:
		return
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_panel.position = (size - panel_size) * 0.5


func _on_game_over(_reason: String) -> void:
	visible = true
	queue_redraw()
	_layout_overlay()


func _restart_level() -> void:
	get_tree().reload_current_scene()
