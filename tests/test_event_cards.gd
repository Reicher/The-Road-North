extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HAND_SCENE := preload("res://ui/hand.tscn")
const DECK_CONTROLLER_SCENE := preload("res://scenes/deck_controller.tscn")
const PLACEMENT_SCRIPT := preload("res://scripts/placement_controller.gd")
const STRAIGHT := preload("res://data/road_straight.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
	_test_destroy_tile_event()
	_test_rotate_tile_event()
	_test_draw_two_event()
	_test_lucky_find_event()
	quit()


func _test_destroy_tile_event() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var roads = ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()

	var player = PLAYER_SCENE.instantiate() as GamePlayer
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

	var hand = HAND_SCENE.instantiate() as HandUI
	hand.name = "Hand"
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
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
	root.add_child(placement)
	placement._ready()

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 0), T_JUNCTION, 2)
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 0)
	roads.force_place_tile(Vector2i(3, 7), STRAIGHT, 0)
	roads.force_place_tile(Vector2i(6, 6), STRAIGHT, 1)
	var destroy_card = hand.cards[0]

	_assert(placement.begin_destroy_targeting(destroy_card), "Expected destroy event to enter targeting mode")
	var sight_fog := placement.get_node("SightFog")
	_assert(sight_fog.visible, "Expected fog-of-war to appear during directed event targeting")
	_assert(not player.input_enabled, "Expected movement input to pause during targeting")
	_assert(not roads.get_visual_tile(Vector2i(4, 7)).highlight_enabled, "Expected valid targets not to be revealed")
	_assert(not roads.get_visual_tile(Vector2i(3, 7)).highlight_enabled, "Expected diagonal placed tiles not to be highlighted")
	_assert(not roads.get_visual_tile(Vector2i(6, 6)).highlight_enabled, "Expected remote placed tiles not to be highlighted")
	_assert(placement.get_node_or_null("TargetPreview") == null, "Expected no target preview before selecting a tile")
	_assert(placement.get_node("PlacementControls/Buttons").visible, "Expected targeting controls to appear immediately")
	_assert(not placement.get_node("PlacementControls/Buttons/RotateButton").visible, "Expected targeting controls to hide rotate")
	_assert(placement.get_node("PlacementControls/Buttons/ConfirmButton").disabled, "Expected target confirm to start disabled")
	_assert(placement.get_node("PlacementControls/Buttons/ConfirmButton").text.is_empty(), "Expected targeting to reuse icon confirm")
	_assert(placement.get_node("PlacementControls/Buttons/CancelButton").text.is_empty(), "Expected targeting to reuse icon cancel")

	map.tile_pressed.emit(Vector2i(4, 8))
	_assert(placement.preview_position == Vector2i(-1, -1), "Expected tapping the map not to select an event target")
	_set_initial_preview(placement, Vector2i(4, 8))
	_assert(not placement.has_valid_preview(), "Expected start/player tile target to be invalid")
	_assert(_get_hint(placement) == "You're standing here", "Expected player tile to take priority over protected tile")
	_assert(not placement.confirm_placement(), "Expected invalid destroy target not to confirm")
	_assert(map.get_tile(Vector2i(4, 8)) != null, "Expected invalid destroy target to remain placed")
	_assert(hand.cards.has(destroy_card), "Expected invalid destroy confirm to keep the card")

	map.tile_pressed.emit(Vector2i(4, 0))
	_assert(placement.preview_position == Vector2i(4, 8), "Expected tapping another tile not to move the event target")
	_drag_preview(placement, Vector2i(4, 8), Vector2i(4, 0))
	_assert(not placement.has_valid_preview(), "Expected goal tile target to be invalid")

	_drag_preview(placement, Vector2i(4, 0), Vector2i(3, 7))
	_assert(placement.has_valid_preview(), "Expected a Manhattan-distance-two tile to be within Sight 2")
	_assert(_get_hint(placement).is_empty(), "Expected a target within Sight to hide the helper text")
	var target_preview = placement.get("_target_preview")
	_assert(target_preview != null and target_preview.preview_color == PlacementController.VALID_COLOR, "Expected the selected target within Sight to show green")

	_drag_preview(placement, Vector2i(3, 7), Vector2i(4, 7))
	_assert(placement.has_valid_preview(), "Expected placed tile target to be valid")
	_assert(_get_hint(placement).is_empty(), "Expected valid event target to hide the helper text")
	_assert(target_preview.preview_color == PlacementController.VALID_COLOR, "Expected only the selected valid target to show green")

	_drag_preview(placement, Vector2i(4, 7), Vector2i(6, 6))
	_assert(not placement.has_valid_preview(), "Expected remote placed tile target to be outside Sight")
	_assert(not placement.confirm_placement(), "Expected remote destroy target not to confirm")
	_assert(map.get_tile(Vector2i(6, 6)) != null, "Expected remote tile to remain placed")

	_drag_preview(placement, Vector2i(6, 6), Vector2i(4, 7))
	_assert(placement.confirm_placement(), "Expected valid destroy target to confirm")
	_assert(map.get_tile(Vector2i(4, 7)) == null, "Expected destroy event to remove the selected adjacent tile")
	_assert(roads.get_visual_tile(Vector2i(4, 7)) == null, "Expected destroy event to remove the adjacent visual tile")
	_assert(not hand.cards.has(destroy_card), "Expected confirmed destroy event to consume the card")
	_assert(player.input_enabled, "Expected movement input to resume after destroy")
	_assert(not sight_fog.visible, "Expected fog-of-war to disappear after targeting")

	root.queue_free()


