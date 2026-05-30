class_name RoadTile
extends Node3D

const GROUND_HEIGHT := 0.10
const ROAD_HEIGHT := 0.08
const ROAD_TREE_CLEARANCE := 0.26

@export var definition: Resource:
	set(value):
		definition = value
		_rebuild_visuals()

@export_range(0, 3, 1) var rotation_steps := 0:
	set(value):
		rotation_steps = posmod(value, 4)
		_rebuild_visuals()

@export_range(16.0, 256.0, 1.0) var tile_size := 96.0:
	set(value):
		tile_size = value
		_refresh_enemy_view()
		_rebuild_visuals()

@export var tile_tint := Color.WHITE:
	set(value):
		tile_tint = value
		_apply_tint()

@export var highlight_enabled := false:
	set(value):
		highlight_enabled = value
		_rebuild_visuals()

@export var highlight_color := Color(0.25, 0.85, 0.35, 0.38):
	set(value):
		highlight_color = value
		_rebuild_visuals()

@export var encounter_data := {}:
	set(value):
		encounter_data = value
		_refresh_enemy_view()
		_rebuild_visuals()

var enemy_data := {}:
	get:
		return encounter_data if _encounter_type() == GameMap.ENCOUNTER_ENEMY else {}
	set(value):
		encounter_data = value

var enemy_offset = Vector3.ZERO:
	set(value):
		if value is Vector2:
			enemy_offset = Vector3(value.x, 0.0, value.y)
		elif value is Vector3:
			enemy_offset = value
		else:
			enemy_offset = Vector3.ZERO
		_refresh_enemy_view()

var _visual_root: Node3D
var _enemy_view: Node3D


func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)
	_enemy_view = get_node_or_null("Enemy") as Node3D
	_refresh_enemy_view()
	_rebuild_visuals()


func rotate_clockwise() -> void:
	rotation_steps += 1


func set_highlight(enabled: bool, color: Color = highlight_color) -> void:
	highlight_color = color
	highlight_enabled = enabled


func get_openings() -> Dictionary:
	if definition == null or not definition.has_method("get_rotated_openings"):
		return {}
	return definition.get_rotated_openings(rotation_steps)


func set_enemy_data(value: Dictionary) -> void:
	encounter_data = value


func set_encounter_data(value: Dictionary) -> void:
	encounter_data = value


func _rebuild_visuals() -> void:
	if not is_inside_tree() or _visual_root == null:
		return
	for child in _visual_root.get_children():
		child.queue_free()

	var terrain_color := Color(0.55, 0.63, 0.45)
	if definition != null and definition.get("terrain_color") != null:
		terrain_color = definition.get("terrain_color")
	terrain_color = terrain_color * tile_tint
	_add_box("Ground", Vector3(tile_size * 0.96, GROUND_HEIGHT, tile_size * 0.96), Vector3(0.0, -GROUND_HEIGHT * 0.35, 0.0), terrain_color)

	if definition != null and definition.get("road_visible") != false:
		var openings := get_openings()
		var shoulder_color: Color = definition.get("shoulder_color")
		var road_color: Color = definition.get("road_color")
		_draw_road(openings, tile_size * 0.42, shoulder_color)
		_draw_road(openings, tile_size * 0.28, road_color, 0.02)

	if definition != null:
		_draw_visual_identity(str(definition.get("visual_identity")))
		_add_road_tile_trees()

	if not encounter_data.is_empty() and _encounter_type() != GameMap.ENCOUNTER_ENEMY:
		_draw_reward_encounter(encounter_data)

	if highlight_enabled:
		_add_highlight()


func _draw_road(openings: Dictionary, width: float, color: Color, y_offset := 0.0) -> void:
	var half := tile_size * 0.5
	var arm_length := half
	var arm_offset := half * 0.5
	var arm_y := GROUND_HEIGHT + y_offset
	var center_y := arm_y + 0.012
	var center_size := Vector3(width, ROAD_HEIGHT, width)
	_add_box("RoadCenter", center_size, Vector3(0.0, center_y, 0.0), color)
	if openings.get("north", false) == true:
		_add_box("RoadNorth", Vector3(width, ROAD_HEIGHT, arm_length), Vector3(0.0, arm_y, -arm_offset), color)
	if openings.get("east", false) == true:
		_add_box("RoadEast", Vector3(arm_length, ROAD_HEIGHT, width), Vector3(arm_offset, arm_y, 0.0), color)
	if openings.get("south", false) == true:
		_add_box("RoadSouth", Vector3(width, ROAD_HEIGHT, arm_length), Vector3(0.0, arm_y, arm_offset), color)
	if openings.get("west", false) == true:
		_add_box("RoadWest", Vector3(arm_length, ROAD_HEIGHT, width), Vector3(-arm_offset, arm_y, 0.0), color)


func _draw_visual_identity(identity: String) -> void:
	if identity == "house":
		_add_house()


