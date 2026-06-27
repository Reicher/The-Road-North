class_name RoadTileVisuals
extends Node3D

const GROUND_HEIGHT := 0.10
const ROAD_WIDTH_RATIO := 0.21
const ROAD_TREE_MARGIN_RATIO := 0.11
const ROAD_TILE_TREE_COUNT := 4
const ROAD_EDGE_SAMPLES := 6
const ROAD_EDGE_JITTER_RATIO := 0.009
const ENCOUNTER_PLAZA_DIAMETER_RATIO := 0.48
const ENCOUNTER_PLAZA_HEIGHT_RATIO := 0.012
const RoadPath = preload("res://scripts/road_path.gd")
const ModelAssets = preload("res://scripts/model_assets.gd")
const VisualPalette = preload("res://scripts/map_visual_palette.gd")
const EnvironmentAssets = preload("res://scripts/map_environment_assets.gd")

var _enemy_view: EnemyView


func _ready() -> void:
	_enemy_view = get_node_or_null("../Enemy") as EnemyView


func render(
	definition: Resource,
	rotation_steps: int,
	tile_size: float,
	_tile_tint: Color,
	highlight_enabled: bool,
	highlight_color: Color,
	encounter_data: Dictionary,
	enemy_offset: Vector3,
	encounter_power_visible: bool
) -> void:
	for child in get_children():
		child.queue_free()

	var openings := _get_openings(definition, rotation_steps)
	var road_color := VisualPalette.ROAD
	if definition != null and definition.get("road_visible") != false:
		road_color = definition.get("road_color")
		_draw_road(openings, tile_size, tile_size * ROAD_WIDTH_RATIO, road_color)

	if definition != null:
		_draw_visual_identity(str(definition.get("visual_identity")), openings, tile_size)
		_add_road_tile_trees(openings, tile_size)

	var road_anchor := RoadPath.get_anchor_offset(openings, tile_size)
	var encounter_offset := enemy_offset + Vector3(road_anchor.x, 0.0, road_anchor.y)
	if not encounter_data.is_empty():
		_add_encounter_plaza(tile_size, encounter_offset, road_color)
		if _encounter_type(encounter_data) != GameMap.ENCOUNTER_ENEMY:
			_draw_reward_encounter(encounter_data, tile_size, encounter_offset)

	if highlight_enabled:
		_add_highlight(tile_size, highlight_color)

	_refresh_enemy_view(tile_size, encounter_data, encounter_offset, encounter_power_visible)


func _get_openings(definition: Resource, rotation_steps: int) -> Dictionary:
	if definition == null or not definition.has_method("get_rotated_openings"):
		return {}
	return definition.get_rotated_openings(rotation_steps)


func _draw_road(openings: Dictionary, tile_size: float, width: float, color: Color, y_offset := 0.0) -> void:
	_add_road_feather("RoadFeatherOuter", openings, tile_size, width + tile_size * 0.075, GROUND_HEIGHT + y_offset - 0.006, Color(color.r, color.g, color.b, 0.14))
	_add_road_feather("RoadFeatherInner", openings, tile_size, width + tile_size * 0.040, GROUND_HEIGHT + y_offset - 0.003, Color(color.r, color.g, color.b, 0.28))
	var mesh := _build_road_mesh(openings, tile_size, width, GROUND_HEIGHT + y_offset)
	var instance := MeshInstance3D.new()
	instance.name = "RoadCenter"
	instance.mesh = mesh
	instance.material_override = _make_road_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _add_road_feather(node_name: String, openings: Dictionary, tile_size: float, width: float, road_y: float, color: Color) -> void:
	var feather := MeshInstance3D.new()
	feather.name = node_name
	feather.mesh = _build_road_mesh(openings, tile_size, width, road_y)
	feather.material_override = _make_road_material(color)
	feather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(feather)


func _build_road_mesh(openings: Dictionary, tile_size: float, width: float, road_y: float) -> ArrayMesh:
	if RoadPath.is_corner(openings):
		return _build_curved_road_mesh(openings, tile_size, width, road_y)
	if _opening_count(openings) == 1:
		return _build_dead_end_mesh(openings, tile_size, width, road_y)
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


func _build_dead_end_mesh(openings: Dictionary, tile_size: float, width: float, road_y: float) -> ArrayMesh:
	var direction := Vector2.ZERO
	for candidate in [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)]:
		if openings.get(_direction_name(candidate), false) == true:
			direction = candidate
			break
	var side := Vector2(-direction.y, direction.x)
	var half_width := width * 0.5
	var edge := direction * tile_size * 0.5
	var outline := PackedVector2Array([edge + side * half_width, edge - side * half_width])
	for sample in 7:
		var angle := PI * float(sample) / 6.0
		outline.append(-side * cos(angle) * half_width - direction * sin(angle) * half_width)
	return _build_flat_polygon_mesh(outline, road_y + 0.006)