func _test_rotate_tile_event() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var roads = ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()

	var player = PLAYER_SCENE.instantiate() as GamePlayer
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

	var hand = HAND_SCENE.instantiate() as HandUI
	hand.name = "Hand"
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hand.size = Vector2(360.0, 640.0)
	ui.add_child(hand)
	hand._ready()
	hand.set_cards([_rotate_card_data()])

	var placement = PLACEMENT_SCRIPT.new()
	placement.name = "PlacementController"
	placement.map_path = NodePath("../Map")
	placement.roads_path = NodePath("../Roads")
	placement.player_path = NodePath("../Player")
	placement.hand_path = NodePath("../UI/Hand")
	root.add_child(placement)
	placement._ready()

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 0), T_JUNCTION, 2)
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 1)
	roads.force_place_tile(Vector2i(6, 6), STRAIGHT, 1)
	var rotate_card = hand.cards[0]

	_assert(placement.begin_rotate_targeting(rotate_card), "Expected rotate event to enter targeting mode")
	_assert(not roads.get_visual_tile(Vector2i(4, 7)).highlight_enabled, "Expected valid rotate targets not to be revealed")
	_assert(not roads.get_visual_tile(Vector2i(6, 6)).highlight_enabled, "Expected remote rotate targets not to be highlighted")
	_set_initial_preview(placement, Vector2i(4, 8))
	_assert(not placement.has_valid_preview(), "Expected player tile rotate target to be invalid")
	_drag_preview(placement, Vector2i(4, 8), Vector2i(6, 6))
	_assert(not placement.has_valid_preview(), "Expected remote rotate target to be outside Sight")
	_drag_preview(placement, Vector2i(6, 6), Vector2i(4, 7))
	_assert(not placement.has_valid_preview(), "Expected unchanged rotate target not to be confirmable")
	var target_preview = placement.get("_target_preview")
	_assert(target_preview != null and target_preview.preview_color == PlacementController.VALID_COLOR, "Expected selected valid rotate target to show green")
	_assert(not placement.confirm_placement(), "Expected unchanged rotate target not to confirm")
	placement.rotate_preview()
	_assert(placement.has_valid_preview(), "Expected changed rotate target to be confirmable")
	_assert(placement.confirm_placement(), "Expected changed rotate target to confirm")
	var rotated_tile: Dictionary = map.get_tile(Vector2i(4, 7))
	_assert(rotated_tile["rotation_steps"] != 1, "Expected rotate event to select a different playable orientation")
	_assert(rotated_tile["connections"]["north"] == true, "Expected rotated tile connections to update")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).rotation_steps == rotated_tile["rotation_steps"], "Expected rotate event to update the visual tile")
	_assert(not hand.cards.has(rotate_card), "Expected confirmed rotate event to consume the card")

	root.queue_free()

	_test_rotate_tile_cancel_restores_original()
	_test_rotate_tile_reselect_restores_original()


func _test_rotate_tile_cancel_restores_original() -> void:
	var fixture := _make_rotate_fixture()
	var root: Node = fixture["root"]
	var map: GameMap = fixture["map"]
	var roads: Roads = fixture["roads"]
	var hand: HandUI = fixture["hand"]
	var placement: PlacementController = fixture["placement"]
	var rotate_card: CardView = hand.cards[0]

	placement.begin_rotate_targeting(rotate_card)
	_set_initial_preview(placement, Vector2i(4, 7))
	placement.rotate_preview()
	placement.rotate_preview()
	hand.card_drag_moved.emit(rotate_card, Vector2.ZERO, false)
	var restored_tile: Dictionary = map.get_tile(Vector2i(4, 7))
	_assert(restored_tile["rotation_steps"] == 1, "Expected cancelling Doubt to restore original rotation")
	_assert(restored_tile["connections"]["east"] == true, "Expected cancelling Doubt to restore original connections")
	_assert(roads.get_visual_tile(Vector2i(4, 7)).rotation_steps == 1, "Expected cancelling Doubt to restore visual rotation")
	_assert(hand.cards.has(rotate_card), "Expected dragging Doubt back into the hand to keep the card")

	root.queue_free()


