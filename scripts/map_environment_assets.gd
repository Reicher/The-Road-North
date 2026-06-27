class_name MapEnvironmentAssets
extends RefCounted

const VisualPalette = preload("res://scripts/map_visual_palette.gd")
const RiverVisualScript = preload("res://scripts/river_visual.gd")


static func create_tree(
	tile_size: float,
	offset: Vector3,
	scale_factor := 1.0,
	width_factor := 1.0,
	rotation_y := 0.0,
	variant := 0
) -> Node3D:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = offset
	tree.rotation_degrees.y = rotation_y
	var slender_width := width_factor * 0.82
	tree.scale = Vector3(slender_width, 1.0, slender_width) * scale_factor

	_add_cylinder(tree, "Trunk", tile_size * 0.026, tile_size * 0.25, Vector3(0.0, tile_size * 0.125, 0.0), VisualPalette.WOOD_DARK, 5)
	var lower_color := VisualPalette.FOLIAGE.darkened(0.08 + float(posmod(variant, 3)) * 0.025)
	var upper_color := lower_color.lightened(0.025)
	_add_cone(tree, "CrownLower", tile_size * 0.19, tile_size * 0.34, Vector3(0.0, tile_size * 0.31, 0.0), lower_color, 7)
	_add_cone(tree, "CrownUpper", tile_size * 0.14, tile_size * 0.29, Vector3(tile_size * 0.012, tile_size * 0.48, -tile_size * 0.008), upper_color, 7)
	for child in tree.get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tree


static func add_mountain(parent: Node3D, tile_size: float, variant := 0) -> Node3D:
	var mountain := Node3D.new()
	mountain.name = "Mountain"
	parent.add_child(mountain)
	var rock := VisualPalette.STONE.darkened(0.10)
	_add_cone(mountain, "MainPeak", tile_size * 0.44, tile_size * 0.68, Vector3(-tile_size * 0.06, tile_size * 0.34, 0.0), rock, 7)
	_add_cone(mountain, "SidePeak", tile_size * 0.30, tile_size * 0.46, Vector3(tile_size * 0.24, tile_size * 0.23, tile_size * 0.12), VisualPalette.STONE, 7)
	_add_cone(mountain, "SnowCap", tile_size * 0.15, tile_size * 0.20, Vector3(-tile_size * 0.06, tile_size * 0.69, 0.0), VisualPalette.STONE_LIGHT, 7)
	mountain.rotation_degrees.y = float(posmod(variant * 47, 360))
	return mountain


static func add_river(parent: Node3D, tile_size: float, rotation_steps: int) -> Node3D:
	var river := RiverVisualScript.new()
	river.name = "River"
	river.tile_size = tile_size
	river.rotation.y = PI * 0.5 if posmod(rotation_steps, 2) == 1 else 0.0
	parent.add_child(river)
	_add_box(river, "Water", Vector3(tile_size * 1.05, tile_size * 0.035, tile_size * 0.38), Vector3(0.0, 0.025, 0.0), VisualPalette.WATER)
	_add_box(river, "ShallowNorth", Vector3(tile_size * 1.05, 0.012, tile_size * 0.055), Vector3(0.0, 0.052, -tile_size * 0.155), VisualPalette.WATER.lightened(0.10))
	_add_box(river, "ShallowSouth", Vector3(tile_size * 1.05, 0.012, tile_size * 0.055), Vector3(0.0, 0.052, tile_size * 0.155), VisualPalette.WATER.darkened(0.08))
	_add_current_mark(river, "CurrentA", tile_size, Vector3(-0.32, 0.052, -0.09), 0.24, -8.0)
	_add_current_mark(river, "CurrentB", tile_size, Vector3(-0.05, 0.053, 0.08), 0.20, 9.0)
	_add_current_mark(river, "CurrentC", tile_size, Vector3(0.20, 0.052, -0.055), 0.18, -6.0)
	_add_current_mark(river, "CurrentD", tile_size, Vector3(0.40, 0.053, 0.075), 0.12, 7.0)
	return river


static func add_bridge(parent: Node3D, tile_size: float, rotation_steps: int) -> Node3D:
	var bridge := Node3D.new()
	bridge.name = "Bridge"
	bridge.rotation.y = PI * 0.5 if posmod(rotation_steps, 2) == 1 else 0.0
	parent.add_child(bridge)
	for index in 7:
		var z := (-0.42 + float(index) * 0.14) * tile_size
		var plank := _add_box(bridge, "Plank%d" % index, Vector3(tile_size * 0.31, tile_size * 0.065, tile_size * 0.12), Vector3(0.0, tile_size * 0.095, z), VisualPalette.WOOD.lightened(0.03 * float(index % 2)))
		plank.rotation.y = deg_to_rad(-2.0 + float(index % 3) * 2.0)
	for side in [-1.0, 1.0]:
		_add_box(bridge, "Rail%d" % int(side), Vector3(tile_size * 0.035, tile_size * 0.035, tile_size), Vector3(side * tile_size * 0.18, tile_size * 0.105, 0.0), VisualPalette.WOOD_DARK)
	return bridge


static func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = VisualPalette.make_material(color)
	parent.add_child(instance)
	return instance


static func _add_current_mark(river: Node3D, node_name: String, tile_size: float, normalized_position: Vector3, length_ratio: float, rotation_degrees: float) -> void:
	var mark := _add_box(
		river,
		node_name,
		Vector3(tile_size * length_ratio, 0.02, tile_size * 0.070),
		Vector3(normalized_position.x * tile_size, 0.10, normalized_position.z * tile_size),
		VisualPalette.WATER_CURRENT
	)
	mark.rotation.y = deg_to_rad(rotation_degrees)
	mark.material_override = VisualPalette.make_material(VisualPalette.WATER_CURRENT, true)
	mark.set_meta("flow_start_x", mark.position.x)


static func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, segments: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = VisualPalette.make_material(color)
	parent.add_child(instance)
	return instance


static func _add_cone(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, segments: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = VisualPalette.make_material(color)
	parent.add_child(instance)
	return instance
