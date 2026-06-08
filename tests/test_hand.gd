extends SceneTree

const HAND_SCENE := preload("res://ui/hand.tscn")
const CARD_SCENE := preload("res://ui/card.tscn")
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
	_assert(hand.card_size == Vector2(174.0, 250.0), "Expected mobile hand cards to use the larger presentation size")
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
		_assert(card.position.x >= hand.side_margin, "Expected cards to keep a margin from the left screen edge")
		_assert(card.position.x + card.size.x <= root.size.x - hand.side_margin, "Expected cards to keep a margin from the right screen edge")
		_assert(not card.focused, "Expected cards to start unfocused")

	var wide_hand = HAND_SCENE.instantiate() as HandUI
	wide_hand.demo_cards_enabled = false
	wide_hand.layout_duration = 0.0
	wide_hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wide_hand.size = Vector2(720.0, 340.0)
	root.add_child(wide_hand)
	wide_hand.set_cards([
		{"category": "Road", "tile_definition": STRAIGHT},
		{"category": "Road", "tile_definition": CORNER},
		{"category": "Road", "tile_definition": T_JUNCTION},
		{"category": "Road", "tile_definition": FOUR_WAY},
	])
	var wide_hand_left: float = wide_hand.cards[0].position.x
	var wide_hand_right: float = wide_hand.cards[3].position.x + wide_hand.cards[3].size.x
	_assert(is_equal_approx(wide_hand_left, wide_hand.side_margin), "Expected a wide four-card hand to keep its left margin")
	_assert(is_equal_approx(wide_hand_right, wide_hand.size.x - wide_hand.side_margin), "Expected a wide four-card hand to keep its right margin")
	wide_hand.queue_free()

	var focused_card = hand.cards[2]
	hand.call("focus_card", focused_card)
	_assert(hand.call("get_focused_card") == focused_card, "Expected tapped card to become focused")
	_assert(focused_card.focused, "Expected focused card state to update")
	_assert(focused_card.scale.x > hand.cards[1].scale.x, "Expected focused card to grow larger than surrounding cards")
	_assert(hand.get_node_or_null("UseButton") == null, "Expected the hand to have no Use button")
	_assert(focused_card.get_node_or_null("UseButton") == null, "Expected cards to have no Use button")
	var title_label := focused_card.get_node("Title") as Label
	var category_label := focused_card.get_node("Category") as Label
	var plain_title_label := hand.cards[0].get_node("Title") as Label
	var berry_title_label := hand.cards[1].get_node("Title") as Label
	var enemy_title_label := hand.cards[3].get_node("Title") as Label
	var berry_category_label := hand.cards[1].get_node("Category") as Label
	var enemy_category_label := hand.cards[3].get_node("Category") as Label
	var detail_label := focused_card.get_node("Detail") as Label
	var plain_detail_label := hand.cards[0].get_node("Detail") as Label
	var berry_detail_label := hand.cards[1].get_node("Detail") as Label
	var enemy_detail_label := hand.cards[3].get_node("Detail") as Label
	_assert(plain_title_label.text == "Straight Road", "Expected plain road cards to show only the road type")
	_assert(plain_detail_label.text == "", "Expected plain road cards to leave the detail text empty")
	_assert(berry_title_label.text == "Corner", "Expected berry road cards to show only the road type")
	_assert(berry_detail_label.text == "", "Expected berry road cards to leave the detail text empty")
	_assert(berry_category_label.text == "ROAD + FOOD", "Expected berry road cards to identify their food reward")
	_assert(enemy_title_label.text == "Four-Way Intersection", "Expected enemy road cards to show only the road type")
	_assert(enemy_detail_label.text == "", "Expected enemy road cards to leave the detail text empty")
	_assert(enemy_category_label.text == "ROAD + ENEMY", "Expected enemy road cards to identify their enemy encounter")
	_assert(title_label.offset_bottom < focused_card.get_card_art_rect().position.y, "Expected two-line card titles to stay above the card art")
	_assert(focused_card.get_card_art_rect().size.y > CardView.NO_DETAIL_ART_RECT.size.y, "Expected larger cards to scale up their road art")
	var card_scale_y: float = focused_card.size.y / CardView.BASE_CARD_SIZE.y
	_assert(is_equal_approx(category_label.offset_top, CardView.CATEGORY_RECT.position.y * card_scale_y), "Expected road category badge to keep the scaled bottom category position")
	_assert(is_equal_approx(category_label.offset_bottom, CardView.CATEGORY_RECT.end.y * card_scale_y), "Expected road category badge to sit at the bottom of the larger card")
	_assert(detail_label.offset_bottom < focused_card.size.y, "Expected focused card detail text to stay inside the card")
	_assert(title_label.get_theme_font_size("font_size") > CardView.TITLE_FONT_MAX, "Expected larger cards to scale up their title text")
	_assert(detail_label.get_theme_font_size("font_size") > CardView.DETAIL_FONT_MAX, "Expected larger cards to scale up their detail text")
	_assert(focused_card.position.y < hand.cards[1].position.y, "Expected focused card to lift above surrounding cards")
	_assert(hand.cards[1].position.y <= hand.cards[0].position.y, "Expected neighboring cards to keep the hand arc height")
	_assert(hand.cards[3].position.y <= hand.cards[4].position.y, "Expected neighboring cards to keep the hand arc height")
	for card in hand.cards:
		var scale_overhang: float = card.size.x * maxf(0.0, card.scale.x - 1.0) * 0.5
		_assert(card.position.x - scale_overhang >= hand.side_margin, "Expected focused hand layout to keep its left margin")
		_assert(card.position.x + card.size.x + scale_overhang <= hand.size.x - hand.side_margin, "Expected focused hand layout to keep its right margin")

	hand.call("_on_card_focus_requested", focused_card)
	_assert(hand.call("get_focused_card") == null, "Expected tapping the focused card again to clear focus")

	var touch_card: CardView = hand.cards[4]
	var touch_button := touch_card.get_node("TouchButton") as Button
	_assert(touch_button != null and touch_button.flat, "Expected cards to use a transparent native Button touch surface")
	var touch_position: Vector2 = touch_card.get_global_transform_with_canvas() * (touch_card.size * 0.5)
	hand.call("_on_card_pointer_pressed", touch_card, touch_position)
	hand.call("_on_card_pointer_released", touch_card, touch_position)
	_assert(hand.get_focused_card() == touch_card, "Expected native card button to focus an overlapping card on mobile")
	_assert((touch_card.get_node("Title") as Label).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Expected card labels not to intercept touch input")

	var drag_card: CardView = touch_card
	var drag_started: Array = []
	var drag_moves: Array = []
	var drag_finished: Array = []
	hand.card_drag_started.connect(func(card: CardView, position: Vector2) -> void: drag_started.append([card, position]))
	hand.card_drag_moved.connect(func(card: CardView, position: Vector2, activated: bool) -> void: drag_moves.append([card, position, activated]))
	hand.card_drag_finished.connect(func(card: CardView, position: Vector2, activated: bool, over_hand: bool) -> void: drag_finished.append([card, position, activated, over_hand]))
	hand.call("_on_card_pointer_pressed", drag_card, touch_position)
	hand.call("_on_card_pointer_moved", drag_card, touch_position + Vector2.UP * (hand.drag_threshold - 1.0))
	_assert(not hand.is_drag_active(), "Expected movement below the drag threshold to keep the card focused")
	var resting_card_y: float = hand.cards[0].position.y
	var activated_position := Vector2(touch_position.x, hand.get_activation_boundary_y() - 8.0)
	hand.call("_on_card_pointer_moved", drag_card, activated_position)
	_assert(hand.is_drag_active(), "Expected a deliberate drag to start card dragging")
	_assert(hand.inactive, "Expected dragging above the hand to make the hand inactive")
	_assert(is_equal_approx(hand.cards[0].position.y, resting_card_y + hand.card_size.y * hand.inactive_visible_ratio + hand.bottom_margin), "Expected inactive cards to sit half hidden below the screen")
	_assert(hand.is_in_group("ui_item_drag_active"), "Expected card dragging to block camera input")
	_assert(drag_started.size() == 1, "Expected card drag start to emit once")
	_assert(drag_moves[-1][2] == true, "Expected dragging above the hand to activate the card")
	hand.call("_on_card_pointer_released", drag_card, activated_position)
	_assert(not hand.is_drag_active(), "Expected releasing to finish card dragging")
	_assert(hand.inactive, "Expected an activated release to keep the hand inactive for placement")
	_assert(not hand.is_in_group("ui_item_drag_active"), "Expected releasing a card to restore camera input")
	_assert(drag_finished.size() == 1 and drag_finished[0][2] == true, "Expected activated release to be reported")
	_assert(drag_finished[0][3] == false, "Expected release above the hand not to count as returning the card")
	hand.set_inactive(false, false)
	_assert(is_equal_approx(hand.cards[0].position.y, resting_card_y), "Expected ending placement to restore the hand")

	hand.call("focus_card", focused_card)

	hand.clear_focus()
	_assert(hand.call("get_focused_card") == null, "Expected clear_focus to remove the selected card")

	var cache_card := CARD_SCENE.instantiate() as CardView
	root.add_child(cache_card)
	cache_card.configure({
		"category": "Road",
		"tile_definition": CORNER,
		"encounter": {
			"type": GameMap.ENCOUNTER_CACHE,
			"loot": [{"kind": "item", "item": {"name": "Knife", "effect": "+1 Power", "power_bonus": 1}}],
		},
	})
	_assert((cache_card.get_node("Title") as Label).text == "Corner", "Expected treasure road cards to show only the road type")
	_assert((cache_card.get_node("Category") as Label).text == "ROAD + LOOT", "Expected treasure road cards to identify their loot encounter")
	cache_card.queue_free()

	var event_card := CARD_SCENE.instantiate() as CardView
	root.add_child(event_card)
	event_card.configure({
		"category": "Event",
		"title": "Mirage",
		"detail": "Destroy a placed tile.",
		"event_type": GameConstants.EVENT_DESTROY_TILE,
	})
	var event_detail_label := event_card.get_node("Detail") as Label
	var event_category_label := event_card.get_node("Category") as Label
	_assert(event_detail_label.text == "Remove a tile", "Expected event cards to keep compact detail text")
	_assert(event_card.get_card_art_rect() == CardView.ART_RECT, "Expected default-size event card art to stay above the detail text")
	_assert(event_detail_label.offset_top > event_card.get_card_art_rect().end.y, "Expected event detail text to sit below the card art")
	_assert(event_detail_label.offset_bottom < event_category_label.offset_top, "Expected event detail text to sit between art and category")
	_assert(is_equal_approx(event_category_label.offset_top, CardView.CATEGORY_RECT.position.y), "Expected event category badge to use the bottom category position")
	_assert(is_equal_approx(event_category_label.offset_bottom, CardView.CATEGORY_RECT.end.y), "Expected event category badge to sit at the bottom of the card")
	for event_type in [
		GameConstants.EVENT_AMBUSH,
		GameConstants.EVENT_WILD_BERRIES,
		GameConstants.EVENT_LOST_BELONGINGS,
	]:
		event_card.event_type = event_type
		_assert(event_card.call("_card_art_texture") == null, "Expected encounter-adding events not to show the fallback event star")
	event_card.event_type = GameConstants.EVENT_CLEAR_PATH
	_assert(event_card.call("_card_art_texture") != null, "Expected Clear Path to keep the fallback event star")
	event_card.queue_free()

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
