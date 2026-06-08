class_name DeckController
extends Node

signal deck_count_changed(cards_remaining: int, total_cards: int)
signal restart_level_requested

const GameBalance = preload("res://scripts/game_balance.gd")

const HAND_SIZE := 4

@export var map_path: NodePath
@export var hand_path: NodePath
@export var player_path: NodePath
@export var deck_builder_path: NodePath = NodePath("DeckBuilder")
@export var hand_size := HAND_SIZE
@export var shuffle_seed := 0
@export var level := 1

@export var straight_definition: Resource = preload("res://data/road_straight.tres")
@export var corner_definition: Resource = preload("res://data/road_corner.tres")
@export var t_junction_definition: Resource = preload("res://data/road_t_junction.tres")
@export var four_way_definition: Resource = preload("res://data/road_four_way.tres")
@export var dead_end_definition: Resource = preload("res://data/road_dead_end.tres")
@export var bridge_definition: Resource = preload("res://data/road_bridge.tres")

var deck: Array[Dictionary] = []
var starting_deck: Array[Dictionary] = []
var deck_components: Dictionary = {}
var drawn_count := 0
var player_removed_base_cards: Array[String] = []
var player_special_cards: Array[Dictionary] = []

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

	if not _hand.card_drag_finished.is_connected(_on_card_drag_finished):
		_hand.card_drag_finished.connect(_on_card_drag_finished)
	# Note: start_run() is called externally by main._configure_player_deck()
	# to allow deck modifiers to be applied first.


func start_run() -> void:
	_prepare_rng()
	generate_deck()
	shuffle_deck()
	drawn_count = 0
	if _hand != null:
		_hand.set_cards(draw_cards(hand_size))
	_emit_deck_count_changed()


func generate_deck() -> void:
	var config := _deck_config()
	deck_components = _deck_builder.make_deck_components(_get_deck_size(), _rng, config)
	_inject_level_specific_cards(config)
	_apply_player_deck_modifiers()
	deck = _deck_builder.combine_deck_components(deck_components)
	starting_deck = deck.duplicate(true)


func set_player_deck_modifiers(removals: Array, special_cards: Array) -> void:
	player_removed_base_cards.clear()
	for removal in removals:
		player_removed_base_cards.append(str(removal))
	player_special_cards.clear()
	for card in special_cards:
		if card is Dictionary:
			player_special_cards.append((card as Dictionary).duplicate(true))


func _apply_player_deck_modifiers() -> void:
	var base_cards: Array = deck_components.get(DeckBuilder.DECK_SOURCE_BASE, [])
	for removal in player_removed_base_cards:
		for index in base_cards.size():
			if GameConstants.card_signature(base_cards[index]) == removal:
				base_cards.remove_at(index)
				break
	deck_components[DeckBuilder.DECK_SOURCE_BASE] = base_cards
	var specials: Array[Dictionary] = []
	for card in player_special_cards:
		var special := card.duplicate(true)
		special["deck_source"] = DeckBuilder.DECK_SOURCE_PLAYER_SPECIAL
		specials.append(special)
	deck_components[DeckBuilder.DECK_SOURCE_PLAYER_SPECIAL] = specials


func _card_signature(card: Dictionary) -> String:
	return GameConstants.card_signature(card)


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
	var card: Dictionary = deck.pop_back()
	_emit_deck_count_changed()
	return card


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


func total_cards() -> int:
	return starting_deck.size()


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
	_check_exhaustion()
	return true


func _check_exhaustion() -> void:
	if _hand == null or _player == null:
		return
	if _hand.cards.is_empty() and deck.is_empty():
		_player.trigger_game_over("exhaustion")


func _on_card_drag_finished(card: CardView, canvas_position: Vector2, activated: bool, released_over_hand: bool) -> void:
	if card.category == GameConstants.ROAD_CATEGORY:
		return
	if not activated or released_over_hand or _map == null:
		return
	if not _map.is_inside_playable_area(_map.screen_to_grid(canvas_position)):
		return
	play_immediate_event(card)


func play_immediate_event(card: CardView) -> bool:
	if card.event_type == GameConstants.EVENT_DRAW_TWO:
		if consume_card(card):
			draw_extra_cards(2)
			_hand.set_inactive(false)
			return true
	elif card.event_type == GameConstants.EVENT_LUCKY_FIND:
		if consume_card(card):
			_apply_lucky_find()
			_hand.set_inactive(false)
			return true
	elif card.event_type == GameConstants.EVENT_SLEEP:
		if consume_card(card):
			_discard_and_refill_hand()
			_hand.set_inactive(false)
			return true
	elif card.event_type == GameConstants.EVENT_RESTART_LEVEL:
		if consume_card(card):
			_hand.set_inactive(false)
			restart_level_requested.emit()
			return true
	return false


func _apply_lucky_find() -> void:
	if _player == null:
		return
	if _rng.randi_range(0, 1) == 0:
		_player.add_food(3)
	else:
		_player.add_gold(4)


func _discard_and_refill_hand() -> void:
	if _hand == null:
		return
	_hand.set_cards([])
	for _index in hand_size:
		var card: Dictionary = draw_card()
		if card.is_empty():
			break
		_hand.add_card(card)
	_check_exhaustion()


func _inject_level_specific_cards(config: Dictionary) -> void:
	var level_cards: Array[Dictionary] = _deck_builder.make_level_specific_cards(level, config)
	if level_cards.is_empty():
		return
	var level_component: Array = deck_components.get(DeckBuilder.DECK_SOURCE_LEVEL, [])
	for card in level_cards:
		card["deck_source"] = DeckBuilder.DECK_SOURCE_LEVEL
		level_component.append(card)
	deck_components[DeckBuilder.DECK_SOURCE_LEVEL] = level_component


func _get_deck_size() -> int:
	if _map == null:
		return 0
	return int(GameBalance.deck_counts(level, _get_map_size())["total_cards"])


func _prepare_rng() -> void:
	if shuffle_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = shuffle_seed


func _emit_deck_count_changed() -> void:
	deck_count_changed.emit(cards_remaining(), total_cards())


func _deck_config() -> Dictionary:
	var map_size := _get_map_size()
	var config := _make_deck_config(level, map_size)
	config["deck_components"] = GameBalance.deck_component_counts(level, map_size)
	if level > 1:
		config["base_deck_config"] = _make_deck_config(1, GameBalance.INTRO_BASE_MAP_SIZE)
	return config


func _make_deck_config(deck_level: int, map_size: int) -> Dictionary:
	var counts := GameBalance.deck_counts(deck_level, map_size)
	return {
		"level": deck_level,
		"map_size": map_size,
		"road_count": counts["road_cards"],
		"road_distribution": counts["road_distribution"],
		"special_roads": counts["special_roads"],
		"road_definitions": {
			"straight": straight_definition,
			"corner": corner_definition,
			"t_junction": t_junction_definition,
			"four_way": four_way_definition,
			"dead_end": dead_end_definition,
		},
		"bridge_definition": bridge_definition,
	}


func _get_map_size() -> int:
	if _map == null:
		return 0
	return mini(_map.playable_width, _map.playable_height)
