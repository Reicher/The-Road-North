class_name StartScreen
extends Control

signal play_requested

const TouchFeedback = preload("res://scripts/touch_feedback.gd")
const UIStyle = preload("res://scripts/ui_style.gd")

const AUTHOR_TEXT := "A game by Robin Reicher"
const GAME_TITLE := "Road to Karlskoga"

var _intro_tween: Tween
var _intro_finished := false

@onready var _author_label := $AuthorLabel as Label
@onready var _intro_hint := $IntroHint as Label
@onready var _title_group := $Content as Control
@onready var _menu_buttons := $Content/MenuButtons as VBoxContainer
@onready var _information := $Content/Information as PanelContainer
@onready var _information_heading := $Content/Information/Margin/Stack/Heading as Label
@onready var _information_body := $Content/Information/Margin/Stack/Body as Label


func _ready() -> void:
	_apply_menu_frame_styles()
	_author_label.text = AUTHOR_TEXT
	$Content/Title.text = GAME_TITLE
	$Content/MenuButtons/PlayButton.pressed.connect(play_requested.emit)
	$Content/MenuButtons/HowToPlayButton.pressed.connect(_show_how_to_play)
	$Content/MenuButtons/SettingsButton.pressed.connect(_show_settings)
	$Content/MenuButtons/AboutButton.pressed.connect(_show_about)
	$Content/Information/Margin/Stack/BackButton.pressed.connect(_hide_information)
	TouchFeedback.apply_to_tree(self)
	_start_intro()


func _apply_menu_frame_styles() -> void:
	_information.add_theme_stylebox_override("panel", UIStyle.menu_panel_style())
	for child in _menu_buttons.get_children():
		if child is Button:
			UIStyle.apply_menu_button_style(child as Button)
	UIStyle.apply_menu_button_style($Content/Information/Margin/Stack/BackButton as Button)


func _input(event: InputEvent) -> void:
	if _intro_finished:
		if event.is_action_pressed("ui_cancel") and _information.visible:
			_hide_information()
			get_viewport().set_input_as_handled()
		return
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo):
		finish_intro()
		get_viewport().set_input_as_handled()


func finish_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_finished = true
	_author_label.hide()
	_intro_hint.hide()
	_title_group.modulate.a = 1.0
	_title_group.show()
	_menu_buttons.modulate.a = 1.0
	_set_menu_enabled(true)


func _start_intro() -> void:
	_intro_finished = false
	_author_label.modulate.a = 0.0
	_intro_hint.modulate.a = 0.0
	_intro_hint.show()
	_title_group.modulate.a = 0.0
	_title_group.show()
	_menu_buttons.modulate.a = 0.0
	_set_menu_enabled(false)

	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_SINE)
	_intro_tween.set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(_author_label, "modulate:a", 1.0, 0.65)
	_intro_tween.parallel().tween_property(_intro_hint, "modulate:a", 0.72, 0.65)
	_intro_tween.tween_interval(0.75)
	_intro_tween.tween_property(_author_label, "modulate:a", 0.0, 0.55)
	_intro_tween.parallel().tween_property(_intro_hint, "modulate:a", 0.0, 0.35)
	_intro_tween.tween_callback(_author_label.hide)
	_intro_tween.tween_callback(_intro_hint.hide)
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(_title_group, "modulate:a", 1.0, 0.75)
	_intro_tween.set_parallel(false)
	_intro_tween.tween_interval(0.18)
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(_menu_buttons, "modulate:a", 1.0, 0.38)
	_intro_tween.set_parallel(false)
	_intro_tween.tween_callback(_set_menu_enabled.bind(true))
	_intro_tween.tween_callback(func() -> void: _intro_finished = true)


func _set_menu_enabled(enabled: bool) -> void:
	for child in _menu_buttons.get_children():
		if child is Button:
			(child as Button).disabled = not enabled


func _show_how_to_play() -> void:
	_show_information(
		"How to play",
		"Build connected roads from the camp to Karlskoga.\n\nSelect a reachable road tile, then confirm to move. Every step costs 1 food.\n\nPlace cards carefully: roads must connect, and your supplies are limited."
	)


func _show_settings() -> void:
	_show_information("Settings", "There are no adjustable settings in this prototype yet.\n\nSound, display and accessibility options will appear here as development continues.")


func _show_about() -> void:
	_show_information(
		"About the game",
		"Road to Karlskoga is a calm, tactical road-building game about finding a way forward with limited supplies.\n\nDesigned and created by Robin Reicher.\nEarly playable prototype."
	)


func _show_information(heading: String, body: String) -> void:
	_information_heading.text = heading
	_information_body.text = body
	_menu_buttons.hide()
	_information.modulate.a = 0.0
	_information.show()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_information, "modulate:a", 1.0, 0.16)


func _hide_information() -> void:
	_information.hide()
	_menu_buttons.show()
