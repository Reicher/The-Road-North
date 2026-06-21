extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const HAND_SCENE := preload("res://ui/hand.tscn")
const DECK_CONTROLLER_SCENE := preload("res://scenes/deck_controller.tscn")
const CARD_DEFINITION_SCRIPT := preload("res://scripts/card_definition.gd")
const STRAIGHT_DEFINITION := preload("res://data/road_straight.tres")
const CORNER_DEFINITION := preload("res://data/road_corner.tres")


func _initialize() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)

	var hand = HAND_SCENE.instantiate() as HandUI
	hand.name = "Hand"
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hand.size = Vector2(360.0, 640.0)
	ui.add_child(hand)
	hand._ready()

	var deck_controller = DECK_CONTROLLER_SCENE.instantiate() as DeckController
	deck_controller.name = "DeckController"
	deck_controller.map_path = NodePath("../Map")
	deck_controller.hand_path = NodePath("../UI/Hand")
	deck_controller.shuffle_seed = 12345
	root.add_child(deck_controller)
	deck_controller._ready()

	_assert(hand.cards.size() == 4, "Expected the opening hand to contain four cards")
	_assert(deck_controller.cards_remaining() == 28, "Expected a level one 9x9 formula deck to draw four cards from thirty-two")
	_assert(deck_controller.drawn_count == 4, "Expected opening hand draw count to be tracked")

	var category_counts := {"Road": 0, "Event": 0}
	var typed_definition_count := 0
	var enemy_road_count := 0
	var enemy_road_has_clear_label := false
	var enemy_power_values_are_level_scaled := true
	var reward_road_count := 0
	var reward_road_has_clear_label := false
	var cache_count := 0
	var caches_have_exactly_one_item := true
	var event_types := {}
	for card in hand.cards:
		category_counts[card.category] += 1
		if card.category == "Road" and card.encounter_data.get("type", "") == GameMap.ENCOUNTER_ENEMY:
			enemy_road_count += 1
			var hand_enemy_power := int(card.encounter_data.get("power", 0))
			enemy_power_values_are_level_scaled = enemy_power_values_are_level_scaled and hand_enemy_power >= 1 and hand_enemy_power <= 3
			enemy_road_has_clear_label = enemy_road_has_clear_label or (card.title == str(card.tile_definition.get("display_name")) and card.detail == "Enemy waits on this road.")
		elif card.category == "Road" and not card.encounter_data.is_empty():
			reward_road_count += 1
			reward_road_has_clear_label = reward_road_has_clear_label or card.detail in ["Plus food", "Plus treasure"]
			if card.encounter_data.get("type", "") == GameMap.ENCOUNTER_CACHE:
				cache_count += 1
				caches_have_exactly_one_item = caches_have_exactly_one_item and _cache_has_exactly_one_item(card.encounter_data)
		elif card.category == "Event":
			event_types[card.event_type] = true
	for card_data in deck_controller.deck:
		category_counts[card_data["category"]] += 1
		if card_data.get("card_definition") is CARD_DEFINITION_SCRIPT:
			typed_definition_count += 1
		var encounter: Dictionary = card_data.get("encounter", {})
		if card_data["category"] == "Road" and encounter.get("type", "") == GameMap.ENCOUNTER_ENEMY:
			enemy_road_count += 1
			var deck_enemy_power := int(encounter.get("power", 0))
			enemy_power_values_are_level_scaled = enemy_power_values_are_level_scaled and deck_enemy_power >= 1 and deck_enemy_power <= 3
			enemy_road_has_clear_label = enemy_road_has_clear_label or (not card_data.has("title") and str(card_data.get("detail", "")) == "Enemy waits on this road.")
		elif card_data["category"] == "Road" and not encounter.is_empty():
			reward_road_count += 1
			reward_road_has_clear_label = reward_road_has_clear_label or str(card_data.get("detail", "")) in ["Plus food", "Plus treasure"]
			if encounter.get("type", "") == GameMap.ENCOUNTER_CACHE:
				cache_count += 1
				caches_have_exactly_one_item = caches_have_exactly_one_item and _cache_has_exactly_one_item(encounter)
		elif card_data["category"] == "Event":
			event_types[str(card_data.get("event_type", ""))] = true
	_assert(category_counts["Road"] == 24, "Expected 75 percent of the formula deck to be road cards")
	_assert(category_counts["Event"] == 8, "Expected the remaining formula deck cards to be events")
	_assert(not event_types.has("restart_map"), "Expected event deck not to include removed restart event")
	_assert(event_types.has(GameConstants.EVENT_DESTROY_TILE), "Expected event deck to include Mirage")
	_assert(event_types.has(GameConstants.EVENT_DRAW_TWO), "Expected event deck to include Idea")
	_assert(event_types.has(GameConstants.EVENT_ROTATE_TILE), "Expected event deck to include Doubt")
	_assert(event_types.has(GameConstants.EVENT_LUCKY_FIND), "Expected event deck to include Lucky Find")
	_assert(event_types.has(GameConstants.EVENT_TROUBLE), "Expected event deck to include Trouble")
	for shop_only_type in [
		GameConstants.EVENT_CLEAR_PATH,
		GameConstants.EVENT_WILD_BERRIES,
		GameConstants.EVENT_LOST_BELONGINGS,
		GameConstants.EVENT_SLEEP,
	]:
		_assert(not event_types.has(shop_only_type), "Expected shop-only special cards to stay out of generated decks")
	_assert(typed_definition_count == deck_controller.deck.size(), "Expected generated draw pile cards to keep typed card definitions")
	_assert(enemy_road_count == 6, "Expected enemy road count to use level and map size")
	_assert(enemy_power_values_are_level_scaled, "Expected level one enemy power to stay between one and three")
	_assert(enemy_road_has_clear_label, "Expected enemy road cards to be clearly named and described")
	_assert(reward_road_count == 8, "Expected four berry roads and four loot roads on a 9x9 level one map")
	_assert(reward_road_has_clear_label, "Expected reward encounter road cards to be clearly described")
	_assert(cache_count > 0, "Expected reward road cards to include treasure caches")
	_assert(caches_have_exactly_one_item, "Expected every treasure cache to contain exactly one item")

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

	var first_card = hand.cards[0]
	deck_controller.consume_card(first_card)
	_assert(hand.cards.size() == 4, "Expected using a card to draw one replacement")
	_assert(deck_controller.cards_remaining() == 27, "Expected replacement draw to remove one card from the deck")
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


func _cache_has_exactly_one_item(encounter: Dictionary) -> bool:
	var loot: Array = encounter.get("loot", [])
	return loot.size() == 1 and loot[0] is Dictionary and loot[0].get("kind", "") == "item"


func _has_definition(cards: Array[Dictionary], definition: Resource) -> bool:
	for card in cards:
		if card.get("tile_definition") == definition:
			return true
	return false
