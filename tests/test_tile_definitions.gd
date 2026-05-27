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

	var start_camp := load("res://data/start_camp.tres")
	_assert(start_camp.get("visual_identity") == "house", "Expected start tile to use a simple house visual identity")
	_assert(start_camp.get("road_visible") == false, "Expected start tile road art to be hidden")
	var goal_town := load("res://data/goal_town.tres")
	_assert(goal_town.get_rotated_openings(2)["south"] == true, "Expected rotated goal town to open inward")
	_assert(goal_town.get("visual_identity") == "house", "Expected goal tile to use a simple house visual identity")
	_assert(goal_town.get("road_visible") == false, "Expected goal tile road art to be hidden")

	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
