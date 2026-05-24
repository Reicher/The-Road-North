extends SceneTree

const MAP_SCRIPT := preload("res://scripts/map.gd")
const HAND_SCRIPT := preload("res://scripts/hand_ui.gd")
const DECK_CONTROLLER_SCRIPT := preload("res://scripts/deck_controller.gd")


func _initialize() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCRIPT.new()
	map.name = "Map"
	root.add_child(map)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)

	var hand = HAND_SCRIPT.new()
	hand.name = "Hand"
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.size = Vector2(360.0, 640.0)
	ui.add_child(hand)
	hand._ready()

	var deck_controller = DECK_CONTROLLER_SCRIPT.new()
	deck_controller.name = "DeckController"
	deck_controller.map_path = NodePath("../Map")
	deck_controller.hand_path = NodePath("../UI/Hand")
	deck_controller.shuffle_seed = 12345
	root.add_child(deck_controller)
	deck_controller._ready()

	_assert(hand.cards.size() == 5, "Expected the opening hand to contain five cards")
	_assert(deck_controller.cards_remaining() == 76, "Expected a 9x9 deck to draw five cards from eighty-one")
	_assert(deck_controller.drawn_count == 5, "Expected opening hand draw count to be tracked")

	var category_counts := {"Road": 0, "Event": 0}
	for card in hand.cards:
		category_counts[card.category] += 1
	for card_data in deck_controller.deck:
		category_counts[card_data["category"]] += 1
	_assert(category_counts["Road"] == 61, "Expected 75 percent of an 81 card deck to round to 61 road cards")
	_assert(category_counts["Event"] == 20, "Expected the remaining deck cards to be events")

	var first_card = hand.cards[0]
	deck_controller.consume_card(first_card)
	_assert(hand.cards.size() == 5, "Expected using a card to draw one replacement")
	_assert(deck_controller.cards_remaining() == 75, "Expected replacement draw to remove one card from the deck")
	_assert(not hand.cards.has(first_card), "Expected used card to leave the hand")

	deck_controller.deck.clear()
	while hand.cards.size() > 0:
		deck_controller.consume_card(hand.cards[0])
	_assert(hand.cards.size() == 0, "Expected hand to shrink when the deck is exhausted")
	_assert(deck_controller.cards_remaining() == 0, "Expected exhausted deck to stay empty")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
