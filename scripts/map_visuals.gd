class_name MapVisuals
extends Node3D

const GROUND_HEIGHT := 0.08
const FOREST_PADDING_TILES := 4
const GROUND_LIGHT_COLOR := Color(0.69, 0.76, 0.57)
const PLAYABLE_BORDER_COLOR := Color(0.30, 0.38, 0.26, 0.62)
const ModelAssets = preload("res://scripts/model_assets.gd")
const TREE_SLOTS := [
	Vector2(-0.38, -0.36),
	Vector2(-0.08, -0.39),
	Vector2(0.31, -0.34),
	Vector2(-0.34, -0.04),
	Vector2(0.14, -0.08),
	Vector2(0.39, 0.04),
	Vector2(-0.28, 0.33),
	Vector2(0.03, 0.38),
	Vector2(0.34, 0.30),
]
const OUTSIDE_TREE_SLOTS := [
	Vector2(-0.44, -0.43),
	Vector2(-0.18, -0.45),
	Vector2(0.08, -0.43),
	Vector2(0.35, -0.44),
	Vector2(-0.42, -0.18),
	Vector2(-0.14, -0.17),
	Vector2(0.15, -0.20),
	Vector2(0.43, -0.15),
	Vector2(-0.45, 0.09),
	Vector2(-0.17, 0.10),
	Vector2(0.12, 0.08),
	Vector2(0.42, 0.13),
	Vector2(-0.40, 0.38),
	Vector2(-0.12, 0.42),
	Vector2(0.18, 0.39),
	Vector2(0.44, 0.40),
]

var _cell_nodes: Dictionary = {}
var _hidden_tree_cells: Dictionary = {}
var _forest_nodes: Array[Node] = []
var _ground_node: Node3D
var _border_node: Node3D
var _cells_root: Node3D
var _forest_root: Node3D


func rebuild_all(map: GameMap) -> void:
	if map == null or not is_inside_tree():
		return
	_resolve_roots()
	for node in _cell_nodes.values():
		if node is Node:
			node.queue_free()
	_cell_nodes.clear()
	for node in _forest_nodes:
		if node != null:
			node.queue_free()
	_forest_nodes.clear()
	if _ground_node != null:
		_ground_node.queue_free()
		_ground_node = null
	if _border_node != null:
		_border_node.queue_free()
		_border_node = null

	for y in range(-FOREST_PADDING_TILES, map.playable_height + FOREST_PADDING_TILES):
		for x in range(-FOREST_PADDING_TILES, map.playable_width + FOREST_PADDING_TILES):
			var grid_position := Vector2i(x, y)
			if not map.is_inside_playable_area(grid_position):
				_add_border_forest_cell(map, grid_position)

	_add_playable_ground(map)
	for y in map.playable_height:
		for x in map.playable_width:
			rebuild_cell(map, Vector2i(x, y))
	_add_playable_area_border(map)


func rebuild_cell(map: GameMap, grid_position: Vector2i) -> void:
	if map == null or not is_inside_tree() or not map.is_inside_playable_area(grid_position):
		return
	_resolve_roots()
	var old_node: Node = _cell_nodes.get(grid_position)
	if old_node != null:
		old_node.queue_free()

	var cell := Node3D.new()
	cell.name = "Cell_%d_%d" % [grid_position.x, grid_position.y]
	cell.position = map.grid_to_world(grid_position)
	_cells_root.add_child(cell)
	_cell_nodes[grid_position] = cell

	var feature := map.get_fixed_feature(grid_position)
	if not feature.is_empty():
		_add_fixed_feature_visual(map, cell, feature)
	elif not map.tiles.has(grid_position):
		cell.set_meta("has_map_trees", true)
		_add_cell_trees(map, cell, grid_position)
		cell.visible = not _hidden_tree_cells.has(grid_position)


func set_cell_trees_visible(grid_position: Vector2i, trees_visible: bool) -> void:
	if trees_visible:
		_hidden_tree_cells.erase(grid_position)
	else:
		_hidden_tree_cells[grid_position] = true
	var cell: Node = _cell_nodes.get(grid_position)
	if cell == null or not cell.has_meta("has_map_trees"):
		return
	(cell as Node3D).visible = trees_visible


func are_cell_trees_visible(grid_position: Vector2i) -> bool:
	return not _hidden_tree_cells.has(grid_position)


func _add_border_forest_cell(map: GameMap, grid_position: Vector2i) -> void:
	var cell := Node3D.new()
	cell.name = "Forest_%d_%d" % [grid_position.x, grid_position.y]
	cell.position = map.grid_to_world(grid_position)
	_forest_root.add_child(cell)
	_forest_nodes.append(cell)

	_add_box(cell, "ForestGround", Vector3(map.tile_size * 1.08, GROUND_HEIGHT, map.tile_size * 1.08), Vector3(0.0, -GROUND_HEIGHT * 0.65, 0.0), GROUND_LIGHT_COLOR)
	_add_outside_forest_trees(map, cell, grid_position)


func _add_playable_ground(map: GameMap) -> void:
	_ground_node = Node3D.new()
	_ground_node.name = "PlayableGround"
	add_child(_ground_node)

	var width := float(map.playable_width) * map.tile_size
	var height := float(map.playable_height) * map.tile_size
	_add_box(
		_ground_node,
		"Ground",
		Vector3(width, GROUND_HEIGHT, height),
		Vector3(width * 0.5, -GROUND_HEIGHT * 0.5, height * 0.5),
		GROUND_LIGHT_COLOR
	)


