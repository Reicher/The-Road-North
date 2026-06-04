extends SceneTree

const TILE_SCENE := preload("res://scenes/tile.tscn")
const TILE_SIZE := 96.0

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
		_assert(is_equal_approx(tile.tile_size, TILE_SIZE), "Expected tile size to remain grid aligned")
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
	corner_tile.queue_free()

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
	var power_label := enemy_tile.get_node_or_null("Enemy/PowerLabel") as Label3D
	_assert(power_label != null, "Expected revealed enemy tiles to show a power label")
	_assert(power_label.text == "7", "Expected enemy power label to show the enemy power")
	_assert(power_label.position.y > TILE_SIZE * 0.45, "Expected enemy power label to sit above the enemy model")
	_assert(power_label.position.x > TILE_SIZE * 0.08, "Expected enemy power label to sit slightly right of the enemy model center")
	_assert(is_equal_approx(power_label.position.z, 0.0), "Expected enemy power label to stay centered above the enemy model")
	_assert(power_label.fixed_size, "Expected enemy power label to stay readable at camera distance")
	_assert(power_label.font_size < 24 and power_label.outline_size <= 3, "Expected enemy power label to render smaller and cleaner than the original oversized label")
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


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
