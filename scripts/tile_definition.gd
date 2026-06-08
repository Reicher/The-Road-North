class_name TileDefinition
extends Resource

const DIRECTION_NAMES: Array[String] = ["north", "east", "south", "west"]

@export var display_name := "Road"
@export var opens_north := false
@export var opens_east := false
@export var opens_south := false
@export var opens_west := false
@export var road_color := Color(0.45, 0.36, 0.27)
@export var terrain_color := Color(0.55, 0.63, 0.45)
@export var visual_identity := "road"
@export var road_visible := true
@export var placeable_on_river := false


func get_base_openings() -> Dictionary:
	return {
		"north": opens_north,
		"east": opens_east,
		"south": opens_south,
		"west": opens_west,
	}


func get_rotated_openings(rotation_steps: int) -> Dictionary:
	var steps := posmod(rotation_steps, DIRECTION_NAMES.size())
	var base_openings := get_base_openings()
	var rotated_openings := {}

	for index in DIRECTION_NAMES.size():
		var from_direction: String = DIRECTION_NAMES[index]
		var to_direction: String = DIRECTION_NAMES[(index + steps) % DIRECTION_NAMES.size()]
		rotated_openings[to_direction] = base_openings[from_direction]

	return rotated_openings
