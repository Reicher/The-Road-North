class_name CombatOverlay
extends Control

const ROLL_STEP_DURATION := 0.07
const UIStyle = preload("res://scripts/ui_style.gd")
const TEXT_COLOR := Color(0.16, 0.11, 0.07)
const DEFEAT_COLOR := Color(0.68, 0.20, 0.16)
const VICTORY_COLOR := Color(0.25, 0.55, 0.16)
const TIE_COLOR := Color(0.45, 0.32, 0.20)

signal fight_pressed
signal retreat_pressed
signal ok_pressed

var _rng := RandomNumberGenerator.new()
var _rolling := false
var _roll_elapsed := 0.0
var _player_power := 0
var _enemy_power := 0
var _player_die: Control
var _enemy_die: Control
var _player_sum_label: Label
var _enemy_sum_label: Label
var _result_label: Label
var _result_detail_label: Label
var _fight_button: Button
var _retreat_button: Button
var _ok_button: Button


func _ready() -> void:
	_player_die = $Panel/Margin/Stack/Calculation/Fighters/Player/DiceRow/Dice as Control
	_enemy_die = $Panel/Margin/Stack/Calculation/Fighters/Enemy/Dice as Control
	_player_sum_label = $Panel/Margin/Stack/Totals/PlayerSum as Label
	_enemy_sum_label = $Panel/Margin/Stack/Totals/EnemySum as Label
	_result_label = $Panel/Margin/Stack/Totals/Result as Label
	_result_detail_label = $Panel/Margin/Stack/Totals/ResultDetail as Label
	_fight_button = $Panel/Margin/Stack/Buttons/FightButton as Button
	_retreat_button = $Panel/Margin/Stack/Buttons/RetreatButton as Button
	_ok_button = $Panel/Margin/Stack/OKButton as Button
	_fight_button.pressed.connect(func() -> void: fight_pressed.emit())
	_retreat_button.pressed.connect(func() -> void: retreat_pressed.emit())
	_ok_button.pressed.connect(func() -> void: ok_pressed.emit())
	_rng.randomize()
	_apply_styles()
	set_process(false)


func open_preview(player_power: int, enemy_power: int, risk_level: String) -> void:
	_player_power = player_power
	_enemy_power = enemy_power
	($TitleBanner/Title as Label).text = "%s Fight" % risk_level
	($Panel/Margin/Stack/Calculation/Fighters/Player/Power/Value as Label).text = str(player_power)
	($Panel/Margin/Stack/Calculation/Fighters/Enemy/Power/Value as Label).text = str(enemy_power)
	_set_roll_text("?", "?")
	_result_label.text = ""
	_result_detail_label.text = ""
	_set_result_color(TEXT_COLOR)
	$Panel/Margin/Stack/Buttons.visible = true
	_set_fight_buttons(true)
	_ok_button.visible = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func start_rolling() -> void:
	_rolling = true
	_roll_elapsed = 0.0
	_set_fight_buttons(false)
	_result_label.text = ""
	_result_detail_label.text = ""
	set_process(true)


func show_round_result(player_roll: int, enemy_roll: int, result: String, victory: bool) -> void:
	_rolling = false
	set_process(false)
	_set_roll_text(str(player_roll), str(enemy_roll))
	_player_sum_label.text = str(_player_power + player_roll)
	_enemy_sum_label.text = str(_enemy_power + enemy_roll)
	_result_label.text = result
	_result_detail_label.text = "-1 HP" if result == "Defeat" else ""
	_set_result_color(VICTORY_COLOR if victory else DEFEAT_COLOR if result == "Defeat" else TIE_COLOR)
	_set_fight_buttons(not victory)
	$Panel/Margin/Stack/Buttons.visible = not victory
	_ok_button.visible = victory
	_ok_button.disabled = victory


func enable_ok() -> void:
	_ok_button.disabled = false


func close() -> void:
	_rolling = false
	set_process(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_label.text = ""
	_result_detail_label.text = ""


func _process(delta: float) -> void:
	if not _rolling:
		return
	_roll_elapsed += delta
	if _roll_elapsed >= ROLL_STEP_DURATION:
		_roll_elapsed = fposmod(_roll_elapsed, ROLL_STEP_DURATION)
		_set_roll_text(str(_rng.randi_range(1, 6)), str(_rng.randi_range(1, 6)))


func _set_roll_text(player_roll: String, enemy_roll: String) -> void:
	_player_die.call("set_value", 0 if player_roll == "?" else int(player_roll))
	_enemy_die.call("set_value", 0 if enemy_roll == "?" else int(enemy_roll))
	_player_sum_label.text = "?" if player_roll == "?" else str(_player_power + int(player_roll))
	_enemy_sum_label.text = "?" if enemy_roll == "?" else str(_enemy_power + int(enemy_roll))


func _set_fight_buttons(enabled: bool) -> void:
	_fight_button.disabled = not enabled
	_retreat_button.disabled = not enabled


func _apply_styles() -> void:
	var panel := $Panel as PanelContainer
	var title_banner := $TitleBanner as PanelContainer
	panel.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, Color(0.95, 0.91, 0.82), Color(0.20, 0.16, 0.12), 24, 4))
	title_banner.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, Color(0.76, 0.38, 0.33), Color(0.38, 0.20, 0.16), 8, 2))
	_style_button(_fight_button, Color(0.16, 0.36, 0.49), Color(0.10, 0.22, 0.29), Color(0.24, 0.47, 0.60))
	_style_button(_retreat_button, Color(0.80, 0.72, 0.58), Color(0.34, 0.25, 0.17), Color(0.88, 0.81, 0.68))
	_style_button(_ok_button, Color(0.40, 0.61, 0.19), Color(0.22, 0.35, 0.10), Color(0.51, 0.72, 0.27))
	_set_result_color(TEXT_COLOR)


func _style_button(button: Button, fill: Color, border: Color, hover: Color) -> void:
	button.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.59, 0.52))
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", UIStyle.elevated_box(self, fill, border, 10, 3))
	button.add_theme_stylebox_override("hover", UIStyle.elevated_box(self, hover, border, 10, 3))
	button.add_theme_stylebox_override("pressed", UIStyle.rounded_box(self, fill.darkened(0.15), border, 10, 3))
	button.add_theme_stylebox_override("disabled", UIStyle.rounded_box(self, fill.darkened(0.28), border.darkened(0.18), 10, 3))


func _set_result_color(color: Color) -> void:
	_result_label.add_theme_color_override("font_color", color)
	_result_detail_label.add_theme_color_override("font_color", color)
