extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HAND_SCENE := preload("res://ui/hand.tscn")
const PLACEMENT_SCRIPT := preload("res://scripts/placement_controller.gd")
const STRAIGHT := preload("res://data/road_straight.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")
const BRIDGE := preload("res://data/road_bridge.tres")


func _initialize() -> void:
	_test_add_and_clear_encounters()
	_test_only_enemies_can_be_added_to_bridges()
	quit()


func _test_add_and_clear_encounters() -> void:
	var fixture := _make_fixture()
	var root: Node = fixture["root"]
	var map: GameMap = fixture["map"]
	var roads: Roads = fixture["roads"]
	var hand: HandUI = fixture["hand"]
	var placement: PlacementController = fixture["placement"]
	var target := Vector2i(4, 7)

	var expected_types := [
		GameMap.ENCOUNTER_ENEMY,
		GameMap.ENCOUNTER_BERRY_BUSH,
		GameMap.ENCOUNTER_CACHE,
	]
	for expected_type in expected_types:
		var add_card := hand.cards[0]
		_assert(placement.begin_encounter_targeting(add_card), "Expected encounter event to enter targeting mode")
		_set_initial_preview(placement, target)
		_assert(placement.has_valid_preview(), "Expected empty adjacent road to accept an encounter")
		_assert(placement.confirm_placement(), "Expected encounter event to confirm")
		var encounter := map.get_encounter(target)
		_assert(str(encounter.get("type", "")) == expected_type, "Expected event to add its encounter type")
		_assert(str(roads.get_visual_tile(target).encounter_data.get("type", "")) == expected_type, "Expected event to update road visuals")
		if expected_type == GameMap.ENCOUNTER_ENEMY:
			_assert(encounter.get("revealed", false) == true, "Expected Trouble enemy to be revealed")
			_assert(int(encounter.get("power", 0)) == 2, "Expected Trouble to keep its generated power")

		var clear_card := hand.cards[0]
		_assert(placement.begin_encounter_targeting(clear_card), "Expected Clear Path to enter targeting mode")
		_set_initial_preview(placement, target)
		_assert(placement.has_valid_preview(), "Expected Clear Path to accept a road with an encounter")
		_assert(placement.confirm_placement(), "Expected Clear Path to confirm")
		_assert(map.get_encounter(target).is_empty(), "Expected Clear Path to remove the encounter without removing the road")
		_assert(map.get_tile(target) != null, "Expected Clear Path to leave the road in place")
		_assert(roads.get_visual_tile(target).encounter_data.is_empty(), "Expected Clear Path to update road visuals")

	var clear_without_encounter := hand.cards[0]
	_assert(placement.begin_encounter_targeting(clear_without_encounter), "Expected remaining Clear Path to enter targeting mode")
	_set_initial_preview(placement, target)
	_assert(not placement.has_valid_preview(), "Expected Clear Path to reject a road without an encounter")
	_assert(_get_hint(placement) == "No encounter here", "Expected empty Clear Path target to explain why it is invalid")
	placement.cancel_placement()

	root.queue_free()


