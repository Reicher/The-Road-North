extends SceneTree

const HAND_SCRIPT := preload("res://scripts/hand_ui.gd")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")
const FOUR_WAY := preload("res://data/road_four_way.tres")
const DEAD_END := preload("res://data/road_dead_end.tres")


func _initialize() -> void:
	var root := Control.new()
	root.size = Vector2(360.0, 640.0)
	get_root().add_child(root)

	var hand = HAND_SCRIPT.new()
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.size = root.size
	root.add_child(hand)
	hand.set_cards([
		{"category": "Road", "tile_definition": STRAIGHT},
		{"category": "Road", "tile_definition": CORNER},
		{"category": "Road", "tile_definition": T_JUNCTION},
		{"category": "Road", "tile_definition": FOUR_WAY},
		{"category": "Road", "tile_definition": DEAD_END},
	])

	_assert(hand.cards.size() == 5, "Expected hand to display five cards")
	_assert(hand.get_card_spacing() < hand.preferred_spacing, "Expected mobile-width hand spacing to compress")
	for card in hand.cards:
		_assert(card.position.x >= 0.0, "Expected cards to stay inside the left screen edge")
		_assert(card.position.x + card.size.x <= root.size.x, "Expected cards to stay inside the right screen edge")
		_assert(not card.focused, "Expected cards to start unfocused")

	var focused_card = hand.cards[2]
	hand.call("focus_card", focused_card)
	_assert(hand.call("get_focused_card") == focused_card, "Expected tapped card to become focused")
	_assert(focused_card.focused, "Expected focused card state to update")
	_assert(focused_card.get_node("UseButton").visible, "Expected Use button to appear only on focused card")
	_assert(not hand.cards[1].get_node("UseButton").visible, "Expected Use button to stay hidden on unfocused cards")
	_assert(focused_card.position.y < hand.cards[1].position.y, "Expected focused card to lift above surrounding cards")
	_assert(hand.cards[1].position.y <= hand.cards[0].position.y, "Expected neighboring cards to keep the hand arc height")
	_assert(hand.cards[3].position.y <= hand.cards[4].position.y, "Expected neighboring cards to keep the hand arc height")

	hand.clear_focus()
	_assert(hand.call("get_focused_card") == null, "Expected clear_focus to remove the selected card")
	_assert(not focused_card.get_node("UseButton").visible, "Expected Use button to hide when card is unfocused")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
