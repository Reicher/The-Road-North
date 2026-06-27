class_name Level
extends Node

signal goal_arrival_finished

const TouchFeedback = preload("res://scripts/touch_feedback.gd")

enum RunState {
	IDLE,
	CARD_FOCUSED,
	PLACEMENT_MODE,
	EVENT_TARGETING,
	PLAYER_MOVING,
	GAME_OVER,
	RUN_WON,
}

@export var hand_path: NodePath = NodePath("UI/Hand")
@export var placement_controller_path: NodePath = NodePath("PlacementController")
@export var player_path: NodePath = NodePath("Player")
@export var encounter_ui_path: NodePath = NodePath("UI/Encounter")
@export var camera_path: NodePath = NodePath("Camera3D")
@export var level_name_label_path: NodePath = NodePath("UI/LevelName")
@export var map_path: NodePath = NodePath("Map")
@export var chapter_title := ""
@export var level_number := 1
@export var level_name := ""
@export_range(0.0, 8.0, 0.1) var level_name_hold_after_zoom_started := 2.0
@export_range(0.0, 2.0, 0.05) var level_name_fade_duration := 0.45
@export_range(0.0, 2.0, 0.05) var intro_ui_reveal_duration := 0.28
@export_range(0.0, 2.0, 0.05) var goal_arrival_pause := 0.42

var state := RunState.IDLE

var _map: GameMap
var _hand: HandUI
var _placement_controller: PlacementController
var _player: GamePlayer
var _encounter_ui: Control
var _camera: Camera3D
var _level_name_label: Label
var _level_name_tween: Tween
var _intro_running := false
var _intro_finished := false
var _goal_arrival_running := false
var _ui_intro_states: Dictionary = {}


func _ready() -> void:
	_hand = get_node_or_null(hand_path) as HandUI
	_placement_controller = get_node_or_null(placement_controller_path) as PlacementController
	_player = get_node_or_null(player_path) as GamePlayer
	_encounter_ui = get_node_or_null(encounter_ui_path) as Control
	_camera = get_node_or_null(camera_path) as Camera3D
	_level_name_label = get_node_or_null(level_name_label_path) as Label
	_map = get_node_or_null(map_path) as GameMap
	_setup_level_name_intro()
	if _should_play_intro_sequence():
		_prepare_level_intro_state()

	if _hand == null:
		push_warning("Level needs a HandUI at hand_path.")
	else:
		_connect_hand()

	if _placement_controller == null:
		push_warning("Level needs a PlacementController at placement_controller_path.")
	else:
		_connect_placement_controller()

	if _player == null:
		push_warning("Level needs a GamePlayer at player_path.")
	else:
		_connect_player()
	TouchFeedback.apply_to_tree(get_node_or_null("UI"))

	if _should_play_intro_sequence():
		call_deferred("_play_level_intro_sequence")


func _exit_tree() -> void:
	if _level_name_tween != null:
		_level_name_tween.kill()


func _setup_level_name_intro() -> void:
	if _level_name_label == null:
		return
	_level_name_label.text = _level_intro_text()
	_level_name_label.modulate.a = 1.0
	_level_name_label.visible = not _level_name_label.text.is_empty()
	if _camera != null and _camera.has_signal("start_zoom_started"):
		_camera.connect("start_zoom_started", _fade_out_level_name)


func _level_intro_text() -> String:
	var lines: Array[String] = []
	lines.append("%s - %d" % [_chapter_roman(), level_number])
	var display_name := level_name if not level_name.is_empty() else "Bana %d" % level_number
	lines.append(display_name)
	return "\n".join(lines)


func _should_play_intro_sequence() -> bool:
	var parent := get_parent()
	return parent != null and parent.name == "Main"


func _chapter_roman() -> String:
	var stripped_title := chapter_title.strip_edges()
	if stripped_title.begins_with("Kapitel "):
		var parts := stripped_title.split(" ", false)
		if parts.size() >= 2:
			return str(parts[1])
	return _to_roman(maxi(1, level_number))


func _to_roman(value: int) -> String:
	var remaining := value
	var result := ""
	var numerals := [
		[10, "X"],
		[9, "IX"],
		[5, "V"],
		[4, "IV"],
		[1, "I"],
	]
	for numeral in numerals:
		var amount := int(numeral[0])
		while remaining >= amount:
			result += str(numeral[1])
			remaining -= amount
	return result


