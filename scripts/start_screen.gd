class_name StartScreen
extends Control

signal play_requested

const AUTHOR_TEXT := "A game by Robin Reicher"
const GAME_TITLE := "Road To Karlskoga"

var _intro_tween: Tween

@onready var _author_label := $AuthorLabel as Label
@onready var _title_group := $Content as VBoxContainer
@onready var _menu_buttons := $Content/MenuButtons as VBoxContainer
@onready var _information := $Content/Information as VBoxContainer
@onready var _information_heading := $Content/Information/Heading as Label
@onready var _information_body := $Content/Information/Body as Label


func _ready() -> void:
	_author_label.text = AUTHOR_TEXT
	$Content/Title.text = GAME_TITLE
	$Content/MenuButtons/PlayButton.pressed.connect(play_requested.emit)
	$Content/MenuButtons/HowToPlayButton.pressed.connect(_show_how_to_play)
	$Content/MenuButtons/SettingsButton.pressed.connect(_show_settings)
	$Content/MenuButtons/AboutButton.pressed.connect(_show_about)
	$Content/Information/BackButton.pressed.connect(_hide_information)
	_start_intro()


func finish_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_author_label.hide()
	_title_group.modulate.a = 1.0
	_title_group.show()
	_menu_buttons.modulate.a = 1.0
	_set_menu_enabled(true)


func _start_intro() -> void:
	_author_label.modulate.a = 0.0
	_title_group.modulate.a = 0.0
	_title_group.show()
	_menu_buttons.modulate.a = 0.0
	_set_menu_enabled(false)

	_intro_tween = create_tween()
	_intro_tween.tween_property(_author_label, "modulate:a", 1.0, 0.8)
	_intro_tween.tween_interval(0.9)
	_intro_tween.tween_property(_author_label, "modulate:a", 0.0, 0.65)
	_intro_tween.tween_callback(_author_label.hide)
	_intro_tween.tween_property(_title_group, "modulate:a", 1.0, 0.8)
	_intro_tween.tween_interval(0.18)
	_intro_tween.tween_property(_menu_buttons, "modulate:a", 1.0, 0.45)
	_intro_tween.tween_callback(_set_menu_enabled.bind(true))


func _set_menu_enabled(enabled: bool) -> void:
	for child in _menu_buttons.get_children():
		if child is Button:
			(child as Button).disabled = not enabled


func _show_how_to_play() -> void:
	_show_information(
		"How to play",
		"Build connected roads from the camp to Karlskoga. Tap reachable road tiles to move. Each step costs 1 food, so plan your route carefully."
	)


func _show_settings() -> void:
	_show_information("Settings", "Settings will be available in a later version.")


func _show_about() -> void:
	_show_information(
		"About the game",
		"A calm, tactical road-building game by Robin Reicher. This is an early playable prototype."
	)


func _show_information(heading: String, body: String) -> void:
	_information_heading.text = heading
	_information_body.text = body
	_menu_buttons.hide()
	_information.show()


func _hide_information() -> void:
	_information.hide()
	_menu_buttons.show()
