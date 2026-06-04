extends SceneTree

const HAND_SCENE := preload("res://ui/hand.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")
const FOUR_WAY := preload("res://data/road_four_way.tres")
const DEAD_END := preload("res://data/road_dead_end.tres")


func _initialize() -> void:
	var root := Control.new()
	root.size = Vector2(360.0, 640.0)
	get_root().add_child(root)

	var hand = HAND_SCENE.instantiate() as HandUI
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hand.size = root.size
	root.add_child(hand)
	hand.set_cards([
		{"category": "Road", "tile_definition": STRAIGHT},
		{
			"category": "Road",
			"tile_definition": CORNER,
			"encounter": {
				"type": GameMap.ENCOUNTER_BERRY_BUSH,
				"loot": [{"kind": "food", "amount": 2}],
			},
		},
		{"category": "Road", "tile_definition": T_JUNCTION},
		{
			"category": "Road",
			"tile_definition": FOUR_WAY,
			"encounter": {
				"type": GameMap.ENCOUNTER_ENEMY,
				"revealed": false,
				"health": 1,
				"max_health": 1,
				"power": 1,
			},
		},
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
	var hand_use_button := hand.get_node("UseButton") as Button
	_assert(hand_use_button.visible, "Expected Use button to appear below the focused card")
	_assert(not focused_card.get_node("UseButton").visible, "Expected focused card to keep its internal Use button hidden")
	_assert(not hand.cards[1].get_node("UseButton").visible, "Expected Use button to stay hidden on unfocused cards")
	var title_label := focused_card.get_node("Title") as Label
	var plain_title_label := hand.cards[0].get_node("Title") as Label
	var berry_title_label := hand.cards[1].get_node("Title") as Label
	var enemy_title_label := hand.cards[3].get_node("Title") as Label
	var detail_label := focused_card.get_node("Detail") as Label
	var plain_detail_label := hand.cards[0].get_node("Detail") as Label
	var berry_detail_label := hand.cards[1].get_node("Detail") as Label
	var focused_card_bottom: float = focused_card.position.y + focused_card.size.y * 0.5 + focused_card.size.y * focused_card.scale.y * 0.5
	_assert(plain_title_label.text == "Straight Road", "Expected plain road cards to show only the road type")
	_assert(plain_detail_label.text == "", "Expected plain road cards to leave the detail text empty")
	_assert(berry_title_label.text == "Berry\nCorner", "Expected berry road cards to show modifier above road type")
	_assert(berry_detail_label.text == "Plus food", "Expected berry road cards to use short reward detail text")
	_assert(enemy_title_label.text == "Danger\nFour-Way", "Expected enemy road cards to show modifier above road type")
	_assert(title_label.offset_bottom < CardView.ART_RECT.position.y, "Expected two-line card titles to stay above the card art")
	_assert(detail_label.offset_bottom < focused_card.size.y, "Expected focused card detail text to stay inside the card")
	_assert(title_label.get_theme_font_size("font_size") <= CardView.TITLE_FONT_MAX, "Expected card titles to use the fitted title font size")
	_assert(detail_label.get_theme_font_size("font_size") <= CardView.DETAIL_FONT_MAX, "Expected card details to use the fitted detail font size")
	_assert(hand_use_button.position.y >= focused_card_bottom, "Expected focused Use button to sit below the card")
	_assert(hand_use_button.position.y + hand_use_button.size.y <= hand.size.y, "Expected focused Use button to fit above the bottom of the screen")
	_assert(focused_card.position.y < hand.cards[1].position.y, "Expected focused card to lift above surrounding cards")
	_assert(hand.cards[1].position.y <= hand.cards[0].position.y, "Expected neighboring cards to keep the hand arc height")
	_assert(hand.cards[3].position.y <= hand.cards[4].position.y, "Expected neighboring cards to keep the hand arc height")

	hand.call("_on_card_focus_requested", focused_card)
	_assert(hand.call("get_focused_card") == null, "Expected tapping the focused card again to clear focus")
	_assert(not hand_use_button.visible, "Expected Use button to hide after tapping the focused card again")

	hand.call("focus_card", focused_card)

	hand.clear_focus()
	_assert(hand.call("get_focused_card") == null, "Expected clear_focus to remove the selected card")
	_assert(not hand_use_button.visible, "Expected Use button to hide when card is unfocused")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
