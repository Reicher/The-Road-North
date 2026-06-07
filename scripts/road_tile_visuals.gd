class_name RoadTileVisuals
extends Node3D

const GROUND_HEIGHT := 0.10
const ROAD_HEIGHT := 0.08
const ROAD_TREE_CLEARANCE := 0.26
const ROAD_EDGE_SAMPLES := 6
const ROAD_EDGE_JITTER_RATIO := 0.009
const ModelAssets = preload("res://scripts/model_assets.gd")
const ROAD_TREE_SLOTS := [
	Vector2(-0.40, -0.40),
	Vector2(-0.12, -0.41),
	Vector2(0.18, -0.40),
	Vector2(0.41, -0.36),
	Vector2(-0.42, -0.10),
	Vector2(0.42, -0.06),
	Vector2(-0.41, 0.20),
	Vector2(0.41, 0.24),
	Vector2(-0.36, 0.41),
	Vector2(-0.06, 0.40),
	Vector2(0.24, 0.41),
	Vector2(0.42, 0.38),
]

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
		var road_color: Color = definition.get("road_color")
		_draw_road(openings, tile_size, tile_size * 0.28, road_color)

	if definition != null:
		_draw_visual_identity(str(definition.get("visual_identity")), openings, tile_size)
		_add_road_tile_trees(openings, tile_size)

	if not encounter_data.is_empty() and _encounter_type(encounter_data) != GameMap.ENCOUNTER_ENEMY:
		_draw_reward_encounter(encounter_data, tile_size)

	if highlight_enabled:
		_add_highlight(tile_size, highlight_color)

	_refresh_enemy_view(tile_size, encounter_data, enemy_offset)


func _get_openings(definition: Resource, rotation_steps: int) -> Dictionary:
	if definition == null or not definition.has_method("get_rotated_openings"):
		return {}
	return definition.get_rotated_openings(rotation_steps)


func _draw_road(openings: Dictionary, tile_size: float, width: float, color: Color, y_offset := 0.0) -> void:
	var mesh := _build_road_mesh(openings, tile_size, width, GROUND_HEIGHT + y_offset)
	var instance := MeshInstance3D.new()
	instance.name = "RoadCenter"
	instance.mesh = mesh
	instance.material_override = _make_road_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_road_mesh(openings: Dictionary, tile_size: float, width: float, road_y: float) -> ArrayMesh:
	var half_width := width * 0.5
	var polygons: Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(-half_width, -half_width),
			Vector2(half_width, -half_width),
			Vector2(half_width, half_width),
			Vector2(-half_width, half_width),
		])
	]
	for direction in [
		Vector2(0.0, -1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(-1.0, 0.0),
	]:
		if openings.get(_direction_name(direction), false) == true:
			polygons.append(_build_road_arm_polygon(direction, tile_size, width))

	var outline := polygons[0]
	for polygon_index in range(1, polygons.size()):
		var merged := Geometry2D.merge_polygons(outline, polygons[polygon_index])
		if not merged.is_empty():
			outline = merged[0]

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_y := road_y + 0.006
	var indices := Geometry2D.triangulate_polygon(outline)
	for index in range(0, indices.size(), 3):
		var a := outline[indices[index]]
		var b := outline[indices[index + 1]]
		var c := outline[indices[index + 2]]
		_add_road_top_triangle(surface, a, b, c, top_y)
	surface.generate_normals()
	return surface.commit()


func _build_road_arm_polygon(direction: Vector2, tile_size: float, width: float) -> PackedVector2Array:
	var half_length := tile_size * 0.5
	var half_width := width * 0.5
	var side := Vector2(-direction.y, direction.x)
	var jitter_amount := tile_size * ROAD_EDGE_JITTER_RATIO
	var seed := _road_arm_seed(direction, tile_size)
	var left_points := PackedVector2Array()
	var right_points := PackedVector2Array()
	for sample in ROAD_EDGE_SAMPLES:
		var ratio := float(sample) / float(ROAD_EDGE_SAMPLES - 1)
		var center := direction * half_length * ratio
		left_points.append(center + side * (half_width + _road_edge_jitter(seed, sample, 0, jitter_amount)))
		right_points.append(center - side * (half_width + _road_edge_jitter(seed, sample, 1, jitter_amount)))
	var polygon := PackedVector2Array()
	for point in left_points:
		polygon.append(point)
	for point_index in range(right_points.size() - 1, -1, -1):
		polygon.append(right_points[point_index])
	return polygon


func _direction_name(direction: Vector2) -> String:
	if direction.y < 0.0:
		return "north"
	if direction.x > 0.0:
		return "east"
	if direction.y > 0.0:
		return "south"
	return "west"


func _add_road_top_triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, y: float) -> void:
	var vertices := [Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y)]
	if (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).y < 0.0:
		vertices.reverse()
	for vertex in vertices:
		surface.add_vertex(vertex)


func _road_arm_seed(direction: Vector2, tile_size: float) -> int:
	var tile_position: Vector3 = get_parent().position if get_parent() is Node3D else global_position
	var grid_x := roundi(tile_position.x / tile_size) if tile_size > 0.0 else 0
	var grid_y := roundi(tile_position.z / tile_size) if tile_size > 0.0 else 0
	return grid_x * 101 + grid_y * 211 + roundi(direction.x) * 307 + roundi(direction.y) * 401


func _road_edge_jitter(seed: int, sample: int, side: int, amount: float) -> float:
	if sample == 0 or sample == ROAD_EDGE_SAMPLES - 1:
		return 0.0
	var hash_value := posmod(seed + sample * 97 + side * 193 + sample * sample * 17, 101)
	return (float(hash_value) / 50.0 - 1.0) * amount


func _make_road_material(color: Color) -> StandardMaterial3D:
	var material := _make_material(color)
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


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
	var added := 0
	var seed := _tree_layout_seed(openings, tile_size)
	for index in ROAD_TREE_SLOTS.size():
		var slot: Vector2 = ROAD_TREE_SLOTS[posmod(index * 5 + seed, ROAD_TREE_SLOTS.size())]
		if _slot_touches_road(slot, openings):
			continue
		var scale_factor := 0.70 + float(posmod(seed + added * 5, 7)) * 0.055
		var width_factor := 0.86 + float(posmod(seed + added * 3, 5)) * 0.055
		var rotation_y := float(posmod(seed * 13 + added * 71, 360))
		_add_tree(tile_size, Vector3(slot.x * tile_size, 0.0, slot.y * tile_size), scale_factor, width_factor, rotation_y)
		added += 1
		if added >= 6:
			return


func _tree_layout_seed(openings: Dictionary, tile_size: float) -> int:
	var grid_x := floori(position.x / tile_size) if tile_size > 0.0 else 0
	var grid_y := floori(position.z / tile_size) if tile_size > 0.0 else 0
	var seed := grid_x * 11 + grid_y * 7
	seed += 1 if openings.get("north", false) == true else 0
	seed += 3 if openings.get("east", false) == true else 0
	seed += 5 if openings.get("south", false) == true else 0
	seed += 7 if openings.get("west", false) == true else 0
	return seed


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


func _add_tree(tile_size: float, offset: Vector3, scale_factor: float = 1.0, width_factor: float = 1.0, rotation_y := 0.0) -> void:
	var model := ModelAssets.instantiate_model(ModelAssets.TREE_MODEL, "Tree", offset, tile_size * scale_factor)
	if model != null:
		model.scale.x *= width_factor
		model.scale.z *= width_factor
		model.rotation_degrees.y = rotation_y
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