func _add_house() -> void:
	var base_size := Vector3(tile_size * 0.26, tile_size * 0.20, tile_size * 0.24)
	var base_y := GROUND_HEIGHT + base_size.y * 0.5
	_add_box("HouseBase", base_size, Vector3(0.0, base_y, tile_size * 0.08), Color(0.70, 0.58, 0.42))
	_add_cone("HouseRoof", tile_size * 0.20, tile_size * 0.18, Vector3(0.0, base_y + tile_size * 0.18, tile_size * 0.08), Color(0.42, 0.20, 0.18), 4)


func _draw_reward_encounter(encounter: Dictionary) -> void:
	var kind := str(encounter.get("type", ""))
	if kind == GameMap.ENCOUNTER_BERRY_BUSH:
		_add_bush(Vector3(0.0, 0.0, tile_size * 0.20), true)
	elif kind == GameMap.ENCOUNTER_CACHE:
		_add_box("Cache", Vector3(tile_size * 0.28, tile_size * 0.16, tile_size * 0.20), Vector3(0.0, GROUND_HEIGHT + tile_size * 0.08, tile_size * 0.18), Color(0.48, 0.27, 0.12))


func _add_road_tile_trees() -> void:
	var openings := get_openings()
	var slots := [
		Vector2(-0.38, -0.38),
		Vector2(0.38, -0.38),
		Vector2(-0.38, 0.38),
		Vector2(0.38, 0.38),
		Vector2(-0.40, 0.0),
		Vector2(0.40, 0.0),
	]
	var added := 0
	for slot in slots:
		if _slot_touches_road(slot, openings):
			continue
		_add_tree(Vector3(slot.x * tile_size, 0.0, slot.y * tile_size), 0.82 + float(added) * 0.08)
		added += 1
		if added >= 3:
			return


func _slot_touches_road(slot: Vector2, openings: Dictionary) -> bool:
	if absf(slot.x) < ROAD_TREE_CLEARANCE and absf(slot.y) < ROAD_TREE_CLEARANCE:
		return true
	if openings.get("north", false) == true and slot.y < ROAD_TREE_CLEARANCE and absf(slot.x) < ROAD_TREE_CLEARANCE:
		return true
	if openings.get("south", false) == true and slot.y > -ROAD_TREE_CLEARANCE and absf(slot.x) < ROAD_TREE_CLEARANCE:
		return true
	if openings.get("east", false) == true and slot.x > -ROAD_TREE_CLEARANCE and absf(slot.y) < ROAD_TREE_CLEARANCE:
		return true
	if openings.get("west", false) == true and slot.x < ROAD_TREE_CLEARANCE and absf(slot.y) < ROAD_TREE_CLEARANCE:
		return true
	return false


func _add_tree(offset: Vector3, scale_factor: float = 1.0) -> void:
	var trunk_height := tile_size * 0.15 * scale_factor
	_add_box("TreeTrunk", Vector3(tile_size * 0.045, trunk_height, tile_size * 0.045), offset + Vector3(0.0, trunk_height * 0.5, 0.0), Color(0.34, 0.20, 0.10))
	_add_cone("TreeTop", tile_size * 0.15 * scale_factor, tile_size * 0.30 * scale_factor, offset + Vector3(0.0, trunk_height + tile_size * 0.14 * scale_factor, 0.0), Color(0.17, 0.39, 0.20), 8)


func _add_bush(offset: Vector3, berries := false) -> void:
	_add_sphere("Bush", tile_size * 0.12, offset + Vector3(0.0, GROUND_HEIGHT + tile_size * 0.09, 0.0), Color(0.18, 0.44, 0.22))
	if berries:
		_add_sphere("BerryA", tile_size * 0.024, offset + Vector3(tile_size * 0.04, GROUND_HEIGHT + tile_size * 0.15, -tile_size * 0.06), Color(0.67, 0.10, 0.18))


func _add_highlight() -> void:
	_add_box("Highlight", Vector3(tile_size * 0.98, 0.035, tile_size * 0.98), Vector3(0.0, GROUND_HEIGHT + ROAD_HEIGHT + 0.05, 0.0), highlight_color)


func _refresh_enemy_view() -> void:
	if _enemy_view == null:
		return
	_enemy_view.set("tile_size", tile_size)
	_enemy_view.set("enemy_data", encounter_data if _encounter_type() == GameMap.ENCOUNTER_ENEMY else {})
	_enemy_view.position = enemy_offset if enemy_offset is Vector3 else Vector3.ZERO


func _apply_tint() -> void:
	_rebuild_visuals()


func _encounter_type() -> String:
	return str(encounter_data.get("type", ""))


func _add_box(node_name: String, size: Vector3, local_position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	_visual_root.add_child(instance)
	return instance


func _add_cone(node_name: String, bottom_radius: float, height: float, local_position: Vector3, color: Color, segments := 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	_visual_root.add_child(instance)
	return instance


func _add_sphere(node_name: String, radius: float, local_position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	_visual_root.add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
