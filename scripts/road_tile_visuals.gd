class_name RoadTileVisuals
extends Node3D

const GROUND_HEIGHT := 0.10
const ROAD_HEIGHT := 0.08
const ROAD_TREE_CLEARANCE := 0.26
const ModelAssets = preload("res://scripts/model_assets.gd")

var _enemy_view: Node3D


func _ready() -> void:
	_enemy_view = get_node_or_null("../Enemy") as Node3D


func render(
	definition: Resource,
	rotation_steps: int,
	tile_size: float,
	_tile_tint: Color,
	highlight_enabled: bool,
	highlight_color: Color,
	encounter_data: Dictionary,
	enemy_offset: Vector3
) -> void:
	for child in get_children():
		child.queue_free()

	var openings := _get_openings(definition, rotation_steps)
	if definition != null and definition.get("road_visible") != false:
		var shoulder_color: Color = definition.get("shoulder_color")
		var road_color: Color = definition.get("road_color")
		_draw_road(openings, tile_size, tile_size * 0.42, shoulder_color)
		_draw_road(openings, tile_size, tile_size * 0.28, road_color, 0.02)

	if definition != null:
		_draw_visual_identity(str(definition.get("visual_identity")), openings, tile_size)
		_add_road_tile_trees(openings, tile_size)

	if not encounter_data.is_empty() and _encounter_type(encounter_data) != GameMap.ENCOUNTER_ENEMY:
		_draw_reward_encounter(encounter_data, tile_size)

	if highlight_enabled:
		_add_highlight(tile_size, highlight_color)

	_refresh_enemy_view(tile_size, encounter_data, enemy_offset)


func refresh_enemy(tile_size: float, encounter_data: Dictionary, enemy_offset: Vector3) -> void:
	_refresh_enemy_view(tile_size, encounter_data, enemy_offset)


func _get_openings(definition: Resource, rotation_steps: int) -> Dictionary:
	if definition == null or not definition.has_method("get_rotated_openings"):
		return {}
	return definition.get_rotated_openings(rotation_steps)


func _draw_road(openings: Dictionary, tile_size: float, width: float, color: Color, y_offset := 0.0) -> void:
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


func _draw_visual_identity(identity: String, openings: Dictionary, tile_size: float) -> void:
	if identity == "house":
		_add_house(openings, tile_size)


func _add_house(openings: Dictionary, tile_size: float) -> void:
	var z_offset := _get_house_z_offset(openings, tile_size)
	var model := ModelAssets.instantiate_model(ModelAssets.HOUSE_MODEL, "House", Vector3(0.0, GROUND_HEIGHT, z_offset), tile_size)
	if model != null:
		add_child(model)


func _get_house_z_offset(openings: Dictionary, tile_size: float) -> float:
	if openings.get("north", false) == true and openings.get("south", false) != true:
		return tile_size * 0.28
	if openings.get("south", false) == true and openings.get("north", false) != true:
		return -tile_size * 0.28
	return tile_size * 0.08


func _draw_reward_encounter(encounter: Dictionary, tile_size: float) -> void:
	var kind := str(encounter.get("type", ""))
	if kind == GameMap.ENCOUNTER_BERRY_BUSH:
		_add_bush(tile_size, Vector3(0.0, 0.0, tile_size * 0.20), true)
	elif kind == GameMap.ENCOUNTER_CACHE:
		_add_box("Cache", Vector3(tile_size * 0.28, tile_size * 0.16, tile_size * 0.20), Vector3(0.0, GROUND_HEIGHT + tile_size * 0.08, tile_size * 0.18), Color(0.48, 0.27, 0.12))


func _add_road_tile_trees(openings: Dictionary, tile_size: float) -> void:
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
		_add_tree(tile_size, Vector3(slot.x * tile_size, 0.0, slot.y * tile_size), 0.82 + float(added) * 0.08)
		added += 1
		if added >= 3:
			return


func _slot_touches_road(slot: Vector2, openings: Dictionary) -> bool:
	if absf(slot.x) < ROAD_TREE_CLEARANCE and absf(slot.y) < ROAD_TREE_CLEARANCE:
		return true
	if openings.get("north", false) == true and openings.get("east", false) == true and slot.x > 0.16 and slot.y < -0.16:
		return true
	if openings.get("east", false) == true and openings.get("south", false) == true and slot.x > 0.16 and slot.y > 0.16:
		return true
	if openings.get("south", false) == true and openings.get("west", false) == true and slot.x < -0.16 and slot.y > 0.16:
		return true
	if openings.get("north", false) == true and openings.get("west", false) == true and slot.x < -0.16 and slot.y < -0.16:
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


func _add_tree(tile_size: float, offset: Vector3, scale_factor: float = 1.0) -> void:
	var model := ModelAssets.instantiate_model(ModelAssets.TREE_MODEL, "Tree", offset, tile_size * scale_factor)
	if model != null:
		add_child(model)


func _add_bush(tile_size: float, offset: Vector3, berries := false) -> void:
	_add_sphere("Bush", tile_size * 0.12, offset + Vector3(0.0, GROUND_HEIGHT + tile_size * 0.09, 0.0), Color(0.18, 0.44, 0.22))
	if berries:
		_add_sphere("BerryA", tile_size * 0.024, offset + Vector3(tile_size * 0.04, GROUND_HEIGHT + tile_size * 0.15, -tile_size * 0.06), Color(0.67, 0.10, 0.18))


func _add_highlight(tile_size: float, highlight_color: Color) -> void:
	var fill_y := GROUND_HEIGHT * 0.55
	_add_box("HighlightFill", Vector3(tile_size * 1.08, 0.018, tile_size * 1.08), Vector3(0.0, fill_y, 0.0), highlight_color)
	var border_color := highlight_color.lightened(0.35)
	border_color.a = minf(1.0, highlight_color.a + 0.18)
	var line_width := tile_size * 0.055
	var line_length := tile_size * 1.12
	var border_y := GROUND_HEIGHT + ROAD_HEIGHT + 0.12
	_add_box("HighlightNorth", Vector3(line_length, line_width, line_width), Vector3(0.0, border_y, -tile_size * 0.56), border_color)
	_add_box("HighlightEast", Vector3(line_width, line_width, line_length), Vector3(tile_size * 0.56, border_y, 0.0), border_color)
	_add_box("HighlightSouth", Vector3(line_length, line_width, line_width), Vector3(0.0, border_y, tile_size * 0.56), border_color)
	_add_box("HighlightWest", Vector3(line_width, line_width, line_length), Vector3(-tile_size * 0.56, border_y, 0.0), border_color)


func _refresh_enemy_view(tile_size: float, encounter_data: Dictionary, enemy_offset: Vector3) -> void:
	if _enemy_view == null:
		_enemy_view = get_node_or_null("../Enemy") as Node3D
	if _enemy_view == null:
		return
	_enemy_view.set("tile_size", tile_size)
	_enemy_view.set("enemy_data", encounter_data if _encounter_type(encounter_data) == GameMap.ENCOUNTER_ENEMY else {})
	_enemy_view.position = enemy_offset


func _encounter_type(encounter_data: Dictionary) -> String:
	return str(encounter_data.get("type", ""))


func _add_box(node_name: String, size: Vector3, local_position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	add_child(instance)
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
	add_child(instance)
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
	add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