func _fade_out_level_name() -> void:
	if _level_name_label == null or not _level_name_label.visible:
		return
	if _level_name_tween != null:
		_level_name_tween.kill()
	_level_name_tween = create_tween()
	_level_name_tween.set_trans(Tween.TRANS_SINE)
	_level_name_tween.set_ease(Tween.EASE_OUT)
	if level_name_hold_after_zoom_started > 0.0:
		_level_name_tween.tween_interval(level_name_hold_after_zoom_started)
	_level_name_tween.tween_property(_level_name_label, "modulate:a", 0.0, level_name_fade_duration)
	_level_name_tween.tween_callback(_level_name_label.hide)


func _prepare_level_intro_state() -> void:
	_intro_running = true
	_intro_finished = false
	_set_player_input_enabled(false)
	if _hand != null:
		_hand.interaction_enabled = false
		_hand.visible = false
	if _player != null:
		_player.visible = false
	var ui := get_node_or_null("UI")
	if ui != null:
		for child in ui.get_children():
			if child == _level_name_label:
				continue
			if child is Control:
				var control := child as Control
				_ui_intro_states[control] = {
					"position": control.position,
					"visible": control.visible,
				}
				control.modulate.a = 0.0


func _play_level_intro_sequence() -> void:
	if not is_inside_tree() or _intro_finished:
		return
	_prepare_level_intro_state()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if _camera != null and _camera.has_signal("start_zoom_finished"):
		await _camera.start_zoom_finished
	else:
		await get_tree().create_timer(0.2).timeout
	if not is_inside_tree():
		return
	await _reveal_player_and_ui()
	if not is_inside_tree():
		return
	_intro_running = false
	_intro_finished = true
	_set_player_input_enabled(true)
	if _hand != null:
		_hand.interaction_enabled = true


func _reveal_player_and_ui() -> void:
	if _player != null:
		_player.visible = true
		_player.scale = Vector3(0.88, 0.88, 0.88)
		var player_tween := create_tween()
		player_tween.set_trans(Tween.TRANS_BACK)
		player_tween.set_ease(Tween.EASE_OUT)
		player_tween.tween_property(_player, "scale", Vector3.ONE, 0.22)
		await player_tween.finished
	if not is_inside_tree():
		return
	var ui_tween := create_tween()
	ui_tween.set_parallel(true)
	ui_tween.set_trans(Tween.TRANS_SINE)
	ui_tween.set_ease(Tween.EASE_OUT)
	for node_variant in _ui_intro_states.keys():
		var control := node_variant as Control
		if control == null or not is_instance_valid(control):
			continue
		var state: Dictionary = _ui_intro_states.get(control, {})
		var was_visible := bool(state.get("visible", true))
		control.visible = was_visible
		if not was_visible:
			control.modulate.a = 1.0
			continue
		var base_position: Vector2 = state.get("position", control.position)
		control.position = base_position + Vector2(0.0, 18.0)
		ui_tween.tween_property(control, "modulate:a", 1.0, intro_ui_reveal_duration)
		ui_tween.tween_property(control, "position", base_position, intro_ui_reveal_duration)
	if _hand != null:
		_hand.visible = true
		_hand.modulate.a = 0.0
		var hand_state: Dictionary = _ui_intro_states.get(_hand, {})
		var hand_base_position: Vector2 = hand_state.get("position", _hand.position)
		_hand.position = hand_base_position + Vector2(0.0, 34.0)
		ui_tween.tween_property(_hand, "modulate:a", 1.0, intro_ui_reveal_duration)
		ui_tween.tween_property(_hand, "position", hand_base_position, intro_ui_reveal_duration)
	await ui_tween.finished


func _connect_hand() -> void:
	if not _hand.card_focused.is_connected(_on_card_focused):
		_hand.card_focused.connect(_on_card_focused)
	if not _hand.card_unfocused.is_connected(_on_card_unfocused):
		_hand.card_unfocused.connect(_on_card_unfocused)


func _connect_placement_controller() -> void:
	if not _placement_controller.placement_started.is_connected(_on_placement_started):
		_placement_controller.placement_started.connect(_on_placement_started)
	if not _placement_controller.placement_cancelled.is_connected(_on_placement_ended):
		_placement_controller.placement_cancelled.connect(_on_placement_ended)
	for resolved_signal in [
		_placement_controller.placement_confirmed,
		_placement_controller.tile_destroyed,
		_placement_controller.tile_rotated,
		_placement_controller.encounter_changed,
	]:
		if not resolved_signal.is_connected(_on_placement_resolved):
			resolved_signal.connect(_on_placement_resolved)


