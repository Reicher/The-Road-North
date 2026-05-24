extends SceneTree

const MAP_SCRIPT := preload("res://scripts/map.gd")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const HAND_SCRIPT := preload("res://scripts/hand_ui.gd")
const DECK_CONTROLLER_SCRIPT := preload("res://scripts/deck_controller.gd")
const PLACEMENT_SCRIPT := preload("res://scripts/placement_controller.gd")
const STRAIGHT := preload("res://data/road_straight.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
	_test_destroy_neighbor_event()
	_test_draw_two_event()
	quit()


func _test_destroy_neighbor_event() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCRIPT.new()
	map.name = "Map"
	root.add_child(map)

	var roads = ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()

	var player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.start_position = Vector2i(4, 8)
	player.starting_food = 5
	player.move_duration = 0.0
	root.add_child(player)
	player._ready()

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
	hand.set_cards([_destroy_card_data()])

	var placement = PLACEMENT_SCRIPT.new()
	placement.name = "PlacementController"
	placement.map_path = NodePath("../Map")
	placement.roads_path = NodePath("../Roads")
	placement.player_path = NodePath("../Player")
	placement.hand_path = NodePath("../UI/Hand")
	placement.hand_placement_tween_duration = 0.0
	root.add_child(placement)
	placement._ready()

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 0), T_JUNCTION, 2)
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 0)
	roads.force_place_tile(Vector2i(6, 6), STRAIGHT, 1)
	var destroy_card = hand.cards[0]

	_assert(placement.begin_destroy_targeting(destroy_card), "Expected destroy event to enter targeting mode")
	_assert(not player.input_enabled, "Expected movement input to pause during targeting")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).highlight_enabled, "Expected neighboring placed tiles to be highlighted")
	_assert(placement.get_node("PlacementControls/Buttons").visible, "Expected targeting controls to appear immediately")
	_assert(not placement.get_node("PlacementControls/Buttons/RotateButton").visible, "Expected targeting controls to hide rotate")
	_assert(placement.get_node("PlacementControls/Buttons/ConfirmButton").disabled, "Expected target confirm to start disabled")

	map.tile_pressed.emit(Vector2i(4, 8))
	_assert(not placement.has_valid_preview(), "Expected start/player tile target to be invalid")
	_assert(not placement.confirm_placement(), "Expected invalid destroy target not to confirm")
	_assert(map.get_tile(Vector2i(4, 8)) != null, "Expected invalid destroy target to remain placed")
	_assert(hand.cards.has(destroy_card), "Expected invalid destroy confirm to keep the card")

	map.tile_pressed.emit(Vector2i(4, 0))
	_assert(not placement.has_valid_preview(), "Expected goal tile target to be invalid")

	map.tile_pressed.emit(Vector2i(6, 6))
	_assert(placement.has_valid_preview(), "Expected any non-endpoint placed tile to be valid")
	_assert(placement.confirm_placement(), "Expected valid destroy target to confirm")
	_assert(map.get_tile(Vector2i(6, 6)) == null, "Expected destroy event to remove the selected tile")
	_assert(roads.get_visual_tile(Vector2i(6, 6)) == null, "Expected destroy event to remove the visual tile")
	_assert(not hand.cards.has(destroy_card), "Expected confirmed destroy event to consume the card")
	_assert(player.input_enabled, "Expected movement input to resume after destroy")

	root.queue_free()


func _test_draw_two_event() -> void:
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
	deck_controller.hand_size = 1
	root.add_child(deck_controller)
	deck_controller._ready()

	hand.set_cards([_draw_two_card_data()])
	deck_controller.deck.clear()
	deck_controller.deck.append({"category": "Road", "tile_definition": STRAIGHT})
	deck_controller.deck.append({"category": "Road", "tile_definition": STRAIGHT})
	deck_controller.deck.append({"category": "Road", "tile_definition": STRAIGHT})
	deck_controller.drawn_count = 0

	var draw_card = hand.cards[0]
	hand.focus_card(draw_card)
	hand.card_use_requested.emit(draw_card)
	_assert(not hand.cards.has(draw_card), "Expected draw-two card to be consumed")
	_assert(hand.cards.size() == 3, "Expected draw-two to draw replacement plus two extra cards")
	_assert(deck_controller.cards_remaining() == 0, "Expected draw-two to draw whatever remains when the deck is short")
	_assert(deck_controller.drawn_count == 3, "Expected draw-two draws to be tracked")

	root.queue_free()


func _destroy_card_data() -> Dictionary:
	return {
		"category": "Event",
		"title": "Clear Road",
		"detail": "Destroy a neighboring placed tile.",
		"event_type": "destroy_neighbor",
	}


func _draw_two_card_data() -> Dictionary:
	return {
		"category": "Event",
		"title": "Supplies",
		"detail": "Draw two extra cards.",
		"event_type": "draw_two",
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