func _test_only_enemies_can_be_added_to_bridges() -> void:
	var fixture := _make_fixture()
	var root: Node = fixture["root"]
	var map: GameMap = fixture["map"]
	var roads: Roads = fixture["roads"]
	var hand: HandUI = fixture["hand"]
	var placement: PlacementController = fixture["placement"]
	var target := Vector2i(4, 7)
	roads.force_place_tile(target, BRIDGE, 0)

	var trouble_card := hand.cards[0]
	_assert(placement.begin_encounter_targeting(trouble_card), "Expected Trouble to enter targeting mode")
	_set_initial_preview(placement, target)
	_assert(placement.has_valid_preview(), "Expected Trouble to be valid on bridges")
	_assert(placement.confirm_placement(), "Expected Trouble to add an enemy to a bridge")
	_assert(str(map.get_encounter(target).get("type", "")) == GameMap.ENCOUNTER_ENEMY, "Expected bridge enemy to be stored")

	var clear_card := hand.cards[0]
	_assert(placement.begin_encounter_targeting(clear_card), "Expected Clear Path to enter targeting mode")
	_set_initial_preview(placement, target)
	_assert(placement.has_valid_preview(), "Expected Clear Path to remove a bridge enemy")
	_assert(placement.confirm_placement(), "Expected Clear Path to confirm on a bridge enemy")
	_assert(map.get_encounter(target).is_empty(), "Expected Clear Path to clear the bridge enemy")

	var berries_card := _card_by_event_type(hand, GameConstants.EVENT_WILD_BERRIES)
	_assert(placement.begin_encounter_targeting(berries_card), "Expected Wild Berries to enter targeting mode")
	_set_initial_preview(placement, target)
	_assert(not placement.has_valid_preview(), "Expected Wild Berries to be invalid on bridges")
	_assert(_get_hint(placement) == "Only enemies on bridges", "Expected bridge reward target to explain why it is invalid")
	placement.cancel_placement()

	var lost_belongings_card := _card_by_event_type(hand, GameConstants.EVENT_LOST_BELONGINGS)
	_assert(placement.begin_encounter_targeting(lost_belongings_card), "Expected Lost Belongings to enter targeting mode")
	_set_initial_preview(placement, target)
	_assert(not placement.has_valid_preview(), "Expected Lost Belongings to be invalid on bridges")
	_assert(_get_hint(placement) == "Only enemies on bridges", "Expected bridge loot target to explain why it is invalid")
	placement.cancel_placement()

	_assert(not roads.set_encounter(target, {"type": GameMap.ENCOUNTER_BERRY_BUSH}), "Expected Roads to reject berry bushes on bridges")
	_assert(map.get_encounter(target).is_empty(), "Expected rejected bridge berry to leave the map unchanged")

	root.queue_free()


func _make_fixture() -> Dictionary:
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
	hand.set_cards([
		_encounter_card("Trouble", GameConstants.EVENT_TROUBLE, {"type": GameMap.ENCOUNTER_ENEMY, "power": 2}),
		_clear_path_card(),
		_encounter_card("Wild Berries", GameConstants.EVENT_WILD_BERRIES, {"type": GameMap.ENCOUNTER_BERRY_BUSH, "loot": [{"kind": "food", "amount": 3}]}),
		_clear_path_card(),
		_encounter_card("Lost Belongings", GameConstants.EVENT_LOST_BELONGINGS, {"type": GameMap.ENCOUNTER_CACHE, "loot": [{"kind": "item", "item": {"name": "Walking Stick", "effect": "+1 Power", "power_bonus": 1}}]}),
		_clear_path_card(),
		_clear_path_card(),
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
	roads.force_place_tile(Vector2i(4, 7), STRAIGHT, 0)
	return {
		"root": root,
		"map": map,
		"roads": roads,
		"hand": hand,
		"placement": placement,
	}


func _encounter_card(title: String, event_type: String, encounter: Dictionary) -> Dictionary:
	return {
		"category": "Event",
		"title": title,
		"event_type": event_type,
		"encounter": encounter,
	}


func _clear_path_card() -> Dictionary:
	return {
		"category": "Event",
		"title": "Clear Path",
		"event_type": GameConstants.EVENT_CLEAR_PATH,
	}


func _set_initial_preview(placement: PlacementController, grid_position: Vector2i) -> void:
	placement.preview_position = grid_position
	placement.call("_refresh_preview")


func _get_hint(placement: PlacementController) -> String:
	var hint_label := placement.get_node("PlacementControls/PromptLabel") as Label
	return hint_label.text if hint_label.visible else ""


func _card_by_event_type(hand: HandUI, event_type: String) -> CardView:
	for card in hand.cards:
		if card.event_type == event_type:
			return card
	return null


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
