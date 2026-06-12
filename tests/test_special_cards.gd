extends SceneTree

const DECK_BUILDER_SCRIPT := preload("res://scripts/deck_builder.gd")

const SHOP_ONLY_EVENT_TYPES := [
	GameConstants.EVENT_CLEAR_PATH,
	GameConstants.EVENT_WILD_BERRIES,
	GameConstants.EVENT_LOST_BELONGINGS,
	GameConstants.EVENT_SLEEP,
]


func _initialize() -> void:
	var catalog_types := {}
	for card in ShopUI.SPECIAL_CARD_CATALOG:
		var event_type := str(card.get("event_type", ""))
		catalog_types[event_type] = true
		_assert(int(card.get("price", 0)) > 0 and int(card.get("price", 0)) < 22, "Expected special cards to be cheaper than the old 22 gold price")
	for event_type in SHOP_ONLY_EVENT_TYPES:
		_assert(catalog_types.has(event_type), "Expected every shop-only event to be sold in the shop")

	var wild_berries := _catalog_card(GameConstants.EVENT_WILD_BERRIES)
	var lost_belongings := _catalog_card(GameConstants.EVENT_LOST_BELONGINGS)
	_assert(wild_berries.get("encounter", {}).get("type", "") == GameMap.ENCOUNTER_BERRY_BUSH, "Expected bought Wild Berries to add a berry encounter")
	_assert(lost_belongings.get("encounter", {}).get("type", "") == GameMap.ENCOUNTER_CACHE, "Expected bought Lost Belongings to add a cache encounter")
	for encounter_type in GameConstants.PERMANENT_ENCOUNTER_TYPES:
		var special_road := _catalog_encounter_card(encounter_type)
		_assert(not special_road.is_empty(), "Expected permanent encounter road to be sold in the shop: %s" % encounter_type)
		_assert(special_road.get("category", "") == GameConstants.ROAD_CATEGORY, "Expected permanent encounter special to be a road card")
		_assert(not special_road.has("tile_definition"), "Expected permanent encounter catalog entry to receive its road shape when offered")
		_assert(_offers_cover_all_road_shapes(special_road), "Expected permanent encounter special to be offered on every normal road shape")
	_assert(_random_shop_offers_are_unique(), "Expected a shop roll never to contain duplicate special card types")
	_assert(_random_shop_rolls_cover_catalog(), "Expected random shop rolls to select from the full special-card catalog")

	var shop := ShopUI.new()
	shop.progression = {"gold": 200}
	shop.card_offers = []
	for card in ShopUI.SPECIAL_CARD_CATALOG:
		shop.card_offers.append(ShopUI.make_catalog_offer(card, RandomNumberGenerator.new()))
	for index in shop.card_offers.size():
		_assert(shop.buy_special_card(index), "Expected every special-card catalog entry to be purchasable")
	var purchased_cards: Array = shop.progression.get("player_special_cards", [])
	_assert(purchased_cards.size() == ShopUI.SPECIAL_CARD_CATALOG.size(), "Expected purchased cards to persist as player special cards")
	_assert(_card_with_type(purchased_cards, GameConstants.EVENT_WILD_BERRIES).get("encounter", {}).get("type", "") == GameMap.ENCOUNTER_BERRY_BUSH, "Expected purchased Wild Berries to keep its encounter payload")
	_assert(_card_with_type(purchased_cards, GameConstants.EVENT_LOST_BELONGINGS).get("encounter", {}).get("type", "") == GameMap.ENCOUNTER_CACHE, "Expected purchased Lost Belongings to keep its encounter payload")
	for encounter_type in GameConstants.PERMANENT_ENCOUNTER_TYPES:
		_assert(not _encounter_card(purchased_cards, encounter_type).is_empty(), "Expected purchased permanent encounter road to persist: %s" % encounter_type)
	shop.free()

	var builder := DECK_BUILDER_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var generated_cards := builder.make_deck(40, rng, {
		"level": 2,
		"map_size": 7,
		"road_count": 0,
		"road_distribution": {},
		"road_definitions": {},
	})
	_assert(not _contains_any_event(generated_cards, SHOP_ONLY_EVENT_TYPES), "Expected shop-only events to stay out of generated base and level decks")
	var level_cards := builder.make_level_specific_cards(2, {})
	_assert(not _contains_any_event(level_cards, SHOP_ONLY_EVENT_TYPES), "Expected shop-only events to stay out of level-specific injection")
	builder.free()
	quit()


func _catalog_card(event_type: String) -> Dictionary:
	return _card_with_type(ShopUI.SPECIAL_CARD_CATALOG, event_type)


func _catalog_encounter_card(encounter_type: String) -> Dictionary:
	return _encounter_card(ShopUI.SPECIAL_CARD_CATALOG, encounter_type)


func _encounter_card(cards: Array, encounter_type: String) -> Dictionary:
	for card in cards:
		if (card.get("encounter", {}) as Dictionary).get("type", "") == encounter_type:
			return card
	return {}


func _card_with_type(cards: Array, event_type: String) -> Dictionary:
	for card in cards:
		if card.get("event_type", "") == event_type:
			return card
	return {}


func _contains_any_event(cards: Array[Dictionary], event_types: Array) -> bool:
	for card in cards:
		if str(card.get("event_type", "")) in event_types:
			return true
	return false


func _offers_cover_all_road_shapes(card: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var road_names := {}
	for _index in 100:
		var offer := ShopUI.make_catalog_offer(card, rng)
		var definition: Resource = offer.get("tile_definition")
		if definition != null:
			road_names[str(definition.get("display_name"))] = true
			_assert(GameConstants.card_signature(offer).begins_with("special_road:"), "Expected offered permanent encounter road to keep a special-road signature")
	return road_names.size() == ShopUI.SPECIAL_ROAD_DEFINITIONS.size()


func _random_shop_offers_are_unique() -> bool:
	for seed in 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var signatures := {}
		for offer in ShopUI.make_unique_catalog_offers(rng, ShopUI.CARD_OFFER_COUNT):
			var signature := _catalog_type_signature(offer)
			if signatures.has(signature):
				return false
			signatures[signature] = true
	return true


func _random_shop_rolls_cover_catalog() -> bool:
	var seen := {}
	for seed in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for offer in ShopUI.make_unique_catalog_offers(rng, ShopUI.CARD_OFFER_COUNT):
			seen[_catalog_type_signature(offer)] = true
	return seen.size() == ShopUI.SPECIAL_CARD_CATALOG.size()


func _catalog_type_signature(card: Dictionary) -> String:
	var encounter_type := str((card.get("encounter", {}) as Dictionary).get("type", ""))
	if not encounter_type.is_empty():
		return "encounter:%s" % encounter_type
	return "event:%s" % str(card.get("event_type", ""))


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