func _add_playable_area_border(map: GameMap) -> void:
	_border_node = Node3D.new()
	_border_node.name = "PlayableAreaBorder"
	add_child(_border_node)

	var line_width := maxf(2.0, map.tile_size * 0.018)
	var y := GROUND_HEIGHT * 0.20
	var width := float(map.playable_width) * map.tile_size
	var height := float(map.playable_height) * map.tile_size
	var center_x := width * 0.5
	var center_z := height * 0.5
	_add_box(_border_node, "BorderNorth", Vector3(width, line_width, line_width), Vector3(center_x, y, 0.0), PLAYABLE_BORDER_COLOR)
	_add_box(_border_node, "BorderSouth", Vector3(width, line_width, line_width), Vector3(center_x, y, height), PLAYABLE_BORDER_COLOR)
	_add_box(_border_node, "BorderWest", Vector3(line_width, line_width, height), Vector3(0.0, y, center_z), PLAYABLE_BORDER_COLOR)
	_add_box(_border_node, "BorderEast", Vector3(line_width, line_width, height), Vector3(width, y, center_z), PLAYABLE_BORDER_COLOR)


func _add_fixed_feature_visual(map: GameMap, parent: Node3D, feature: Dictionary) -> void:
	var feature_type := str(feature.get("type", ""))
	if feature_type == GameMap.FEATURE_MOUNTAIN:
		_add_cone(parent, "Mountain", map.tile_size * 0.58, map.tile_size * 0.64, Vector3(0.0, map.tile_size * 0.32, 0.0), Color(0.42, 0.43, 0.39))
		_add_cone(parent, "SnowCap", map.tile_size * 0.24, map.tile_size * 0.20, Vector3(0.0, map.tile_size * 0.72, 0.0), Color(0.82, 0.84, 0.78))
	elif feature_type == GameMap.FEATURE_RIVER:
		_add_river(map, parent, int(feature.get("rotation_steps", 0)))
	elif feature_type == GameMap.FEATURE_BRIDGE:
		_add_river(map, parent, int(feature.get("rotation_steps", 0)))
		_add_bridge(map, parent, int(feature.get("rotation_steps", 0)))


func _add_river(map: GameMap, parent: Node3D, rotation_steps: int) -> void:
	var horizontal := posmod(rotation_steps, 2) == 0
	var size := Vector3(map.tile_size * 1.04, 0.04, map.tile_size * 0.34) if horizontal else Vector3(map.tile_size * 0.34, 0.04, map.tile_size * 1.04)
	_add_box(parent, "River", size, Vector3(0.0, 0.03, 0.0), Color(0.23, 0.48, 0.68))


func _add_bridge(map: GameMap, parent: Node3D, rotation_steps: int) -> void:
	var horizontal_river := posmod(rotation_steps, 2) == 0
	var size := Vector3(map.tile_size * 0.30, 0.08, map.tile_size * 0.78) if horizontal_river else Vector3(map.tile_size * 0.78, 0.08, map.tile_size * 0.30)
	_add_box(parent, "Bridge", size, Vector3(0.0, 0.09, 0.0), Color(0.55, 0.36, 0.18))


func _add_cell_trees(map: GameMap, parent: Node3D, grid_position: Vector2i) -> void:
	var seed := grid_position.x * 11 + grid_position.y * 7
	var count := 6 + posmod(seed, 3)
	for index in count:
		var slot_index := posmod(index * 4 + seed, TREE_SLOTS.size())
		var offset: Vector2 = TREE_SLOTS[slot_index]
		var scale_factor := 0.70 + float(posmod(seed + index * 5, 7)) * 0.055
		var width_factor := 0.86 + float(posmod(seed + index * 3, 5)) * 0.055
		var rotation_y := float(posmod(seed * 13 + index * 71, 360))
		_add_tree(map, parent, Vector3(offset.x * map.tile_size, 0.0, offset.y * map.tile_size), scale_factor, width_factor, rotation_y)


func _add_outside_forest_trees(map: GameMap, parent: Node3D, grid_position: Vector2i) -> void:
	var seed := grid_position.x * 17 + grid_position.y * 13
	var count := 14 + posmod(seed, 3)
	for index in count:
		var slot_index := posmod(index * 7 + seed, OUTSIDE_TREE_SLOTS.size())
		var offset: Vector2 = OUTSIDE_TREE_SLOTS[slot_index]
		var scale_factor := 0.88 + float(posmod(seed + index * 5, 7)) * 0.055
		var width_factor := 0.98 + float(posmod(seed + index * 3, 5)) * 0.06
		var rotation_y := float(posmod(seed * 19 + index * 67, 360))
		_add_tree(map, parent, Vector3(offset.x * map.tile_size, 0.0, offset.y * map.tile_size), scale_factor, width_factor, rotation_y)


func _add_tree(map: GameMap, parent: Node3D, offset: Vector3, scale_factor: float = 1.0, width_factor: float = 1.0, rotation_y := 0.0) -> void:
	var model := ModelAssets.instantiate_model(ModelAssets.TREE_MODEL, "Tree", offset, map.tile_size * scale_factor)
	if model != null:
		model.scale.x *= width_factor
		model.scale.z *= width_factor
		model.rotation_degrees.y = rotation_y
		parent.add_child(model)


func _add_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance


func _add_cone(parent: Node3D, node_name: String, bottom_radius: float, height: float, local_position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 8
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _resolve_roots() -> void:
	_cells_root = $Cells
	_forest_root = $Forest
