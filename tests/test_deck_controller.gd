extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const HAND_SCENE := preload("res://ui/hand.tscn")
const DECK_CONTROLLER_SCENE := preload("res://scenes/deck_controller.tscn")
const STRAIGHT_DEFINITION := preload("res://data/road_straight.tres")
const CORNER_DEFINITION := preload("res://data/road_corner.tres")


func _initialize() -> void:
	var fixture := _make_fixture(1, 5)
	var hand := fixture["hand"] as HandUI
	var deck_controller := fixture["deck"] as DeckController

	_assert(hand.cards.size() == 4, "Expected the opening hand to contain four cards")
	_assert(deck_controller.total_cards() == 18, "Expected level one to use the authored base deck")
	_assert(deck_controller.cards_remaining() == 14, "Expected opening hand to draw from the base deck")
	_assert(deck_controller.drawn_count == 4, "Expected opening hand draw count to be tracked")
	_assert(deck_controller.deck_components[GameConstants.DECK_SOURCE_BASE].size() == 18, "Expected level one to contain only base cards")
	_assert(deck_controller.deck_components[GameConstants.DECK_SOURCE_LEVEL].is_empty(), "Expected level one to have no level add-on cards")

	var all_cards := _all_card_data(deck_controller, hand)
	_assert(_count_category(all_cards, GameConstants.ROAD_CATEGORY) == 15, "Expected base deck to contain fifteen road cards")
	_assert(_count_category(all_cards, GameConstants.EVENT_CATEGORY) == 3, "Expected base deck to contain three event cards")
	_assert(_count_road_encounter(all_cards, GameConstants.ENCOUNTER_ENEMY) == 1, "Expected base deck to contain one enemy road")
	_assert(_count_road_encounter(all_cards, GameConstants.ENCOUNTER_BERRY_BUSH) == 1, "Expected base deck to contain one berry road")
	_assert(_count_road_encounter(all_cards, GameConstants.ENCOUNTER_CACHE) == 1, "Expected base deck to contain one cache road")
	_assert(_count_road_encounter(all_cards, GameConstants.ENCOUNTER_GRAVEYARD) == 1, "Expected base deck to contain one graveyard road")
	_assert(_has_event(all_cards, GameConstants.EVENT_DESTROY_TILE), "Expected base deck to include Mirage")
	_assert(_has_event(all_cards, GameConstants.EVENT_DRAW_TWO), "Expected base deck to include Idea")
	_assert(_has_event(all_cards, GameConstants.EVENT_LUCKY_FIND), "Expected base deck to include Lucky Find")
	_assert(not _has_event(all_cards, GameConstants.EVENT_ROTATE_TILE), "Expected Doubt to stay out of the base deck")
	_assert(_enemy_power_values_are_in_range(all_cards, Vector2i(1, 3)), "Expected level one enemies to use the level one power range")
	_assert(_caches_have_exactly_one_item(all_cards), "Expected every cache to contain exactly one item")

	var level_two := _make_fixture(2, 7)
	var level_two_deck := level_two["deck"] as DeckController
	_assert(level_two_deck.total_cards() == 30, "Expected level two to combine base and authored level cards")
	_assert(level_two_deck.deck_components[GameConstants.DECK_SOURCE_BASE].size() == 18, "Expected level two to keep the base deck component")
	_assert(level_two_deck.deck_components[GameConstants.DECK_SOURCE_LEVEL].size() == 12, "Expected level two to add its twelve-card authored component")
	var level_two_cards := _all_card_data(level_two_deck, level_two["hand"] as HandUI)
	_assert(_count_road_type(level_two_cards, "Bridge") == 1, "Expected level two to include one bridge")
	_assert(_count_road_encounter(level_two_cards, GameConstants.ENCOUNTER_ENEMY) == 4, "Expected level two total enemy road count to include base plus level encounters")
	_assert(_count_road_encounter(level_two_cards, GameConstants.ENCOUNTER_BERRY_BUSH) == 3, "Expected level two total berry road count to include base plus level encounters")
	_assert(_count_road_encounter(level_two_cards, GameConstants.ENCOUNTER_CACHE) == 3, "Expected level two total cache road count to include base plus level encounters")
	_assert(_has_event(level_two_cards, GameConstants.EVENT_TROUBLE), "Expected level two to include Trouble")
	_assert(_enemy_power_values_are_in_range(level_two_cards, Vector2i(2, 4)), "Expected level two enemies to use the level two power range")

	var modal_source: Array[Dictionary] = []
	for _index in 5:
		modal_source.append({"category": "Road", "tile_definition": STRAIGHT_DEFINITION})
	for _index in 3:
		modal_source.append({"category": "Road", "tile_definition": CORNER_DEFINITION})
	for _index in 2:
		modal_source.append({"category": "Event", "event_type": GameConstants.EVENT_DRAW_TWO})
	var modal_hand: Array[Dictionary] = deck_controller.get_node("DeckBuilder").make_most_likely_hand(modal_source, 2)
	_assert(modal_hand.size() == 2, "Expected modal hand calculation to preserve requested hand size")
	_assert(_has_definition(modal_hand, STRAIGHT_DEFINITION) and _has_definition(modal_hand, CORNER_DEFINITION), "Expected modal hand calculation to maximize combinations without replacement")

	var first_card := hand.cards[0]
	deck_controller.consume_card(first_card)
	_assert(hand.cards.size() == 4, "Expected using a card to draw one replacement")
	_assert(deck_controller.cards_remaining() == 13, "Expected replacement draw to remove one card from the deck")
	_assert(not hand.cards.has(first_card), "Expected used card to leave the hand")

	deck_controller.deck.clear()
	while hand.cards.size() > 0:
		deck_controller.consume_card(hand.cards[0])
	_assert(hand.cards.size() == 0, "Expected hand to shrink when the deck is exhausted")
	_assert(deck_controller.cards_remaining() == 0, "Expected exhausted deck to stay empty")

	quit()


