extends Node

const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://levels/level_001.tscn"),
	preload("res://levels/level_002.tscn"),
]

const DEBUG_LABEL_TEXT := "debugg"

var _current_level_index := 0
var _current_level: Node
var _debug_mode_enabled := false
var _debug_layer: CanvasLayer
var _debug_label: Label


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
		_load_level(0)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_2:
		_load_level(1)
		get_viewport().set_input_as_handled()


func _load_level(level_index: int) -> void:
	if _current_level != null:
		remove_child(_current_level)
		_current_level.queue_free()

	_current_level_index = clampi(level_index, 0, LEVEL_SCENES.size() - 1)
	_current_level = LEVEL_SCENES[_current_level_index].instantiate()
	_current_level.name = "Level"
	add_child(_current_level)
	var level := _current_level as Level
	if level != null and not level.restart_requested.is_connected(_on_restart_level_requested):
		level.restart_requested.connect(_on_restart_level_requested)
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
	_debug_label.add_theme_font_size_override("font_size", 10)
	_debug_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_debug_label.position = Vector2(6.0, -18.0)
	_debug_layer.add_child(_debug_label)


func _set_debug_mode_enabled(enabled: bool) -> void:
	_debug_mode_enabled = enabled
	if _debug_label != null:
		_debug_label.visible = _debug_mode_enabled


func _on_next_level_requested() -> void:
	_load_level(_current_level_index + 1)


func _on_restart_level_requested() -> void:
	_load_level(_current_level_index)


func _on_restart_game_requested() -> void:
	_load_level(0)