func _test_rotate_tile_reselect_restores_original() -> void:
	var fixture := _make_rotate_fixture()
	var root: Node = fixture["root"]
	var map: GameMap = fixture["map"]
	var roads: Roads = fixture["roads"]
	var hand: HandUI = fixture["hand"]
	var placement: PlacementController = fixture["placement"]
	var rotate_card: CardView = hand.cards[0]

	roads.force_place_tile(Vector2i(3, 8), STRAIGHT, 0)
	placement.begin_rotate_targeting(rotate_card)
	_set_initial_preview(placement, Vector2i(4, 7))
	placement.rotate_preview()
	_drag_preview(placement, Vector2i(4, 7), Vector2i(3, 8))
	var original_tile: Dictionary = map.get_tile(Vector2i(4, 7))
	_assert(original_tile["rotation_steps"] == 1, "Expected selecting a new Doubt target to restore the previous target")
	_assert(not placement.has_valid_preview(), "Expected newly selected unchanged target to wait for rotation")
	placement.rotate_preview()
	_assert(placement.confirm_placement(), "Expected changed second target to confirm")
	var second_tile: Dictionary = map.get_tile(Vector2i(3, 8))
	_assert(second_tile["rotation_steps"] == 1, "Expected second selected tile to keep confirmed rotation")
	_assert(roads.get_visual_tile(Vector2i(3, 8)).rotation_steps == 1, "Expected second visual tile to keep confirmed rotation")
	_assert(not hand.cards.has(rotate_card), "Expected confirmed Doubt to consume the card")

	root.queue_free()


func _test_draw_two_event() -> void:
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
	_assert(deck_controller.play_immediate_event(draw_card), "Expected draw-two to be a playable immediate event")
	_assert(not hand.cards.has(draw_card), "Expected draw-two card to be consumed")
	_assert(hand.cards.size() == 3, "Expected draw-two to draw replacement plus two extra cards")
	_assert(deck_controller.cards_remaining() == 0, "Expected draw-two to draw whatever remains when the deck is short")
	_assert(deck_controller.drawn_count == 3, "Expected draw-two draws to be tracked")

	root.queue_free()


func _test_lucky_find_event() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var player = PLAYER_SCENE.instantiate() as GamePlayer
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.starting_food = 5
	player.starting_gold = 1
	player.move_duration = 0.0
	root.add_child(player)
	player._ready()

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
	deck_controller.player_path = NodePath("../Player")
	deck_controller.hand_size = 1
	root.add_child(deck_controller)
	deck_controller._ready()

	hand.set_cards([_lucky_find_card_data()])
	deck_controller.deck.clear()

	var lucky_card = hand.cards[0]
	_assert(deck_controller.play_immediate_event(lucky_card), "Expected lucky find to be a playable immediate event")
	_assert(not hand.cards.has(lucky_card), "Expected lucky find card to be consumed")
	_assert(player.food == 8 or player.gold == 5, "Expected lucky find to grant food or gold")

	root.queue_free()


func _make_rotate_fixture() -> Dictionary:
	var root := Node2D.new()
	get_root().add_child(root)

	var map = MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)

	var roads = ROADS_SCRIPT.new()
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()

	var player = PLAYER_SCENE.instantiate() as GamePlayer
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

	var hand = HAND_SCENE.instantiate() as HandUI
	hand.name = "Hand"
	hand.demo_cards_enabled = false
	hand.layout_duration = 0.0
	hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hand.size = Vector2(360.0, 640.0)
	ui.add_child(hand)
	hand._ready()
	hand.set_cards([_rotate_card_data()])

	var placement = PLACEMENT_SCRIPT.new()
	placement.name = "PlacementController"
	placement.map_path = NodePath("../Map")
	placement.roads_path = NodePath("../Roads")
	placement.player_path = NodePath("../Player")
	placement.hand_path = NodePath("../UI/Hand")
	root.add_child(placement)
	placement._ready()

	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	roads.force_place_tile(Vector2i(4, 0), T_JUNCTION, 2)
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 1)
	return {
		"root": root,
		"map": map,
		"roads": roads,
		"hand": hand,
		"placement": placement,
	}


func _destroy_card_data() -> Dictionary:
	return {
		"category": "Event",
		"title": "Mirage",
		"detail": "Destroy a placed tile.",
		"event_type": "destroy_tile",
	}


func _draw_two_card_data() -> Dictionary:
	return {
		"category": "Event",
		"title": "Idea",
		"detail": "Draw two extra cards.",
		"event_type": "draw_two",
	}


func _rotate_card_data() -> Dictionary:
	return {
		"category": "Event",
		"title": "Doubt",
		"detail": "Rotate a placed tile.",
		"event_type": "rotate_tile",
	}


func _lucky_find_card_data() -> Dictionary:
	return {
		"category": "Event",
		"title": "Lucky Find",
		"detail": "Gain food or gold.",
		"event_type": "lucky_find",
	}


func _set_initial_preview(placement: PlacementController, grid_position: Vector2i) -> void:
	placement.preview_position = grid_position
	placement.call("_refresh_preview")


func _drag_preview(placement: PlacementController, from: Vector2i, to: Vector2i) -> void:
	_assert(placement.call("_try_start_preview_drag", from, -1), "Expected dragging to start on the active event target")
	placement.call("_move_preview_drag", to)
	placement.call("_finish_preview_drag")


func _get_hint(placement: PlacementController) -> String:
	var hint_label := placement.get_node("PlacementControls/PromptLabel") as Label
	return hint_label.text if hint_label.visible else ""


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