func _build_flat_polygon_mesh(outline: PackedVector2Array, y: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for index in range(0, indices.size(), 3):
		_add_road_top_triangle(surface, outline[indices[index]], outline[indices[index + 1]], outline[indices[index + 2]], y)
	surface.generate_normals()
	return surface.commit()


func _opening_count(openings: Dictionary) -> int:
	var count := 0
	for direction_name in ["north", "east", "south", "west"]:
		if openings.get(direction_name, false) == true:
			count += 1
	return count


func _build_curved_road_mesh(openings: Dictionary, tile_size: float, width: float, road_y: float) -> ArrayMesh:
	var centerline := RoadPath.get_centerline(openings, tile_size)
	var curve_center := RoadPath.get_curve_center(openings, tile_size)
	var left_points := PackedVector2Array()
	var right_points := PackedVector2Array()
	for point in centerline:
		var normal := (point - curve_center).normalized()
		left_points.append(point + normal * width * 0.5)
		right_points.append(point - normal * width * 0.5)
	var outline := PackedVector2Array()
	for point in left_points:
		outline.append(point)
	for index in range(right_points.size() - 1, -1, -1):
		outline.append(right_points[index])

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for index in range(0, indices.size(), 3):
		_add_road_top_triangle(surface, outline[indices[index]], outline[indices[index + 1]], outline[indices[index + 2]], road_y + 0.006)
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


func _make_road_material(color: Color) -> Material:
	return VisualPalette.make_road_material(color)


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


func _add_encounter_plaza(tile_size: float, offset: Vector3, road_color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = tile_size * ENCOUNTER_PLAZA_DIAMETER_RATIO * 0.5
	mesh.bottom_radius = mesh.top_radius * 1.04
	mesh.height = tile_size * ENCOUNTER_PLAZA_HEIGHT_RATIO
	mesh.radial_segments = 12
	var plaza := MeshInstance3D.new()
	plaza.name = "EncounterPlaza"
	plaza.mesh = mesh
	plaza.position = offset + Vector3(0.0, GROUND_HEIGHT + mesh.height * 0.5 + 0.008, 0.0)
	plaza.material_override = _make_road_material(road_color)
	plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plaza)


func _draw_reward_encounter(encounter: Dictionary, tile_size: float, encounter_offset: Vector3) -> void:
	var kind := str(encounter.get("type", ""))
	if kind == GameMap.ENCOUNTER_BERRY_BUSH:
		_add_bush(tile_size, encounter_offset, true)
	elif kind == GameMap.ENCOUNTER_CACHE:
		_add_box("Cache", Vector3(tile_size * 0.28, tile_size * 0.16, tile_size * 0.20), encounter_offset + Vector3(0.0, GROUND_HEIGHT + tile_size * 0.08, 0.0), VisualPalette.WOOD)
	elif kind == GameMap.ENCOUNTER_CAMPFIRE:
		_add_campfire(tile_size, encounter_offset)
	elif kind == GameMap.ENCOUNTER_TAVERN:
		_add_tavern(tile_size, encounter_offset)
	elif kind == GameMap.ENCOUNTER_WITCH_HUT:
		_add_witch_hut(tile_size, encounter_offset)
	elif kind == GameMap.ENCOUNTER_SHRINE:
		_add_shrine(tile_size, encounter_offset)
	elif kind == GameMap.ENCOUNTER_GRAVEYARD:
		_add_graveyard(tile_size, encounter_offset)


func _add_campfire(tile_size: float, encounter_offset: Vector3) -> void:
	var center := encounter_offset + Vector3(0.0, GROUND_HEIGHT, 0.0)
	var log_a := _add_box("CampfireLogA", Vector3(tile_size * 0.25, tile_size * 0.045, tile_size * 0.055), center + Vector3(0.0, tile_size * 0.025, 0.0), Color(0.32, 0.16, 0.07))
	log_a.rotation.y = deg_to_rad(38.0)
	var log_b := _add_box("CampfireLogB", Vector3(tile_size * 0.25, tile_size * 0.045, tile_size * 0.055), center + Vector3(0.0, tile_size * 0.03, 0.0), Color(0.42, 0.22, 0.09))
	log_b.rotation.y = deg_to_rad(-38.0)
	_add_cone("CampfireFlame", tile_size * 0.09, tile_size * 0.24, center + Vector3(0.0, tile_size * 0.15, 0.0), Color(1.0, 0.36, 0.06), 8)


func _add_tavern(tile_size: float, encounter_offset: Vector3) -> void:
	var center := encounter_offset + Vector3(0.0, GROUND_HEIGHT, 0.0)
	_add_box("TavernBody", Vector3(tile_size * 0.32, tile_size * 0.25, tile_size * 0.26), center + Vector3(0.0, tile_size * 0.13, 0.0), Color(0.62, 0.40, 0.19))
	_add_cone("TavernRoof", tile_size * 0.25, tile_size * 0.18, center + Vector3(0.0, tile_size * 0.34, 0.0), Color(0.55, 0.16, 0.10), 4)
	_add_box("TavernSignPost", Vector3(tile_size * 0.025, tile_size * 0.22, tile_size * 0.025), center + Vector3(-tile_size * 0.23, tile_size * 0.12, 0.0), Color(0.25, 0.13, 0.05))
	_add_box("TavernSign", Vector3(tile_size * 0.16, tile_size * 0.09, tile_size * 0.025), center + Vector3(-tile_size * 0.23, tile_size * 0.22, 0.0), Color(0.90, 0.67, 0.20))


func _add_witch_hut(tile_size: float, encounter_offset: Vector3) -> void:
	var center := encounter_offset + Vector3(0.0, GROUND_HEIGHT, 0.0)
	_add_box("WitchHutBody", Vector3(tile_size * 0.30, tile_size * 0.24, tile_size * 0.25), center + Vector3(0.0, tile_size * 0.13, 0.0), Color(0.19, 0.16, 0.22))
	var roof := _add_cone("WitchHutRoof", tile_size * 0.26, tile_size * 0.24, center + Vector3(0.0, tile_size * 0.37, 0.0), Color(0.37, 0.16, 0.48), 5)
	roof.rotation.y = deg_to_rad(18.0)
	_add_sphere("WitchHutGlow", tile_size * 0.045, center + Vector3(0.0, tile_size * 0.17, -tile_size * 0.14), Color(0.63, 0.95, 0.45))


func _add_shrine(tile_size: float, encounter_offset: Vector3) -> void:
	var center := encounter_offset + Vector3(0.0, GROUND_HEIGHT, 0.0)
	_add_box("ShrineBase", Vector3(tile_size * 0.28, tile_size * 0.08, tile_size * 0.24), center + Vector3(0.0, tile_size * 0.04, 0.0), Color(0.40, 0.43, 0.46))
	_add_box("ShrinePillar", Vector3(tile_size * 0.12, tile_size * 0.34, tile_size * 0.12), center + Vector3(0.0, tile_size * 0.23, 0.0), Color(0.58, 0.61, 0.62))
	_add_sphere("ShrineLight", tile_size * 0.075, center + Vector3(0.0, tile_size * 0.45, 0.0), Color(0.38, 0.82, 1.0))


func _add_graveyard(tile_size: float, encounter_offset: Vector3) -> void:
	var stone := Color(0.46, 0.47, 0.45)
	for index in 3:
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := (-0.24 + float(index) * 0.22) * tile_size
		var center := encounter_offset + Vector3(side * tile_size * 0.18, GROUND_HEIGHT, z * 0.65)
		_add_box("Gravestone%d" % index, Vector3(tile_size * 0.14, tile_size * 0.22, tile_size * 0.055), center + Vector3(0.0, tile_size * 0.11, 0.0), stone)
	var cross_center := encounter_offset + Vector3(tile_size * 0.16, GROUND_HEIGHT, tile_size * 0.13)
	_add_box("GraveCrossPost", Vector3(tile_size * 0.045, tile_size * 0.30, tile_size * 0.045), cross_center + Vector3(0.0, tile_size * 0.15, 0.0), Color(0.25, 0.19, 0.13))
	_add_box("GraveCrossBar", Vector3(tile_size * 0.17, tile_size * 0.045, tile_size * 0.045), cross_center + Vector3(0.0, tile_size * 0.20, 0.0), Color(0.25, 0.19, 0.13))


func _add_road_tile_trees(openings: Dictionary, tile_size: float) -> void:
	var added := 0
	var seed := _tree_layout_seed(openings, tile_size)
	var slots := _road_tree_slots(seed)
	for slot in slots:
		if _point_touches_road(slot, openings, ROAD_WIDTH_RATIO):
			continue
		var scale_factor := 0.62 + float(posmod(seed + added * 5, 7)) * 0.045
		var width_factor := 0.86 + float(posmod(seed + added * 3, 5)) * 0.055
		var rotation_y := float(posmod(seed * 13 + added * 71, 360))
		_add_tree(tile_size, Vector3(slot.x * tile_size, 0.0, slot.y * tile_size), scale_factor, width_factor, rotation_y)
		added += 1
		if added >= ROAD_TILE_TREE_COUNT:
			return


func _road_tree_slots(seed: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	var columns := 7
	var spacing := 0.14
	for row in columns:
		for column in columns:
			var slot_index := row * columns + column
			var jitter_x := (float(posmod(seed + slot_index * 37, 9)) - 4.0) * 0.006
			var jitter_y := (float(posmod(seed + slot_index * 53, 9)) - 4.0) * 0.006
			slots.append(Vector2(
				-0.42 + float(column) * spacing + jitter_x,
				-0.42 + float(row) * spacing + jitter_y
			))
	var ordered: Array[Vector2] = []
	for index in slots.size():
		ordered.append(slots[posmod(index * 17 + seed, slots.size())])
	return ordered


func _tree_layout_seed(openings: Dictionary, tile_size: float) -> int:
	var grid_x := floori(position.x / tile_size) if tile_size > 0.0 else 0
	var grid_y := floori(position.z / tile_size) if tile_size > 0.0 else 0
	var seed := grid_x * 11 + grid_y * 7
	seed += 1 if openings.get("north", false) == true else 0
	seed += 3 if openings.get("east", false) == true else 0
	seed += 5 if openings.get("south", false) == true else 0
	seed += 7 if openings.get("west", false) == true else 0
	return seed


func _point_touches_road(point: Vector2, openings: Dictionary, width_ratio: float) -> bool:
	var half_width := width_ratio * 0.5 + ROAD_TREE_MARGIN_RATIO
	if RoadPath.is_corner(openings):
		var centerline := RoadPath.get_centerline(openings, 1.0)
		for index in range(centerline.size() - 1):
			if Geometry2D.get_closest_point_to_segment(point, centerline[index], centerline[index + 1]).distance_to(point) <= half_width:
				return true
		return false
	if absf(point.x) <= half_width and absf(point.y) <= half_width:
		return true
	if openings.get("north", false) == true and point.y <= 0.0 and absf(point.x) <= half_width:
		return true
	if openings.get("south", false) == true and point.y >= 0.0 and absf(point.x) <= half_width:
		return true
	if openings.get("east", false) == true and point.x >= 0.0 and absf(point.y) <= half_width:
		return true
	if openings.get("west", false) == true and point.x <= 0.0 and absf(point.y) <= half_width:
		return true
	return false


func _add_tree(tile_size: float, offset: Vector3, scale_factor: float = 1.0, width_factor: float = 1.0, rotation_y := 0.0) -> void:
	add_child(EnvironmentAssets.create_tree(tile_size, offset, scale_factor, width_factor, rotation_y, get_child_count()))


func _add_bush(tile_size: float, offset: Vector3, berries := false) -> void:
	_add_sphere("Bush", tile_size * 0.12, offset + Vector3(0.0, GROUND_HEIGHT + tile_size * 0.09, 0.0), Color(0.18, 0.44, 0.22))
	if berries:
		_add_sphere("BerryA", tile_size * 0.024, offset + Vector3(tile_size * 0.04, GROUND_HEIGHT + tile_size * 0.15, -tile_size * 0.06), Color(0.67, 0.10, 0.18))


func _add_highlight(tile_size: float, highlight_color: Color) -> void:
	var preview_y := GROUND_HEIGHT * 0.55
	_add_box("Highlight", Vector3(tile_size * 1.08, 0.018, tile_size * 1.08), Vector3(0.0, preview_y, 0.0), highlight_color)


func _refresh_enemy_view(tile_size: float, encounter_data: Dictionary, enemy_offset: Vector3, power_visible: bool) -> void:
	if _enemy_view == null:
		_enemy_view = get_node_or_null("../Enemy") as EnemyView
	if _enemy_view == null:
		return
	_enemy_view.tile_size = tile_size
	_enemy_view.enemy_data = encounter_data if _encounter_type(encounter_data) == GameMap.ENCOUNTER_ENEMY else {}
	_enemy_view.position = enemy_offset
	_enemy_view.set_combat_status_visible(power_visible)


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
	return VisualPalette.make_material(color)
