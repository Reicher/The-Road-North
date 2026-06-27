extends Node3D

const TILE_SIZE := 96.0
const TILE_SCENE := preload("res://scenes/tile.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const CORNER := preload("res://data/road_corner.tres")
const VisualPalette = preload("res://scripts/map_visual_palette.gd")

const ENCOUNTERS := [
	{"type": GameConstants.ENCOUNTER_ENEMY, "power": 3, "revealed": true, "risk_level": "Fair"},
	{"type": GameConstants.ENCOUNTER_BERRY_BUSH},
	{"type": GameConstants.ENCOUNTER_CACHE},
	{"type": GameConstants.ENCOUNTER_CAMPFIRE},
	{"type": GameConstants.ENCOUNTER_TAVERN},
	{"type": GameConstants.ENCOUNTER_WITCH_HUT},
	{"type": GameConstants.ENCOUNTER_SHRINE},
	{"type": GameConstants.ENCOUNTER_GRAVEYARD},
]


func _ready() -> void:
	_build_ground()
	_build_tiles()
	var camera := $Camera3D as Camera3D
	var center := Vector3(TILE_SIZE, 0.0, TILE_SIZE * 1.5)
	camera.look_at(center, Vector3.UP)


func _build_ground() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TILE_SIZE * 3.4, 6.0, TILE_SIZE * 4.4)
	var ground := MeshInstance3D.new()
	ground.name = "ShowcaseGround"
	ground.mesh = mesh
	ground.position = Vector3(TILE_SIZE, -3.1, TILE_SIZE * 1.5)
	ground.material_override = VisualPalette.make_material(VisualPalette.GRASS)
	add_child(ground)


func _build_tiles() -> void:
	for index in ENCOUNTERS.size():
		var tile := TILE_SCENE.instantiate() as RoadTile
		tile.name = "Encounter_%s" % str(ENCOUNTERS[index]["type"])
		tile.definition = CORNER if index == 7 else STRAIGHT
		tile.rotation_steps = 1
		tile.tile_size = TILE_SIZE
		tile.encounter_data = ENCOUNTERS[index]
		tile.position = Vector3(float(index % 3) * TILE_SIZE, 0.0, float(index / 3) * TILE_SIZE)
		add_child(tile)

