class_name DeckController
extends Node

const ROAD_CATEGORY := "Road"
const EVENT_CATEGORY := "Event"
const EVENT_DESTROY_TILE := "destroy_tile"
const EVENT_DRAW_TWO := "draw_two"
const EVENT_ROTATE_TILE := "rotate_tile"
const EVENT_LUCKY_FIND := "lucky_find"

const ROAD_CARD_RATIO := 0.75
const ENEMY_ROAD_CARD_RATIO := 0.20
const REWARD_ROAD_CARD_RATIO := 0.15
const HAND_SIZE := 4

const ROAD_DISTRIBUTION := {
	"straight": 30.0,
	"corner": 30.0,
	"t_junction": 20.0,
	"four_way": 10.0,
	"dead_end": 10.0,
}

@export var map_path: NodePath
@export var hand_path: NodePath
@export var player_path: NodePath
@export var deck_builder_path: NodePath = NodePath("DeckBuilder")
@export var hand_size := HAND_SIZE
@export var shuffle_seed := 0
@export_range(0.0, 1.0, 0.01) var road_card_ratio := ROAD_CARD_RATIO
@export_range(0.0, 1.0, 0.01) var enemy_road_card_ratio := ENEMY_ROAD_CARD_RATIO
@export_range(0.0, 1.0, 0.01) var reward_road_card_ratio := REWARD_ROAD_CARD_RATIO
@export var level := 1
@export var road_distribution := ROAD_DISTRIBUTION.duplicate()

@export var straight_definition: Resource = preload("res://data/road_straight.tres")
@export var corner_definition: Resource = preload("res://data/road_corner.tres")
@export var t_junction_definition: Resource = preload("res://data/road_t_junction.tres")
@export var four_way_definition: Resource = preload("res://data/road_four_way.tres")
@export var dead_end_definition: Resource = preload("res://data/road_dead_end.tres")

var deck: Array[Dictionary] = []
var starting_deck: Array[Dictionary] = []
var drawn_count := 0

var _map: GameMap
var _hand: HandUI
var _player: GamePlayer
var _deck_builder: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_hand = get_node_or_null(hand_path) as HandUI
	_player = get_node_or_null(player_path) as GamePlayer
	_deck_builder = get_node_or_null(deck_builder_path)
	if _map == null:
		push_warning("DeckController needs a GameMap at map_path.")
		return
	if _hand == null:
		push_warning("DeckController needs a HandUI at hand_path.")
		return
	if _deck_builder == null:
		push_warning("DeckController needs a DeckBuilder child at deck_builder_path.")
		return

	start_run()
	if not _hand.card_use_requested.is_connected(_on_card_use_requested):
		_hand.card_use_requested.connect(_on_card_use_requested)


func start_run() -> void:
	_prepare_rng()
	generate_deck()
	shuffle_deck()
	drawn_count = 0
	if _hand != null:
		_hand.set_cards(draw_cards(hand_size))


func generate_deck() -> void:
	deck = _deck_builder.make_deck(_get_deck_size(), _rng, _deck_config())
	starting_deck = deck.duplicate(true)


func shuffle_deck() -> void:
	for index in range(deck.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var card: Dictionary = deck[index]
		deck[index] = deck[swap_index]
		deck[swap_index] = card


func draw_card() -> Dictionary:
	if deck.is_empty():
		return {}

	drawn_count += 1
	return deck.pop_back()


func draw_cards(count: int) -> Array[Dictionary]:
	var drawn_cards: Array[Dictionary] = []
	for _index in count:
		var card: Dictionary = draw_card()
		if card.is_empty():
			break
		drawn_cards.append(card)
	return drawn_cards


func refill_hand() -> void:
	if _hand == null:
		return

	while _hand.cards.size() < hand_size:
		var card: Dictionary = draw_card()
		if card.is_empty():
			return
		_hand.add_card(card)


func draw_extra_cards(count: int) -> int:
	if _hand == null:
		return 0

	var drawn := 0
	for _index in count:
		var card: Dictionary = draw_card()
		if card.is_empty():
			break
		_hand.add_card(card)
		drawn += 1
	return drawn


func cards_remaining() -> int:
	return deck.size()


func show_debug_hand(kind: String) -> bool:
	if _hand == null or _deck_builder == null:
		return false
	var debug_cards: Array[Dictionary]
	if kind == "likely":
		debug_cards = _deck_builder.make_most_likely_hand(starting_deck, hand_size)
	else:
		debug_cards = _deck_builder.make_debug_hand(kind, _deck_config())
	if debug_cards.is_empty():
		return false
	_hand.visible = true
	_hand.set_cards(debug_cards)
	return true


func consume_card(card: CardView) -> bool:
	if _hand == null:
		return false
	if not _hand.remove_card(card):
		return false
	refill_hand()
	return true


func _on_card_use_requested(card: CardView) -> void:
	if card.category == ROAD_CATEGORY:
		return
	if card.event_type == EVENT_DRAW_TWO:
		if consume_card(card):
			draw_extra_cards(2)
	elif card.event_type == EVENT_LUCKY_FIND:
		if consume_card(card):
			_apply_lucky_find()


func _apply_lucky_find() -> void:
	if _player == null:
		return
	if _rng.randi_range(0, 1) == 0:
		_player.add_food(3)
	else:
		_player.add_gold(4)


func _get_deck_size() -> int:
	if _map == null:
		return 0
	return _map.playable_width * _map.playable_height


func _prepare_rng() -> void:
	if shuffle_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = shuffle_seed


func _deck_config() -> Dictionary:
	return {
		"road_card_ratio": road_card_ratio,
		"enemy_road_card_ratio": enemy_road_card_ratio,
		"level": level,
		"reward_road_card_ratio": reward_road_card_ratio,
		"road_distribution": road_distribution,
		"road_definitions": {
			"straight": straight_definition,
			"corner": corner_definition,
			"t_junction": t_junction_definition,
			"four_way": four_way_definition,
			"dead_end": dead_end_definition,
		},
	}
