extends SceneTree

const LEVEL_001 := preload("res://levels/level_001.tscn")
const LEVEL_002 := preload("res://levels/level_002.tscn")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var level := LEVEL_001.instantiate()
	get_root().add_child(level)
	await process_frame

	var map := level.get_node("Map") as GameMap
	var roads := level.get_node("Roads") as Roads
	var deck_controller := level.get_node("DeckController") as DeckController
	var hand := level.get_node("UI/Hand") as HandUI
	var loot := level.get_node("UI/Loot")
	var inventory := level.get_node("UI/Inventory")
	var hud_background := level.get_node("UI/HudBackground")
	var settings_menu := level.get_node("UI/SettingsMenu")
	var player := level.get_node("Player") as GamePlayer
	var camera := level.get_node("Camera3D") as Camera3D
	var level_name_label := level.get_node("UI/LevelName") as Label
	var placement := level.get_node("PlacementController") as PlacementController
	var typed_level := level as Level
	deck_controller.start_run()

	_assert(map != null, "Expected level scene to include a GameMap")
	_assert(roads != null, "Expected level scene to include Roads")
	_assert(deck_controller != null, "Expected level scene to include DeckController")
	_assert(hand != null, "Expected level scene to include HandUI")
	_assert(typed_level != null, "Expected level scene to use the Level script")
	_assert(loot != null, "Expected level scene to include LootUI")
	_assert(inventory != null, "Expected level scene to include InventoryUI")
	_assert(hud_background != null, "Expected level scene to include the shared HUD background panel")
	_assert(settings_menu != null, "Expected level scene to include a settings menu")
	_assert(level_name_label.text == "I - 1\nFirst Bend" and level_name_label.visible, "Expected the level intro to show compact chapter and level name during the opening map hold")
	_assert(inventory.get_index() > loot.get_index(), "Expected inventory to sit above loot for backpack interaction")
	_assert(player.loot_ui_path == NodePath("../UI/Loot"), "Expected player to connect to LootUI")
	_assert(map.playable_width == 5 and map.playable_height == 5, "Expected level 001 to configure a 5x5 map")
	_assert(map.fixed_features.size() == 1, "Expected level 001 to include one fixed mountain feature")
	_assert(map.get_fixed_feature(Vector2i(2, 2))["type"] == GameMap.FEATURE_MOUNTAIN, "Expected level 001 mountain to sit in the map center")
	_assert(not map.can_place_tile(Vector2i(2, 2), {}), "Expected level 001 fixed mountain to block road placement")
	var map_visuals := map.get_node("MapVisuals")
	var playable_ground := map_visuals.get_node_or_null("PlayableGround/Ground") as MeshInstance3D
	_assert(playable_ground != null, "Expected map visuals to use one continuous playable ground surface")
	_assert(playable_ground.material_override is ShaderMaterial, "Expected playable ground to use the subtle shared forest texture")
	var playable_grid := map_visuals.get_node_or_null("PlayableGrid")
	_assert(playable_grid != null, "Expected map visuals to show a thin grid over the playable ground")
	_assert(playable_grid.get_child_count() == map.playable_width + map.playable_height + 2, "Expected the playable grid to mark every tile boundary")
	var grid_line := playable_grid.get_child(0) as MeshInstance3D
	_assert((grid_line.mesh as BoxMesh).size.x < map.tile_size * 0.01, "Expected playable grid lines to stay very thin")
	_assert(map_visuals.get_node_or_null("PlayableAreaBorder") != null, "Expected map visuals to keep a thin playable area outline")
	_assert(map_visuals.get_node_or_null("Cells/Cell_0_0/Ground") == null, "Expected playable cells not to render internal grid ground tiles")
	var playable_forest_cell := map_visuals.get_node("Cells/Cell_0_0")
	var outside_forest_cell := map_visuals.get_node("Forest/Forest_-1_-1")
	var outside_ground := outside_forest_cell.get_node("ForestGround") as MeshInstance3D
	_assert(playable_forest_cell.get_child_count() >= 6, "Expected playable empty cells to show dense forest")
	_assert(outside_forest_cell.get_child_count() >= 15, "Expected outside cells to form a much thicker forest barrier")
	_assert(outside_forest_cell.get_child_count() > playable_forest_cell.get_child_count(), "Expected outside forest to be denser than playable empty tiles")
	_assert(outside_ground.material_override is ShaderMaterial, "Expected outside forest ground to share the subtle forest texture")
	_assert(playable_forest_cell.get_child(0).scale != playable_forest_cell.get_child(1).scale, "Expected forest trees to vary in shape and size")
	var sample_tree := playable_forest_cell.get_child(0) as Node3D
	_assert(sample_tree.get_node_or_null("Trunk") != null and sample_tree.get_node_or_null("CrownLower") != null and sample_tree.get_node_or_null("CrownUpper") != null, "Expected trees to use the shared layered low-poly model")
	_assert((sample_tree.get_node("CrownLower") as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Expected dense forest decoration not to cover the mobile map in hard shadows")
	var mountain := map_visuals.get_node_or_null("Cells/Cell_2_2/Mountain")
	_assert(mountain != null and mountain.get_node_or_null("MainPeak") != null and mountain.get_node_or_null("SidePeak") != null and mountain.get_node_or_null("SnowCap") != null, "Expected mountains to use the shared multi-peak model")
	_assert(roads.seed_start_and_goal, "Expected level 001 to seed start and goal tiles")
	var start_visual := roads.get_visual_tile(map.get_start_position())
	_assert(start_visual.get_node_or_null("Visuals/Ground") == null, "Expected road tiles not to render square ground patches over the continuous map ground")
	_assert(roads.start_definition.get("visual_identity") == "house", "Expected start tile to use simple house visuals")
	_assert(roads.goal_definition.get("visual_identity") == "house", "Expected goal tile to use simple house visuals")
	_assert(deck_controller.hand_size == 4, "Expected level 001 to configure a four-card hand")
	_assert(deck_controller.level == 1, "Expected level 001 enemies to use power one through three")
	_assert(deck_controller.total_cards() == 18, "Expected level 001 deck size to use its authored 5x5 map size")
	_assert(deck_controller.deck_components["base"].size() == 18 and deck_controller.deck_components["level"].is_empty(), "Expected level 001 to use only the base deck")
	_assert(_road_shape_counts(deck_controller.deck_components["base"]) == {
		"Straight Road": 4,
		"Corner": 4,
		"T-Junction": 3,
		"Four-Way Intersection": 2,
		"Dead End": 2,
	}, "Expected the base deck to use the fixed fifteen-road recipe")
	_assert(_encounter_counts(deck_controller.deck_components["base"]) == {
		GameMap.ENCOUNTER_ENEMY: 1,
		GameMap.ENCOUNTER_BERRY_BUSH: 1,
		GameMap.ENCOUNTER_CACHE: 1,
		GameMap.ENCOUNTER_GRAVEYARD: 1,
	}, "Expected exactly one enemy, berry bush, cache, and Graveyard on random base roads")
	_assert(_event_counts(deck_controller.deck_components["base"]) == {
		GameConstants.EVENT_DRAW_TWO: 1,
		GameConstants.EVENT_LUCKY_FIND: 1,
		GameConstants.EVENT_DESTROY_TILE: 1,
	}, "Expected the base deck to contain Idea, Lucky Find, and Mirage")
	_assert(deck_controller.deck_components["player_special"].is_empty(), "Expected player special cards to remain an empty concept")
	_assert(placement.get_sight() == 2, "Expected the player to start with Sight 2")
	inventory.add_item({"name": "Kikare", "effect": "+1 Sight", "sight_bonus": 1})
	_assert(placement.get_sight() == 3, "Expected Kikare in the inventory to grant +1 Sight")
	_assert(placement.is_in_sight(Vector2i(2, 1)), "Expected Kikare to allow three vertical tiles")
	_assert(placement.is_in_sight(Vector2i(1, 2)), "Expected Kikare to allow a Manhattan-distance-three tile")
	inventory.replace_item_at_slot(0, {"name": "Goldsmith's Scale", "effect": "Gain twice as much gold.", "gold_multiplier": 2})
	inventory.add_item({"name": "Field Medic's Bag", "effect": "+2 Max Health", "max_health_bonus": 2})
	player.add_gold(3)
	_assert(player.gold == 6, "Expected Goldsmith's Scale to double gold gained")
	_assert(player.health == 6 and player.max_health == 6, "Expected Field Medic's Bag to add two current and max health while carried")
	inventory.replace_item_at_slot(2, {})
	_assert(player.health == 4 and player.max_health == 4, "Expected removing Field Medic's Bag to remove its health bonus")
	_assert(typed_level.state == Level.RunState.IDLE, "Expected level to start idle")
	player.move_started.emit(Vector2i(4, 7))
	_assert(typed_level.state == Level.RunState.PLAYER_MOVING, "Expected level to own player moving state")
	_assert(player.input_enabled, "Expected level to keep destination input enabled while moving")
	_assert(not camera.get("_following_player"), "Expected camera not to snap directly to the player when movement starts")
	_assert(camera.get("_move_focus_tween") != null, "Expected camera to approach the player with a smooth transition")
	var movement_midpoint := map.grid_to_world(Vector2i(2, 3))
	player.position = movement_midpoint
	await create_timer(camera.move_focus_duration + 0.05).timeout
	_assert(camera.get("_following_player"), "Expected camera to begin continuous following after reaching the player")
	camera.call("_process", 0.0)
	var expected_follow_target: Vector2 = camera.call("_get_clamped_target_for_world_position", movement_midpoint)
	_assert((camera.get("_target_xz") as Vector2).is_equal_approx(expected_follow_target), "Expected camera to track the player's tweened world position")
	player.moved.emit(Vector2i(4, 7))
	_assert(typed_level.state == Level.RunState.IDLE, "Expected level to return idle after movement")
	_assert(player.input_enabled, "Expected level to re-enable player input after movement")
	_assert(not camera.get("_following_player"), "Expected camera to stop continuously following after movement")
	_assert(camera.get("_start_zoom_announced"), "Expected interrupting the intro camera to start fading the level name")
	_assert(typed_level.get("_level_name_tween") != null, "Expected the level name fade to begin with the camera zoom")

	var road_card: CardView
	for card in hand.cards:
		if card.category == GameConstants.ROAD_CATEGORY:
			road_card = card
			break
	_assert(road_card != null, "Expected the opening hand to include a road card for drag interaction")
	var card_position: Vector2 = road_card.get_global_transform_with_canvas() * (road_card.size * 0.5)
	var preview_position := map.grid_to_screen_position(Vector2i(2, 3))
	hand._on_card_pointer_pressed(road_card, card_position)
	hand._on_card_pointer_moved(road_card, preview_position)
	_assert(placement.active_card == road_card, "Expected dragging a road card above the hand to start placement")
	_assert(placement.get_node("SightFog").get("fogged_positions").size() == 11, "Expected Kikare to expand the normal area to Sight 3")
	_assert(placement.preview_position == Vector2i(2, 3), "Expected the initial road preview to follow the dragged card")
	_assert(hand.inactive, "Expected the hand to move down while dragging a card over the map")
	_assert(not placement.get_node("PlacementControls/Buttons").visible, "Expected placement buttons to stay hidden while dragging")
	hand._on_card_pointer_released(road_card, preview_position)
	_assert(placement.active_card == road_card, "Expected releasing a road card over the map to leave placement active")
	_assert(not hand.is_drag_active(), "Expected release to finish the hand drag while placement remains active")
	_assert(hand.inactive, "Expected the hand to remain down after releasing into placement")
	_assert(placement.get_node("PlacementControls/Buttons").visible, "Expected placement buttons to appear after releasing the card")
	var other_tile_position := map.grid_to_screen_position(Vector2i(1, 3))
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.position = other_tile_position
	mouse_press.pressed = true
	placement._unhandled_input(mouse_press)
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.position = other_tile_position
	mouse_release.pressed = false
	placement._unhandled_input(mouse_release)
	_assert(placement.preview_position == Vector2i(2, 3), "Expected clicking another map tile not to move the released preview")
	mouse_press.position = preview_position
	mouse_press.pressed = true
	placement._unhandled_input(mouse_press)
	var mouse_drag := InputEventMouseMotion.new()
	mouse_drag.position = other_tile_position
	mouse_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	placement._unhandled_input(mouse_drag)
	mouse_release.position = other_tile_position
	placement._unhandled_input(mouse_release)
	_assert(placement.preview_position == Vector2i(1, 3), "Expected dragging from the released preview to move it")
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.position = other_tile_position
	touch_press.pressed = true
	placement._unhandled_input(touch_press)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = preview_position
	placement._unhandled_input(touch_drag)
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.position = preview_position
	touch_release.pressed = false
	placement._unhandled_input(touch_release)
	_assert(placement.preview_position == Vector2i(2, 3), "Expected touch dragging from the released preview to move it")
	placement.cancel_placement()
	_assert(typed_level.state == Level.RunState.IDLE, "Expected cancelling the released preview to return the level to idle")
	_assert(not hand.inactive, "Expected cancelling placement to restore the hand")

	var level_002 := LEVEL_002.instantiate()
	get_root().add_child(level_002)
	var second_map := level_002.get_node("Map") as GameMap
	var second_deck_controller := level_002.get_node("DeckController") as DeckController
	var second_camera := level_002.get_node("Camera3D") as Camera3D
	second_deck_controller.start_run()
	_assert(second_map.playable_width == 7 and second_map.playable_height == 7, "Expected level 002 to configure a 7x7 map")
	_assert(second_map.get_fixed_feature(Vector2i(3, 3))["type"] == GameMap.FEATURE_RIVER, "Expected level 002 to include a horizontal river")
	_assert(second_map.get_fixed_feature(Vector2i(2, 3))["type"] == GameMap.FEATURE_BRIDGE, "Expected level 002 river to include bridge crossings")
	var second_visuals := second_map.get_node("MapVisuals")
	var river := second_visuals.get_node_or_null("Cells/Cell_3_3/River")
	var bridge := second_visuals.get_node_or_null("Cells/Cell_2_3/Bridge")
	_assert(river != null and river.get_node_or_null("Water") != null and river.get_node_or_null("BankNorth") != null and river.get_node_or_null("BankSouth") != null, "Expected rivers to use a shader-driven water surface with readable banks")
	_assert(bridge != null and bridge.get_node_or_null("Plank0") != null and bridge.get_node_or_null("Plank6") != null and bridge.get_node_or_null("Rail1") != null, "Expected bridges to use a readable plank-built model")
	_assert(not second_map.can_place_tile(Vector2i(3, 3), {}), "Expected river fixed features to block road placement")
	_assert(not second_map.can_place_tile(Vector2i(2, 3), {}), "Expected bridge fixed features to already provide a road crossing")
	_assert(second_map.get_fixed_feature_connections(Vector2i(2, 3))["north"] == true, "Expected level 002 bridges to connect across the river")
	_assert(second_deck_controller.hand_size == 4, "Expected level 002 to configure a four-card hand")
	_assert(second_deck_controller.level == 2, "Expected level 002 enemies to use power two through four")
	_assert(second_deck_controller.deck_components["base"].size() == 18 and second_deck_controller.deck_components["level"].size() == 12, "Expected level 002 to combine the base deck with its twelve-card authored pack")
	_assert(_count_enemy_cards(second_deck_controller.deck_components["base"]) == 1, "Expected level 002 to retain the level-one base deck recipe")
	_assert(_all_enemy_cards_use_level_range(second_deck_controller.deck_components["base"], 2), "Expected level 002 base-deck enemies to scale to the current level")
	_assert(_all_enemy_cards_use_level_range(second_deck_controller.deck_components["level"], 2), "Expected level 002 level-deck enemies and Trouble cards to use the current level")
	_assert(_road_shape_counts(second_deck_controller.deck_components["level"]) == {
		"Straight Road": 2,
		"Corner": 1,
		"T-Junction": 1,
		"Four-Way Intersection": 1,
		"Dead End": 2,
		"Bridge": 1,
	}, "Expected the authored Level 2 road recipe")
	_assert(_encounter_counts(second_deck_controller.deck_components["level"]) == {
		GameMap.ENCOUNTER_ENEMY: 3,
		GameMap.ENCOUNTER_BERRY_BUSH: 2,
		GameMap.ENCOUNTER_CACHE: 2,
	}, "Expected seven of the eight authored Level 2 roads to have encounters")
	_assert(_event_counts(second_deck_controller.deck_components["level"]) == {
		GameConstants.EVENT_TROUBLE: 1,
		GameConstants.EVENT_DRAW_TWO: 1,
		GameConstants.EVENT_LUCKY_FIND: 1,
		GameConstants.EVENT_DESTROY_TILE: 1,
	}, "Expected the authored Level 2 event recipe")
	_assert(second_deck_controller.deck_components["player_special"].is_empty(), "Expected player special cards to remain an empty concept")
	_assert(second_camera.reserved_bottom_path == NodePath("../UI/Hand"), "Expected camera to reserve the card hand area when sizing the map viewport")
	_assert(is_equal_approx(second_camera.pan_margin_x_tiles, 3.0), "Expected camera to allow visual forest margin beyond the left and right edges")
	_assert(is_equal_approx(second_camera.pan_margin_z_tiles, 3.0), "Expected camera to allow visual forest margin beyond the top and bottom edges")
	_assert(is_equal_approx(second_camera.initial_visible_tile_width, 5.5), "Expected the intro camera to start one zoom step farther out")
	_assert(is_equal_approx(second_camera.zoom_in_visible_tile_width, 4.0), "Expected maximum zoom-in to keep adjacent placement tiles fully visible")
	_assert(is_equal_approx(second_camera.player_screen_y_ratio, 0.67), "Expected automatic player focus to frame the player two thirds down the map viewport")
	var second_start_world := second_map.grid_to_world(second_map.get_start_position())
	var second_intro_size: float = second_camera.call("_get_initial_zoom_target")
	var second_intro_target: Vector2 = second_camera.call("_get_clamped_target_for_world_position", second_start_world, second_intro_size)
	_assert(second_intro_target.y < second_start_world.z, "Expected level 002 intro camera target to sit above the start tile so the player appears lower on screen")
	_assert(second_intro_size < second_camera.call("_get_zoom_out_limit"), "Expected portrait intro camera sequence to visibly zoom toward the player")

	level.queue_free()
	level_002.queue_free()
	await process_frame
	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _all_level_cards_are_difficult(cards: Array[Dictionary]) -> bool:
	for card in cards:
		var encounter: Dictionary = card.get("encounter", {})
		var event_type := str(card.get("event_type", ""))
		var tile_definition: Resource = card.get("tile_definition")
		var is_dead_end := tile_definition != null and str(tile_definition.get("display_name")) == "Dead End"
		if encounter.get("type", "") != GameMap.ENCOUNTER_ENEMY and event_type not in [
			GameConstants.EVENT_DESTROY_TILE,
			GameConstants.EVENT_ROTATE_TILE,
			GameConstants.EVENT_TROUBLE,
		] and not is_dead_end:
			return false
	return true


func _count_enemy_cards(cards: Array[Dictionary]) -> int:
	var count := 0
	for card in cards:
		if (card.get("encounter", {}) as Dictionary).get("type", "") == GameMap.ENCOUNTER_ENEMY:
			count += 1
	return count


func _road_shape_counts(cards: Array[Dictionary]) -> Dictionary:
	var counts := {}
	for card in cards:
		var definition: Resource = card.get("tile_definition")
		if definition == null:
			continue
		var display_name := str(definition.get("display_name"))
		counts[display_name] = int(counts.get(display_name, 0)) + 1
	return counts


func _encounter_counts(cards: Array[Dictionary]) -> Dictionary:
	var counts := {}
	for card in cards:
		if card.get("tile_definition") == null:
			continue
		var encounter_type := str((card.get("encounter", {}) as Dictionary).get("type", ""))
		if encounter_type.is_empty():
			continue
		counts[encounter_type] = int(counts.get(encounter_type, 0)) + 1
	return counts


func _event_counts(cards: Array[Dictionary]) -> Dictionary:
	var counts := {}
	for card in cards:
		var event_type := str(card.get("event_type", ""))
		if event_type.is_empty():
			continue
		counts[event_type] = int(counts.get(event_type, 0)) + 1
	return counts


func _all_enemy_cards_use_level_range(cards: Array[Dictionary], level: int) -> bool:
	for card in cards:
		var encounter: Dictionary = card.get("encounter", {})
		if encounter.get("type", "") != GameMap.ENCOUNTER_ENEMY:
			continue
		var power := int(encounter.get("power", 0))
		if power < level or power > level + 2:
			return false
	return true
