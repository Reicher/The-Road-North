extends SceneTree

const MAP_SCRIPT := preload("res://scripts/map.gd")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const HAND_SCRIPT := preload("res://scripts/hand_ui.gd")
const PLACEMENT_SCRIPT := preload("res://scripts/placement_controller.gd")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
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
	hand.set_cards([
		{
			"category": "Road",
			"tile_definition": STRAIGHT,
			"enemy": {
				"revealed": false,
				"health": 2,
				"max_health": 2,
				"attack": 1,
				"armor": 1,
			},
		},
		{"category": "Road", "tile_definition": CORNER},
	])

	var placement = PLACEMENT_SCRIPT.new()
	placement.name = "PlacementController"
	placement.map_path = NodePath("../Map")
	placement.roads_path = NodePath("../Roads")
	placement.player_path = NodePath("../Player")
	placement.hand_path = NodePath("../UI/Hand")
	root.add_child(placement)
	placement._ready()

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)

	var straight_card = hand.cards[0]
	var hand_rest_position: Vector2 = hand.position
	_assert(placement.begin_placement(straight_card), "Expected road card to enter placement mode")
	_assert(placement.is_placing(), "Expected placement mode to become active")
	_assert(not player.input_enabled, "Expected movement input to pause during placement")
	_assert(hand.get_focused_card() == null, "Expected placement mode to clear the focused card")
	_assert(not placement.has_valid_preview(), "Expected Use to wait for a map tap before showing a preview")
	_assert(placement.get_node("PlacementControls/PromptLabel").visible, "Expected Use to show placement prompt text")
	_assert(hand.position == hand_rest_position, "Expected placement mode to keep the hand in its separate panel")
	_assert(placement.get_node("PlacementControls").layer > ui.layer, "Expected placement buttons to appear above the hand UI")
	_assert(placement.get_node("PlacementControls/Buttons").visible, "Expected placement buttons to show before selecting a preview")
	_assert(placement.get_node("PlacementControls/Buttons/CancelButton").visible, "Expected cancel button to be available before selecting a preview")
	_assert(placement.get_node("PlacementControls/Buttons/RotateButton").disabled, "Expected rotate button to wait for a preview tile")
	_assert(placement.get_node("PlacementControls/Buttons/ConfirmButton").disabled, "Expected confirm button to stay disabled before a preview exists")
	var hint_positions := placement.get_placement_hint_positions()
	_assert(hint_positions.has(Vector2i(4, 7)), "Expected placement hints to include the adjacent tile above the player")
	_assert(hint_positions.has(Vector2i(3, 8)), "Expected placement hints to include a left-side tile that is valid after rotation")
	_assert(hint_positions.has(Vector2i(5, 8)), "Expected placement hints to include a right-side tile that is valid after rotation")
	_assert(not hint_positions.has(Vector2i(4, 6)), "Expected placement hints to ignore non-adjacent tiles")

	map.tile_pressed.emit(Vector2i(4, 6))
	_assert(not placement.has_valid_preview(), "Expected non-adjacent preview to be invalid")
	_assert(not placement.confirm_placement(), "Expected confirm to reject invalid preview")
	_assert(map.get_tile(Vector2i(4, 6)) == null, "Expected invalid confirm not to place a tile")
	_assert(hand.cards.has(straight_card), "Expected invalid confirm to keep the card in hand")

	map.tile_pressed.emit(Vector2i(4, 7))
	_assert(placement.has_valid_preview(), "Expected adjacent matching road to be valid")
	_assert(not placement.get_node("PlacementControls/PromptLabel").visible, "Expected placement prompt to hide after preview appears")
	_assert(not placement.get_node("PlacementControls/Buttons/RotateButton").disabled, "Expected rotate button to enable after selecting a preview")
	_assert(not placement.get_node("PlacementControls/Buttons/ConfirmButton").disabled, "Expected confirm button to enable for a valid preview")
	placement.rotate_preview()
	_assert(not placement.has_valid_preview(), "Expected rotated mismatch to become invalid")
	_assert(not placement.confirm_placement(), "Expected confirm to stay disabled for invalid rotation")

	placement.rotate_preview()
	placement.rotate_preview()
	placement.rotate_preview()
	_assert(placement.has_valid_preview(), "Expected rotating back to restore valid placement")
	_assert(placement.confirm_placement(), "Expected valid preview to place the road")
	_assert(map.get_tile(Vector2i(4, 7)) != null, "Expected confirmed placement to store map tile")
	_assert(map.get_tile(Vector2i(4, 7)).has("enemy"), "Expected enemy road card to place an enemy tile")
	_assert(map.get_tile(Vector2i(4, 7))["enemy"]["revealed"] == true, "Expected enemy to reveal when the road card is placed")
	_assert(roads.get_visual_tile(Vector2i(4, 7)) != null, "Expected confirmed placement to spawn visual tile")
	_assert(map.get_tile(Vector2i(4, 7))["enemy"]["health"] == 1, "Expected enemy road cards to place one-life enemies")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).enemy_data["health"] == 1, "Expected visual tile data to use one-life enemies")
	_assert(not hand.cards.has(straight_card), "Expected confirmed placement to consume the card")
	_assert(not placement.is_placing(), "Expected confirm to exit placement mode")
	_assert(player.input_enabled, "Expected movement input to resume after confirm")
	_assert(hand.position == hand_rest_position, "Expected hand to return after confirmed placement")
	_assert(placement.get_placement_hint_positions().is_empty(), "Expected confirmed placement to clear placement hint markers")

	var corner_card = hand.cards[0]
	_assert(placement.begin_placement(corner_card), "Expected another road card to enter placement mode")
	placement.cancel_placement()
	_assert(hand.cards.has(corner_card), "Expected cancel to keep the card in hand")
	_assert(not placement.is_placing(), "Expected cancel to exit placement mode")
	_assert(player.input_enabled, "Expected movement input to resume after cancel")
	_assert(hand.position == hand_rest_position, "Expected hand to return after cancelling placement")
	_assert(hand.get_focused_card() == null, "Expected cancelled placement to leave the hand unfocused")
	_assert(placement.get_placement_hint_positions().is_empty(), "Expected cancel to clear placement hint markers")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
