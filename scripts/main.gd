extends Node

const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://levels/level_001.tscn"),
	preload("res://levels/level_002.tscn"),
]

var _current_level_index := 0
var _current_level: Node


func _ready() -> void:
	_load_level(0)


func _load_level(level_index: int) -> void:
	if _current_level != null:
		remove_child(_current_level)
		_current_level.queue_free()

	_current_level_index = clampi(level_index, 0, LEVEL_SCENES.size() - 1)
	_current_level = LEVEL_SCENES[_current_level_index].instantiate()
	_current_level.name = "Level"
	add_child(_current_level)
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


func _on_next_level_requested() -> void:
	_load_level(_current_level_index + 1)


func _on_restart_level_requested() -> void:
	_load_level(_current_level_index)


func _on_restart_game_requested() -> void:
	_load_level(0)
