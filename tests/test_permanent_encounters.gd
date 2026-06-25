extends SceneTree

const LEVEL_SCENE := preload("res://scenes/level.tscn")

var failures := 0


func _init() -> void:
	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	await process_frame

	var player := level.get_node("Player") as GamePlayer
	var map := level.get_node("Map") as GameMap
	var roads := level.get_node("Roads") as Roads
	var deck := level.get_node("DeckController") as DeckController
	var encounter_ui := level.get_node("UI/Encounter")

	player.move_duration = 0.0
	player.food = 5
	player.gold = 2
	player.set_max_health(5)
	player.set_health(3)

	var target := Vector2i(map.get_start_position().x, map.get_start_position().y - 1)
	roads.force_place_tile(target, preload("res://data/road_straight.tres"), 0)
	roads.set_encounter(target, {"type": GameConstants.ENCOUNTER_CAMPFIRE})
	_assert(player.move_to(target), "Expected player to move onto Campfire")
	_assert(encounter_ui.visible, "Expected permanent encounter popup to open")
	_assert(encounter_ui.get_node_or_null("Panel/Margin/Stack/Resources") == null, "Expected encounter popup not to duplicate player resources")
	for encounter_type in GameConstants.PERMANENT_ENCOUNTER_TYPES:
		var marker_card := CardView.new()
		marker_card.encounter_data = {"type": encounter_type}
		_assert(marker_card._encounter_marker_texture() != null, "Expected permanent encounter card to have an image marker: %s" % encounter_type)
		marker_card.free()
	_assert(roads.get_visual_tile(target).get_node_or_null("Visuals/CampfireFlame") != null, "Expected Campfire to have a distinct 3D marker")
	_assert_marker(roads.get_visual_tile(target), GameConstants.ENCOUNTER_TAVERN, "TavernBody")
	_assert_marker(roads.get_visual_tile(target), GameConstants.ENCOUNTER_WITCH_HUT, "WitchHutBody")
	_assert_marker(roads.get_visual_tile(target), GameConstants.ENCOUNTER_SHRINE, "ShrinePillar")
	roads.get_visual_tile(target).set_encounter_data({"type": GameConstants.ENCOUNTER_CAMPFIRE})
	encounter_ui._trade()
	_assert(player.food == 3 and player.health == 4, "Expected Campfire to trade one post-move food for one health")
	encounter_ui.close()
	_assert(not map.get_encounter(target).is_empty(), "Expected Campfire encounter to remain after use")
	_assert(player.move_to(map.get_start_position()), "Expected player to backtrack from Campfire")
	_assert(player.move_to(target), "Expected player to revisit Campfire")
	_assert(encounter_ui.visible, "Expected permanent encounter popup to reopen on revisit")
	encounter_ui.close()
	player.food = 4

	encounter_ui.open({"type": GameConstants.ENCOUNTER_TAVERN})
	encounter_ui._trade()
	_assert(player.gold == 1 and player.food == 5, "Expected Tavern to trade one gold for one food")

	deck.deck = [_plain_road_card(), _plain_road_card()]
	var shrine_hand_count := (level.get_node("UI/Hand") as HandUI).cards.size()
	encounter_ui.open({"type": GameConstants.ENCOUNTER_SHRINE})
	encounter_ui._trade()
	_assert(player.food == 4, "Expected Shrine to cost one food")
	_assert((level.get_node("UI/Hand") as HandUI).cards.size() == shrine_hand_count + 2, "Expected Shrine to draw two cards")

	var special_count := deck.player_special_cards.size()
	encounter_ui.open({"type": GameConstants.ENCOUNTER_WITCH_HUT})
	var witch_offer_card := encounter_ui.get_node("Panel/Margin/Stack/OfferCard/Card") as CardView
	_assert(witch_offer_card.visible, "Expected Witch's Hut to show an actual card scene")
	_assert(witch_offer_card.title == str(encounter_ui._witch_offer.get("title", "")), "Expected Witch's Hut card scene to show the offered card")
	_assert(witch_offer_card.tile_definition == encounter_ui._witch_offer.get("tile_definition"), "Expected Witch's Hut card scene to show the offered road shape")
	var witch_offer_encounter := str((encounter_ui._witch_offer.get("encounter", {}) as Dictionary).get("type", ""))
	if witch_offer_card.category == GameConstants.ROAD_CATEGORY and witch_offer_encounter in GameConstants.REUSABLE_ENCOUNTER_TYPES:
		_assert((witch_offer_card.get_node("Title") as Label).text == str(witch_offer_card.tile_definition.get("display_name")), "Expected Witch's Hut special road preview to show the offered road shape")
		_assert(witch_offer_card._compact_detail_text() == "", "Expected Witch's Hut special road preview to hide effect text")
	else:
		_assert(not witch_offer_card._compact_detail_text().is_empty(), "Expected Witch's Hut card scene to show a compact effect")
	var hand_count := (level.get_node("UI/Hand") as HandUI).cards.size()
	player.set_health(5)
	encounter_ui._trade()
	_assert(deck.player_special_cards.size() == special_count + 1, "Expected Witch's Hut card to join permanent special deck")
	_assert((level.get_node("UI/Hand") as HandUI).cards.size() == hand_count + 1, "Expected Witch's Hut card to join hand immediately")

	encounter_ui.close()
	var hand := level.get_node("UI/Hand") as HandUI
	hand.set_cards([])
	deck.deck = [{
		"category": GameConstants.ROAD_CATEGORY,
		"tile_definition": preload("res://data/road_straight.tres"),
		"deck_source": GameConstants.DECK_SOURCE_BASE,
	}]
	roads.set_encounter(target, {"type": GameConstants.ENCOUNTER_GRAVEYARD})
	_assert(roads.get_visual_tile(target).get_node_or_null("Visuals/GraveCrossPost") != null, "Expected Graveyard to show crosses and gravestones")
	player.food = 4
	_assert(player.move_to(map.get_start_position()), "Expected player to leave Graveyard road")
	_assert(player.move_to(target), "Expected player to re-enter Graveyard")
	_assert(bool(deck.deck[0].get("rotation_locked", false)), "Expected entering Graveyard to lock an unlocked base draw-pile road")
	_assert(not map.get_encounter(target).is_empty(), "Expected Graveyard to remain after triggering")

	level.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)


func _plain_road_card() -> Dictionary:
	return {
		"category": GameConstants.ROAD_CATEGORY,
		"tile_definition": preload("res://data/road_straight.tres"),
	}


func _assert_marker(tile: RoadTile, encounter_type: String, marker_name: String) -> void:
	tile.set_encounter_data({"type": encounter_type})
	_assert(tile.get_node_or_null("Visuals/%s" % marker_name) != null, "Expected %s to have a distinct 3D marker" % encounter_type)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
