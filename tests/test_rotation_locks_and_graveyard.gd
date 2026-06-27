extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const HAND_SCENE := preload("res://ui/hand.tscn")
const DECK_CONTROLLER_SCENE := preload("res://scenes/deck_controller.tscn")
const PLACEMENT_SCRIPT := preload("res://scripts/placement_controller.gd")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")

var failures := 0


func _init() -> void:
	var fixture := _make_fixture()
	await process_frame
	var deck: DeckController = fixture["deck"]
	deck.level = 3
	deck.shuffle_seed = 31415
	deck.start_run()
	var randomized_road_rotations := 0
	for card in deck.starting_deck:
		if card.get("category", "") != GameConstants.ROAD_CATEGORY:
			continue
		_assert(card.has("rotation_steps"), "Expected every generated road card to have a starting rotation")
		var starting_rotation := int(card.get("rotation_steps", -1))
		_assert(starting_rotation >= 0 and starting_rotation <= 3, "Expected road starting rotation to be normalized")
		if starting_rotation != 0:
			randomized_road_rotations += 1
	_assert(randomized_road_rotations > 0, "Expected generated road cards not to all use the default rotation")
	var level_locks := 0
	for card in deck.deck_components[GameConstants.DECK_SOURCE_LEVEL]:
		if bool(card.get("rotation_locked", false)):
			level_locks += 1
	_assert(level_locks == 2, "Expected Level 3 to pre-lock level - 1 road cards")

	var graveyards := 0
	for card in deck.deck_components[GameConstants.DECK_SOURCE_BASE]:
		var encounter: Dictionary = card.get("encounter", {})
		if str(encounter.get("type", "")) == GameConstants.ENCOUNTER_GRAVEYARD:
			graveyards += 1
	_assert(graveyards == 1, "Expected exactly one Graveyard on a base road")

	var hand: HandUI = fixture["hand"]
	hand.set_cards([{
		"category": GameConstants.ROAD_CATEGORY,
		"tile_definition": STRAIGHT,
		"deck_source": GameConstants.DECK_SOURCE_BASE,
		"rotation_locked": true,
		"rotation_steps": 1,
	}])
	var placement: PlacementController = fixture["placement"]
	var locked_card := hand.cards[0]
	_assert(placement.begin_placement(locked_card), "Expected locked road to enter placement")
	_assert(placement.rotation_steps == 1, "Expected locked road to keep its starting rotation")
	placement.rotate_preview()
	_assert(placement.rotation_steps == 1, "Expected locked road not to rotate before placement")
	placement.cancel_placement()

	hand.set_cards([{
		"category": GameConstants.ROAD_CATEGORY,
		"tile_definition": STRAIGHT,
		"deck_source": GameConstants.DECK_SOURCE_BASE,
		"rotation_steps": 1,
	}])
	deck.deck.clear()
	_assert(deck.lock_random_unlocked_base_road_card(), "Expected Graveyard to lock an unlocked base hand card")
	_assert(hand.cards[0].rotation_locked and hand.cards[0].rotation_steps == 1, "Expected Graveyard lock to preserve current rotation")
	_assert(not deck.lock_random_unlocked_base_road_card(), "Expected no effect when every remaining base road is locked")
	var permanent_locks := deck.player_locked_base_cards.duplicate(true)
	_assert(permanent_locks.size() == 1, "Expected Graveyard to record a permanent base-deck lock")
	deck.set_player_deck_modifiers([], [], permanent_locks)
	deck.start_run()
	var restored_lock_count := 0
	for card in deck.deck_components[GameConstants.DECK_SOURCE_BASE]:
		if bool(card.get("rotation_locked", false)) and GameConstants.card_signature(card) == str(permanent_locks[0].get("signature", "")):
			restored_lock_count += 1
			_assert(int(card.get("rotation_steps", 0)) == 1, "Expected permanent lock to restore its saved rotation")
	_assert(restored_lock_count == 1, "Expected permanent lock to follow the rebuilt base deck")
	deck.set_player_deck_modifiers([], [], [])
	deck.start_run()
	var dream_restored_base_locks := 0
	for card in deck.deck_components[GameConstants.DECK_SOURCE_BASE]:
		if bool(card.get("rotation_locked", false)):
			dream_restored_base_locks += 1
	_assert(dream_restored_base_locks == 0, "Expected a Dream reset to discard Graveyard locks gained after level start")

	var validator := PlacementValidator.new()
	validator.setup(fixture["map"], fixture["player"], func() -> int: return 2)
	var roads: Roads = fixture["roads"]
	var target := Vector2i(4, 7)
	roads.force_place_tile(target, STRAIGHT, 1)
	_assert(not validator.get_valid_alternative_rotations(target).is_empty(), "Expected Doubt to find a playable alternative rotation")
	roads.force_place_tile(Vector2i(4, 6), STRAIGHT, 1)
	_assert(validator.get_valid_alternative_rotations(target).is_empty(), "Expected Doubt to reject rotations that mismatch a neighboring road")

	fixture["root"].queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)


func _make_fixture() -> Dictionary:
	var root_node := Node2D.new()
	root.add_child(root_node)
	var map := MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root_node.add_child(map)
	var roads := ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	root_node.add_child(roads)
	var player := PLAYER_SCENE.instantiate() as GamePlayer
	player.name = "Player"
	player.map_path = NodePath("../Map")
	root_node.add_child(player)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	root_node.add_child(ui)
	var hand := HAND_SCENE.instantiate() as HandUI
	hand.name = "Hand"
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hand.size = Vector2(360.0, 640.0)
	ui.add_child(hand)
	var deck := DECK_CONTROLLER_SCENE.instantiate() as DeckController
	deck.name = "DeckController"
	deck.map_path = NodePath("../Map")
	deck.hand_path = NodePath("../UI/Hand")
	deck.player_path = NodePath("../Player")
	root_node.add_child(deck)
	var placement := PLACEMENT_SCRIPT.new()
	placement.name = "PlacementController"
	placement.map_path = NodePath("../Map")
	placement.roads_path = NodePath("../Roads")
	placement.player_path = NodePath("../Player")
	placement.hand_path = NodePath("../UI/Hand")
	placement.deck_controller_path = NodePath("../DeckController")
	root_node.add_child(placement)
	return {"root": root_node, "map": map, "roads": roads, "player": player, "hand": hand, "deck": deck, "placement": placement}


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