func _connect_player() -> void:
	if not _player.move_started.is_connected(_on_player_move_started):
		_player.move_started.connect(_on_player_move_started)
	if not _player.moved.is_connected(_on_player_moved):
		_player.moved.connect(_on_player_moved)
	if not _player.move_failed.is_connected(_on_player_moved):
		_player.move_failed.connect(_on_player_moved)
	if not _player.game_over.is_connected(_on_game_over):
		_player.game_over.connect(_on_game_over)
	if not _player.run_won.is_connected(_on_run_won):
		_player.run_won.connect(_on_run_won)
	if not _player.permanent_encounter_reached.is_connected(_on_permanent_encounter_reached):
		_player.permanent_encounter_reached.connect(_on_permanent_encounter_reached)
	if _encounter_ui != null and not _encounter_ui.closed.is_connected(_on_encounter_closed):
		_encounter_ui.closed.connect(_on_encounter_closed)


func _on_card_focused(_card: CardView) -> void:
	if not _is_terminal_state():
		state = RunState.CARD_FOCUSED


func _on_card_unfocused() -> void:
	if state == RunState.CARD_FOCUSED:
		state = RunState.IDLE


func _on_placement_started(card: CardView) -> void:
	if _is_terminal_state():
		return
	_set_player_input_enabled(false)
	if card.event_type in GameConstants.TARGETED_EVENT_TYPES:
		state = RunState.EVENT_TARGETING
	else:
		state = RunState.PLACEMENT_MODE


func _on_placement_ended(_card: CardView) -> void:
	if _is_terminal_state():
		return
	state = RunState.IDLE
	_set_player_input_enabled(true)


func _on_placement_resolved(_grid_position: Vector2i, _card: CardView) -> void:
	if _is_terminal_state():
		return
	state = RunState.IDLE
	_set_player_input_enabled(true)
	if _player != null:
		_player.refresh_enemy_risk_colors()


func _on_player_move_started(_target_position: Vector2i) -> void:
	if _is_terminal_state():
		return
	state = RunState.PLAYER_MOVING
	_set_player_input_enabled(true)


func _on_player_moved(_grid_position: Vector2i) -> void:
	if _is_terminal_state():
		return
	state = RunState.IDLE
	_set_player_input_enabled(true)


func _on_permanent_encounter_reached(_grid_position: Vector2i, encounter: Dictionary) -> void:
	if _is_terminal_state() or _encounter_ui == null:
		return
	_set_player_input_enabled(false)
	_encounter_ui.open(encounter)


func _on_encounter_closed() -> void:
	if not _is_terminal_state():
		_set_player_input_enabled(true)
		_player.continue_route_after_encounter()


func _on_game_over(_reason: String) -> void:
	state = RunState.GAME_OVER
	_set_player_input_enabled(false)


func _on_run_won() -> void:
	state = RunState.RUN_WON
	_set_player_input_enabled(false)
	if _player == null or not bool(_player.get("_moving")):
		goal_arrival_finished.emit()
		return
	_play_goal_arrival_sequence()


func _is_terminal_state() -> bool:
	return state == RunState.GAME_OVER or state == RunState.RUN_WON


func _set_player_input_enabled(enabled: bool) -> void:
	if _player != null:
		_player.input_enabled = enabled and not _intro_running and not _goal_arrival_running


func _play_goal_arrival_sequence() -> void:
	if _goal_arrival_running:
		return
	_goal_arrival_running = true
	_set_player_input_enabled(false)
	if _map != null:
		_map.flash_tile(_map.get_goal_position())
	var roads := get_node_or_null("Roads") as Roads
	var goal_tile := roads.get_visual_tile(_map.get_goal_position()) if roads != null and _map != null else null
	var goal_tween: Tween
	if goal_tile != null:
		goal_tween = create_tween()
		goal_tween.set_trans(Tween.TRANS_SINE)
		goal_tween.set_ease(Tween.EASE_IN_OUT)
		goal_tween.tween_property(goal_tile, "scale", Vector3(1.045, 1.045, 1.045), 0.18)
		goal_tween.tween_interval(goal_arrival_pause)
		goal_tween.tween_property(goal_tile, "scale", Vector3.ONE, 0.22)
		await goal_tween.finished
	else:
		await get_tree().create_timer(goal_arrival_pause).timeout
	if not is_inside_tree():
		return
	_goal_arrival_running = false
	goal_arrival_finished.emit()
