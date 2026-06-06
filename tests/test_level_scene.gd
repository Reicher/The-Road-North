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
	var player := level.get_node("Player") as GamePlayer
	var camera := level.get_node("Camera3D") as Camera3D
	var typed_level := level as Level

	_assert(map != null, "Expected level scene to include a GameMap")
	_assert(roads != null, "Expected level scene to include Roads")
	_assert(deck_controller != null, "Expected level scene to include DeckController")
	_assert(hand != null, "Expected level scene to include HandUI")
	_assert(typed_level != null, "Expected level scene to use the Level script")
	_assert(loot != null, "Expected level scene to include LootUI")
	_assert(inventory != null, "Expected level scene to include InventoryUI")
	_assert(inventory.get_index() > loot.get_index(), "Expected inventory to sit above loot for backpack interaction")
	_assert(player.loot_ui_path == NodePath("../UI/Loot"), "Expected player to connect to LootUI")
	_assert(map.playable_width == 5 and map.playable_height == 5, "Expected level 001 to configure a 5x5 map")
	_assert(map.fixed_features.size() == 1, "Expected level 001 to include one fixed mountain feature")
	_assert(map.get_fixed_feature(Vector2i(2, 2))["type"] == GameMap.FEATURE_MOUNTAIN, "Expected level 001 mountain to sit in the map center")
	_assert(not map.can_place_tile(Vector2i(2, 2), {}), "Expected level 001 fixed mountain to block road placement")
	var map_visuals := map.get_node("MapVisuals")
	var playable_ground := map_visuals.get_node_or_null("PlayableGround/Ground") as MeshInstance3D
	_assert(playable_ground != null, "Expected map visuals to use one continuous playable ground surface")
	_assert((playable_ground.material_override as StandardMaterial3D).albedo_texture == null, "Expected playable ground to use a clean solid color")
	_assert(map_visuals.get_node_or_null("PlayableAreaBorder") != null, "Expected map visuals to keep a thin playable area outline")
	_assert(map_visuals.get_node_or_null("Cells/Cell_0_0/Ground") == null, "Expected playable cells not to render internal grid ground tiles")
	var playable_forest_cell := map_visuals.get_node("Cells/Cell_0_0")
	var outside_forest_cell := map_visuals.get_node("Forest/Forest_-1_-1")
	var outside_ground := outside_forest_cell.get_node("ForestGround") as MeshInstance3D
	_assert(playable_forest_cell.get_child_count() >= 6, "Expected playable empty cells to show dense forest")
	_assert(outside_forest_cell.get_child_count() >= 7, "Expected outside cells to use the same dense forest plus forest ground")
	_assert((outside_ground.material_override as StandardMaterial3D).albedo_texture == null, "Expected outside forest ground to use a clean solid color")
	_assert(playable_forest_cell.get_child(0).scale != playable_forest_cell.get_child(1).scale, "Expected forest trees to vary in shape and size")
	_assert(roads.seed_start_and_goal, "Expected level 001 to seed start and goal tiles")
	var start_visual := roads.get_visual_tile(map.get_start_position())
	_assert(start_visual.get_node_or_null("Visuals/Ground") == null, "Expected road tiles not to render square ground patches over the continuous map ground")
	_assert(roads.start_definition.get("visual_identity") == "house", "Expected start tile to use simple house visuals")
	_assert(roads.goal_definition.get("visual_identity") == "house", "Expected goal tile to use simple house visuals")
	_assert(deck_controller.hand_size == 4, "Expected level 001 to configure a four-card hand")
	_assert(is_equal_approx(deck_controller.road_card_ratio, 0.75), "Expected level 001 to configure road card ratio")
	_assert(is_equal_approx(deck_controller.enemy_road_card_ratio, 0.20), "Expected level 001 to configure enemy road card ratio")
	_assert(deck_controller.level == 1, "Expected level 001 enemies to use power one through three")
	_assert(is_equal_approx(deck_controller.reward_road_card_ratio, 0.15), "Expected level 001 to configure reward road card ratio")
	_assert(deck_controller.road_distribution["straight"] == 30.0, "Expected level 001 to configure road distribution")
	_assert(typed_level.state == Level.RunState.IDLE, "Expected level to start idle")
	player.move_started.emit(Vector2i(4, 7))
	_assert(typed_level.state == Level.RunState.PLAYER_MOVING, "Expected level to own player moving state")
	_assert(not player.input_enabled, "Expected level to disable player input while moving")
	_assert(camera.get("_following_player"), "Expected camera to follow the player while movement is active")
	var movement_midpoint := map.grid_to_world(Vector2i(2, 3))
	player.position = movement_midpoint
	camera.call("_process", 0.0)
	var expected_follow_target: Vector2 = camera.call("_get_clamped_target_for_world_position", movement_midpoint)
	_assert((camera.get("_target_xz") as Vector2).is_equal_approx(expected_follow_target), "Expected camera to track the player's tweened world position")
	player.moved.emit(Vector2i(4, 7))
	_assert(typed_level.state == Level.RunState.IDLE, "Expected level to return idle after movement")
	_assert(player.input_enabled, "Expected level to re-enable player input after movement")
	_assert(not camera.get("_following_player"), "Expected camera to stop continuously following after movement")

	var level_002 := LEVEL_002.instantiate()
	get_root().add_child(level_002)
	var second_map := level_002.get_node("Map") as GameMap
	var second_deck_controller := level_002.get_node("DeckController") as DeckController
	var second_camera := level_002.get_node("Camera3D") as Camera3D
	_assert(second_map.playable_width == 7 and second_map.playable_height == 7, "Expected level 002 to configure a 7x7 map")
	_assert(second_map.get_fixed_feature(Vector2i(3, 3))["type"] == GameMap.FEATURE_RIVER, "Expected level 002 to include a horizontal river")
	_assert(second_map.get_fixed_feature(Vector2i(2, 3))["type"] == GameMap.FEATURE_BRIDGE, "Expected level 002 river to include bridge crossings")
	_assert(not second_map.can_place_tile(Vector2i(3, 3), {}), "Expected river fixed features to block road placement")
	_assert(not second_map.can_place_tile(Vector2i(2, 3), {}), "Expected bridge fixed features to already provide a road crossing")
	_assert(second_map.get_fixed_feature_connections(Vector2i(2, 3))["north"] == true, "Expected level 002 bridges to connect across the river")
	_assert(second_deck_controller.hand_size == 4, "Expected level 002 to configure a four-card hand")
	_assert(second_deck_controller.level == 2, "Expected level 002 enemies to use power four through six")
	_assert(second_camera.reserved_bottom_path == NodePath("../UI/Hand"), "Expected camera to reserve the card hand area when sizing the map viewport")
	_assert(is_equal_approx(second_camera.pan_margin_x_tiles, 3.0), "Expected camera to allow visual forest margin beyond the left and right edges")
	_assert(is_equal_approx(second_camera.pan_margin_z_tiles, 3.0), "Expected camera to allow visual forest margin beyond the top and bottom edges")
	_assert(is_equal_approx(second_camera.zoom_in_visible_tile_width, 3.5), "Expected maximum zoom-in to keep adjacent placement tiles fully visible")
	var second_start_world := second_map.grid_to_world(second_map.get_start_position())
	var second_intro_size: float = second_camera.call("_get_initial_zoom_target")
	var second_intro_target: Vector2 = second_camera.call("_get_clamped_target_for_world_position", second_start_world, second_intro_size)
	_assert(is_equal_approx(second_intro_target.y, second_start_world.z), "Expected level 002 intro camera target to center on the start tile")
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
