class_name DeckController
extends Node

const ROAD_CATEGORY := "Road"
const EVENT_CATEGORY := "Event"
const EVENT_DESTROY_NEIGHBOR := "destroy_neighbor"
const EVENT_DRAW_TWO := "draw_two"

const ROAD_CARD_RATIO := 0.75
const ENEMY_ROAD_CARD_RATIO := 0.20
const HAND_SIZE := 5

const ROAD_DISTRIBUTION := {
	"straight": 30.0,
	"corner": 30.0,
	"t_junction": 20.0,
	"four_way": 10.0,
	"dead_end": 10.0,
}

@export var map_path: NodePath
@export var hand_path: NodePath
@export var hand_size := HAND_SIZE
@export var shuffle_seed := 0
@export_range(0.0, 1.0, 0.01) var road_card_ratio := ROAD_CARD_RATIO
@export_range(0.0, 1.0, 0.01) var enemy_road_card_ratio := ENEMY_ROAD_CARD_RATIO
@export var road_distribution := ROAD_DISTRIBUTION.duplicate()

@export var straight_definition: Resource = preload("res://data/road_straight.tres")
@export var corner_definition: Resource = preload("res://data/road_corner.tres")
@export var t_junction_definition: Resource = preload("res://data/road_t_junction.tres")
@export var four_way_definition: Resource = preload("res://data/road_four_way.tres")
@export var dead_end_definition: Resource = preload("res://data/road_dead_end.tres")

var deck: Array[Dictionary] = []
var drawn_count := 0

var _map: GameMap
var _hand: HandUI
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_hand = get_node_or_null(hand_path) as HandUI
	if _map == null:
		push_warning("DeckController needs a GameMap at map_path.")
		return
	if _hand == null:
		push_warning("DeckController needs a HandUI at hand_path.")
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
	var deck_size := _get_deck_size()
	var road_count := roundi(float(deck_size) * road_card_ratio)
	var event_count: int = maxi(0, deck_size - road_count)

	deck.clear()
	for road_card in _make_road_cards(road_count):
		deck.append(road_card)
	for event_card in _make_event_cards(event_count):
		deck.append(event_card)


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


func _get_deck_size() -> int:
	if _map == null:
		return 0
	return _map.playable_width * _map.playable_height


func _prepare_rng() -> void:
	if shuffle_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = shuffle_seed


func _make_road_cards(count: int) -> Array[Dictionary]:
	var definitions: Dictionary = {
		"straight": straight_definition,
		"corner": corner_definition,
		"t_junction": t_junction_definition,
		"four_way": four_way_definition,
		"dead_end": dead_end_definition,
	}
	var counts := _counts_from_distribution(count, road_distribution)
	var cards: Array[Dictionary] = []
	for subtype in counts:
		var card_count: int = counts[subtype]
		for _index in card_count:
			cards.append({
				"category": ROAD_CATEGORY,
				"tile_definition": definitions[subtype],
			})
	_add_enemies_to_road_cards(cards)
	return cards


func _make_event_cards(count: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for index in count:
		if index % 2 == 0:
			cards.append({
				"category": EVENT_CATEGORY,
				"title": "Clear Road",
				"detail": "Destroy a neighboring placed tile.",
				"event_type": "destroy_neighbor",
				"card_color": Color(0.79, 0.76, 0.67),
			})
		else:
			cards.append({
				"category": EVENT_CATEGORY,
				"title": "Supplies",
				"detail": "Draw two extra cards.",
				"event_type": "draw_two",
				"card_color": Color(0.68, 0.82, 0.70),
			})
	return cards


func _counts_from_distribution(total: int, distribution: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	var fractions: Array[Dictionary] = []
	var assigned := 0
	var weight_total := 0.0

	for key in distribution:
		weight_total += float(distribution[key])

	for key in distribution:
		var exact_count := float(total) * float(distribution[key]) / weight_total
		var base_count := floori(exact_count)
		counts[key] = base_count
		fractions.append({
			"key": key,
			"fraction": exact_count - float(base_count),
		})
		assigned += base_count

	fractions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["fraction"]) > float(b["fraction"]))

	var remaining := total - assigned
	for index in remaining:
		var key: String = fractions[index % fractions.size()]["key"]
		counts[key] += 1

	return counts


func _add_enemies_to_road_cards(cards: Array[Dictionary]) -> void:
	var enemy_count := roundi(float(cards.size()) * enemy_road_card_ratio)
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var card := cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = card

	for index in mini(enemy_count, cards.size()):
		var card: Dictionary = cards[index]
		card["enemy"] = _make_enemy_data()
		cards[index] = card


func _make_enemy_data() -> Dictionary:
	return {
		"revealed": false,
		"health": 1,
		"max_health": 1,
		"attack": _rng.randi_range(1, 3),
		"armor": _rng.randi_range(1, 3),
	}
