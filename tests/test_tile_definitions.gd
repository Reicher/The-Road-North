extends SceneTree

const TILE_SCENE := preload("res://scenes/tile.tscn")
const TILE_SIZE := 96.0
const RoadPath = preload("res://scripts/road_path.gd")

const ROAD_DEFINITION_PATHS: Array[String] = [
	"res://data/road_straight.tres",
	"res://data/road_corner.tres",
	"res://data/road_t_junction.tres",
	"res://data/road_four_way.tres",
	"res://data/road_dead_end.tres",
	"res://data/start_camp.tres",
	"res://data/goal_town.tres",
]


func _initialize() -> void:
	for path in ROAD_DEFINITION_PATHS:
		var definition := load(path)
		_assert(definition != null, "Expected road definition to load: %s" % path)

		var tile := TILE_SCENE.instantiate()
		_assert(tile is RoadTile, "Expected tile scene to instantiate RoadTile")
		tile.definition = definition
		tile.tile_size = TILE_SIZE
		get_root().add_child(tile)
		await process_frame
		_assert(is_equal_approx(tile.tile_size, TILE_SIZE), "Expected tile size to remain grid aligned")
		_assert(_count_named_children(tile.get_node("Visuals"), "RoadCenter") == 1, "Expected roads to render without a second shoulder frame: %s" % path)
		_assert(_count_named_children(tile.get_node("Visuals"), "RoadShoulder") == 0, "Expected roads not to use a dark outline frame: %s" % path)
		_assert(_count_named_children(tile.get_node("Visuals"), "RoadFeatherInner") == 1 and _count_named_children(tile.get_node("Visuals"), "RoadFeatherOuter") == 1, "Expected road sides to fade into the ground: %s" % path)
		var road_center := tile.get_node("Visuals/RoadCenter") as MeshInstance3D
		var road_material := road_center.material_override as ShaderMaterial
		_assert(road_material != null and road_material.shader.code.contains("texture_value"), "Expected roads to use subtle procedural grain: %s" % path)
		_assert(road_center.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Expected flat roads not to cast shadows: %s" % path)
		_assert(road_center.mesh is ArrayMesh, "Expected each road tile to use one continuous generated mesh: %s" % path)
		for direction in ["North", "East", "South", "West"]:
			var road_arm := tile.get_node_or_null("Visuals/Road%s" % direction) as MeshInstance3D
			_assert(road_arm == null, "Expected road center and arms to share one continuous mesh: %s" % path)
		tile.queue_free()

	var straight := load("res://data/road_straight.tres")
	var straight_openings: Dictionary = straight.get_rotated_openings(1)
	_assert(straight_openings["east"] == true, "Expected rotated straight road to open east")
	_assert(straight_openings["west"] == true, "Expected rotated straight road to open west")
	_assert(straight_openings["north"] == false, "Expected rotated straight road to close north")
	_assert(straight_openings["south"] == false, "Expected rotated straight road to close south")

	var corner_tile := TILE_SCENE.instantiate()
	corner_tile.definition = load("res://data/road_corner.tres")
	corner_tile.rotate_clockwise()
	var corner_openings: Dictionary = corner_tile.get_openings()
	_assert(corner_openings["east"] == true, "Expected rotated corner to open east")
	_assert(corner_openings["south"] == true, "Expected rotated corner to open south")
	_assert(corner_openings["north"] == false, "Expected rotated corner to close north")
	_assert(corner_openings["west"] == false, "Expected rotated corner to close west")
	var corner_centerline := RoadPath.get_centerline(corner_openings, TILE_SIZE)
	_assert(corner_centerline[0].is_equal_approx(Vector2(TILE_SIZE * 0.5, 0.0)), "Expected curved corner to start at its east edge")
	_assert(corner_centerline[-1].is_equal_approx(Vector2(0.0, TILE_SIZE * 0.5)), "Expected curved corner to end at its south edge")
	_assert(corner_centerline[corner_centerline.size() / 2].distance_to(Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)) > TILE_SIZE * 0.45, "Expected corner centerline to follow a quarter-circle instead of a right angle")
	get_root().add_child(corner_tile)
	corner_tile.encounter_data = {"type": GameMap.ENCOUNTER_ENEMY, "revealed": true, "power": 1}
	await process_frame
	var curved_enemy := corner_tile.get_node("Enemy") as EnemyView
	var corner_anchor := RoadPath.get_anchor_offset(corner_openings, TILE_SIZE)
	_assert(curved_enemy.position.is_equal_approx(Vector3(corner_anchor.x, 0.0, corner_anchor.y)), "Expected enemies on corners to stand on the curved road")
	var corner_plaza := corner_tile.get_node_or_null("Visuals/EncounterPlaza") as MeshInstance3D
	_assert(corner_plaza == null, "Expected enemies to stand directly on the road without a plaza")
	corner_tile.queue_free()

	var berry_tile := TILE_SCENE.instantiate() as RoadTile
	berry_tile.definition = straight
	berry_tile.tile_size = TILE_SIZE
	berry_tile.encounter_data = {"type": GameMap.ENCOUNTER_BERRY_BUSH}
	get_root().add_child(berry_tile)
	await process_frame
	var berry_visuals := berry_tile.get_node("Visuals")
	_assert(berry_visuals.get_node_or_null("BerryBush0Core") != null and berry_visuals.get_node_or_null("BerryBush2Core") != null, "Expected several berry bushes around the road")
	_assert(berry_visuals.get_node_or_null("BerryBush0BerryA") != null, "Expected fresh bushes to show distinct red berries")
	_assert(berry_visuals.get_node_or_null("BerryBush0BerryF") != null, "Expected each fresh bush to show several distinct red berries")
	var bright_berry_material := (berry_visuals.get_node("BerryBush0BerryA") as MeshInstance3D).material_override as StandardMaterial3D
	_assert(bright_berry_material.emission_enabled, "Expected berries to remain readable against the dark forest palette")
	_assert(berry_visuals.get_node_or_null("EncounterPlaza") == null, "Expected berry roads not to use an encounter plaza")
	var reserved_bush_positions: Array[Vector2] = berry_visuals.call("_berry_bush_positions", straight.get_rotated_openings(0))
	for tree in berry_visuals.get_children().filter(func(child: Node) -> bool: return child.get_node_or_null("CrownLower") != null):
		for bush_position in reserved_bush_positions:
			_assert(Vector2((tree as Node3D).position.x, (tree as Node3D).position.z).distance_to(bush_position * TILE_SIZE) >= TILE_SIZE * 0.24, "Expected berry bushes not to overlap roadside fir trees")
	berry_tile.set_encounter_data({"type": GameMap.ENCOUNTER_BERRY_BUSH, "depleted": true})
	_assert(berry_visuals.get_node_or_null("BerryBush0Core") != null, "Expected picked berry bushes to remain beside the road")
	_assert(berry_visuals.get_node_or_null("BerryBush0BerryA") == null, "Expected red berries to disappear after collection")
	berry_tile.queue_free()

	var enemy_tile := TILE_SCENE.instantiate() as RoadTile
	get_root().add_child(enemy_tile)
	enemy_tile.definition = straight
	enemy_tile.tile_size = TILE_SIZE
	enemy_tile.encounter_data = {
		"type": GameMap.ENCOUNTER_ENEMY,
		"revealed": true,
		"power": 7,
	}
	await process_frame
	var enemy_model := enemy_tile.get_node_or_null("Enemy/EnemyModel") as MeshInstance3D
	var power_label := enemy_tile.get_node_or_null("Enemy/PowerLabel") as Label3D
	var power_icon := enemy_tile.get_node_or_null("Enemy/PowerIcon") as Sprite3D
	_assert(enemy_model != null, "Expected enemy tiles to show the shared pawn model")
	_assert(enemy_model.scale.is_equal_approx(Vector3.ONE * TILE_SIZE * ModelAssets.PAWN_MODEL_SCALE), "Expected enemy pawn to use the player's model scale")
	var enemy_material := enemy_model.material_override as StandardMaterial3D
	_assert(enemy_material != null and enemy_material.albedo_color.is_equal_approx(EnemyView.ENEMY_COLOR), "Expected the shared enemy pawn model to be red")
	_assert(power_label != null, "Expected revealed enemy tiles to show a power label")
	_assert(power_icon != null, "Expected revealed enemy tiles to show a power icon")
	_assert(power_label.text == "7", "Expected enemy power label to show the enemy power")
	_assert(power_label.position.y > TILE_SIZE * 0.45, "Expected enemy power label to sit above the enemy model")
	_assert(power_icon.texture == load("res://assets/images/stats/stat_power.png"), "Expected enemy tiles to use the player's power icon")
	_assert(power_label.position.x > power_icon.position.x, "Expected the enemy power value to sit right of the power icon")
	_assert(power_label.position.x - power_icon.position.x > TILE_SIZE * 0.15, "Expected clear spacing between the enemy power icon and value")
	_assert(is_equal_approx((power_label.position.x + power_icon.position.x) * 0.5, 0.0), "Expected the power value and icon to be centered over the enemy")
	_assert(is_equal_approx(power_icon.position.y, power_label.position.y), "Expected the power value and icon to share a baseline")
	_assert(is_equal_approx(power_label.position.z, 0.0), "Expected enemy power label to stay centered above the enemy model")
	_assert(power_label.fixed_size, "Expected enemy power label to stay readable at camera distance")
	_assert(power_icon.fixed_size, "Expected enemy power icon to stay readable at camera distance")
	_assert(power_label.font_size == PlayerStatsUI.STAT_VALUE_FONT_SIZE, "Expected enemy power value to follow the player's power stat font size")
	_assert(is_equal_approx(power_label.pixel_size, power_icon.pixel_size), "Expected the enemy power icon and value to use the same 3D pixel scale")
	_assert(is_equal_approx(power_icon.scale.x * float(power_icon.texture.get_width()), PlayerStatsUI.STAT_ICON_SIZE), "Expected enemy power icon to follow the player's power stat icon size")
	var risk_encounter: Dictionary = enemy_tile.encounter_data.duplicate(true)
	risk_encounter["risk_level"] = "Dangerous"
	enemy_tile.set_encounter_data(risk_encounter)
	await process_frame
	power_label = enemy_tile.get_node_or_null("Enemy/PowerLabel") as Label3D
	_assert(enemy_tile.get_node_or_null("Enemy/RiskLabel") == null, "Expected enemy risk not to use separate text")
	_assert(power_label.modulate.is_equal_approx(Color(1.0, 0.22, 0.16)), "Expected dangerous enemy power to use a red value")
	(enemy_tile.get_node("Enemy") as EnemyView).set_combat_status_visible(false)
	power_label = enemy_tile.get_node_or_null("Enemy/PowerLabel") as Label3D
	power_icon = enemy_tile.get_node_or_null("Enemy/PowerIcon") as Sprite3D
	_assert(not power_label.visible and not power_icon.visible, "Expected enemy power value and symbol to hide during combat")
	enemy_tile.queue_free()

	var start_camp := load("res://data/start_camp.tres")
	var start_openings: Dictionary = start_camp.get_rotated_openings(0)
	_assert(start_openings["north"] == true, "Expected start camp to open north")
	_assert(start_openings["east"] == true, "Expected start camp to open east")
	_assert(start_openings["south"] == false, "Expected start camp to stay closed south")
	_assert(start_openings["west"] == true, "Expected start camp to open west")
	_assert(start_camp.get("visual_identity") == "house", "Expected start tile to use a simple house visual identity")
	_assert(start_camp.get("road_visible") != false, "Expected start tile road art to show under the house")
	var goal_town := load("res://data/goal_town.tres")
	var goal_openings: Dictionary = goal_town.get_rotated_openings(2)
	_assert(goal_openings["north"] == false, "Expected rotated goal town to stay closed north")
	_assert(goal_openings["east"] == true, "Expected rotated goal town to open east")
	_assert(goal_openings["south"] == true, "Expected rotated goal town to open inward")
	_assert(goal_openings["west"] == true, "Expected rotated goal town to open west")
	_assert(goal_town.get("visual_identity") == "house", "Expected goal tile to use a simple house visual identity")
	_assert(goal_town.get("road_visible") != false, "Expected goal tile road art to show under the house")

	quit()


func _count_named_children(parent: Node, child_name: String) -> int:
	var count := 0
	for child in parent.get_children():
		if child.name == child_name and not child.is_queued_for_deletion():
			count += 1
	return count


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