func _make_fixture(level: int, map_size: int) -> Dictionary:
	var root := Node2D.new()
	get_root().add_child(root)

	var map := MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	map.playable_width = map_size
	map.playable_height = map_size
	root.add_child(map)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)

	var hand := HAND_SCENE.instantiate() as HandUI
	hand.name = "Hand"
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hand.size = Vector2(360.0, 640.0)
	ui.add_child(hand)
	hand._ready()

	var deck_controller := DECK_CONTROLLER_SCENE.instantiate() as DeckController
	deck_controller.name = "DeckController"
	deck_controller.map_path = NodePath("../Map")
	deck_controller.hand_path = NodePath("../UI/Hand")
	deck_controller.shuffle_seed = 12345
	deck_controller.level = level
	root.add_child(deck_controller)
	deck_controller._ready()
	deck_controller.start_run()

	return {"root": root, "hand": hand, "deck": deck_controller}


func _all_card_data(deck_controller: DeckController, hand: HandUI) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for card in hand.cards:
		cards.append(card.get_card_data())
	for card_data in deck_controller.deck:
		cards.append(card_data)
	return cards


func _count_category(cards: Array[Dictionary], category: String) -> int:
	var count := 0
	for card in cards:
		if str(card.get("category", "")) == category:
			count += 1
	return count


func _count_road_encounter(cards: Array[Dictionary], encounter_type: String) -> int:
	var count := 0
	for card in cards:
		if str(card.get("category", "")) != GameConstants.ROAD_CATEGORY:
			continue
		if str((card.get("encounter", {}) as Dictionary).get("type", "")) == encounter_type:
			count += 1
	return count


func _count_road_type(cards: Array[Dictionary], display_name: String) -> int:
	var count := 0
	for card in cards:
		var definition: Resource = card.get("tile_definition")
		if definition != null and str(definition.get("display_name")) == display_name:
			count += 1
	return count


func _has_event(cards: Array[Dictionary], event_type: String) -> bool:
	for card in cards:
		if str(card.get("event_type", "")) == event_type:
			return true
	return false


func _enemy_power_values_are_in_range(cards: Array[Dictionary], power_range: Vector2i) -> bool:
	for card in cards:
		var encounter: Dictionary = card.get("encounter", {})
		if str(encounter.get("type", "")) != GameConstants.ENCOUNTER_ENEMY:
			continue
		var power := int(encounter.get("power", 0))
		if power < power_range.x or power > power_range.y:
			return false
	return true


func _caches_have_exactly_one_item(cards: Array[Dictionary]) -> bool:
	for card in cards:
		var encounter: Dictionary = card.get("encounter", {})
		if str(encounter.get("type", "")) != GameConstants.ENCOUNTER_CACHE:
			continue
		var loot: Array = encounter.get("loot", [])
		if loot.size() != 1 or not (loot[0] is Dictionary) or str(loot[0].get("kind", "")) != "item":
			return false
	return true


func _has_definition(cards: Array[Dictionary], definition: Resource) -> bool:
	for card in cards:
		if card.get("tile_definition") == definition:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
