class_name Level
extends Node2D

enum RunState {
	IDLE,
	CARD_FOCUSED,
	PLACEMENT_MODE,
	EVENT_TARGETING,
	GAME_OVER,
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
	if not _placement_controller.placement_confirmed.is_connected(_on_placement_confirmed):
		_placement_controller.placement_confirmed.connect(_on_placement_confirmed)
	if not _placement_controller.tile_destroyed.is_connected(_on_tile_destroyed):
		_placement_controller.tile_destroyed.connect(_on_tile_destroyed)


func _connect_player() -> void:
	if not _player.moved.is_connected(_on_player_moved):
		_player.moved.connect(_on_player_moved)
	if not _player.game_over.is_connected(_on_game_over):
		_player.game_over.connect(_on_game_over)


func _on_card_focused(_card: CardView) -> void:
	if state != RunState.GAME_OVER:
		state = RunState.CARD_FOCUSED


func _on_card_unfocused() -> void:
	if state == RunState.CARD_FOCUSED:
		state = RunState.IDLE


func _on_placement_started(card: CardView) -> void:
	if state == RunState.GAME_OVER:
		return
	if card.event_type == DeckController.EVENT_DESTROY_NEIGHBOR:
		state = RunState.EVENT_TARGETING
	else:
		state = RunState.PLACEMENT_MODE


func _on_placement_ended(_card: CardView) -> void:
	if state != RunState.GAME_OVER:
		state = RunState.IDLE


func _on_placement_confirmed(_grid_position: Vector2i, _card: CardView) -> void:
	if state != RunState.GAME_OVER:
		state = RunState.IDLE


func _on_tile_destroyed(_grid_position: Vector2i, _card: CardView) -> void:
	if state != RunState.GAME_OVER:
		state = RunState.IDLE


func _on_player_moved(_grid_position: Vector2i) -> void:
	if state != RunState.GAME_OVER:
		state = RunState.IDLE


func _on_game_over(_reason: String) -> void:
	state = RunState.GAME_OVER
