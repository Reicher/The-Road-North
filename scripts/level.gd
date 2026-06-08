class_name Level
extends Node

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

var state := RunState.IDLE

var _hand: HandUI
var _placement_controller: PlacementController
var _player: GamePlayer


func _ready() -> void:
	_hand = get_node_or_null(hand_path) as HandUI
	_placement_controller = get_node_or_null(placement_controller_path) as PlacementController
	_player = get_node_or_null(player_path) as GamePlayer

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
	if not _player.game_over.is_connected(_on_game_over):
		_player.game_over.connect(_on_game_over)
	if not _player.run_won.is_connected(_on_run_won):
		_player.run_won.connect(_on_run_won)


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


func _on_player_move_started(_target_position: Vector2i) -> void:
	if _is_terminal_state():
		return
	state = RunState.PLAYER_MOVING
	_set_player_input_enabled(false)


func _on_player_moved(_grid_position: Vector2i) -> void:
	if _is_terminal_state():
		return
	state = RunState.IDLE
	_set_player_input_enabled(true)


func _on_game_over(_reason: String) -> void:
	state = RunState.GAME_OVER
	_set_player_input_enabled(false)


func _on_run_won() -> void:
	state = RunState.RUN_WON
	_set_player_input_enabled(false)


func _is_terminal_state() -> bool:
	return state == RunState.GAME_OVER or state == RunState.RUN_WON


func _set_player_input_enabled(enabled: bool) -> void:
	if _player != null:
		_player.input_enabled = enabled
