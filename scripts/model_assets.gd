class_name ModelAssets
extends RefCounted

const TREE_MODEL := "res://assets/models/tree.obj"
const HOUSE_MODEL := "res://assets/models/house.obj"
const PLAYER_MODEL := "res://assets/models/player_pawn_lightblue_no_shadow.obj"
const ENEMY_MODEL := PLAYER_MODEL

static var _cache: Dictionary = {}


static func instantiate_model(path: String, node_name: String, local_position: Vector3, uniform_scale: float) -> Node3D:
	var resource := _load_model(path)
	if resource == null:
		push_error("Missing or invalid 3D model asset: %s" % path)
		return null

	var node: Node3D
	if resource is PackedScene:
		node = resource.instantiate() as Node3D
	elif resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource
		node = mesh_instance

	if node == null:
		push_error("3D model asset is not a Node3D or Mesh: %s" % path)
		return null

	node.name = node_name
	node.position = local_position
	node.scale = Vector3.ONE * uniform_scale
	return node


static func _load_model(path: String) -> Resource:
	if _cache.has(path):
		return _cache[path]
	var resource: Resource
	if ResourceLoader.exists(path):
		resource = load(path)
	else:
		resource = _load_obj_mesh(path)
	if resource == null:
		return null
	_cache[path] = resource
	return resource


static func _load_obj_mesh(path: String) -> ArrayMesh:
	if not FileAccess.file_exists(path):
		push_error("3D model file does not exist: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open 3D model file: %s" % path)
		return null

	var vertices: Array[Vector3] = []
	var surface_vertices: Dictionary = {}
	var surface_normals: Dictionary = {}
	var materials: Dictionary = {}
	var current_material := ""
	var base_dir := path.get_base_dir()

	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		var keyword := str(parts[0])
		if keyword == "mtllib" and parts.size() >= 2:
			materials = _load_mtl("%s/%s" % [base_dir, str(parts[1])])
		elif keyword == "usemtl" and parts.size() >= 2:
			current_material = str(parts[1])
			_ensure_surface(current_material, surface_vertices, surface_normals)
		elif keyword == "v" and parts.size() >= 4:
			vertices.append(Vector3(str(parts[1]).to_float(), str(parts[2]).to_float(), str(parts[3]).to_float()))
		elif keyword == "f" and parts.size() >= 4:
			_ensure_surface(current_material, surface_vertices, surface_normals)
			var face: Array[Vector3] = []
			for index in range(1, parts.size()):
				var vertex_index := _parse_face_vertex_index(str(parts[index]), vertices.size())
				if vertex_index >= 0 and vertex_index < vertices.size():
					face.append(vertices[vertex_index])
			for index in range(1, face.size() - 1):
				_add_triangle(current_material, face[0], face[index], face[index + 1], surface_vertices, surface_normals)

	var mesh := ArrayMesh.new()
	for material_name in surface_vertices.keys():
		var packed_vertices: PackedVector3Array = surface_vertices[material_name]
		if packed_vertices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = packed_vertices
		arrays[Mesh.ARRAY_NORMAL] = surface_normals[material_name]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface_index := mesh.get_surface_count() - 1
		mesh.surface_set_material(surface_index, materials.get(material_name, _make_material(Color(0.8, 0.8, 0.8))))
	if mesh.get_surface_count() == 0:
		push_error("3D model file has no usable mesh surfaces: %s" % path)
		return null
	return mesh


static func _load_mtl(path: String) -> Dictionary:
	var materials: Dictionary = {}
	if not FileAccess.file_exists(path):
		return materials
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return materials

	var current_name := ""
	var current_color := Color(0.8, 0.8, 0.8)
	var current_alpha := 1.0
	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		var keyword := str(parts[0])
		if keyword == "newmtl":
			if not current_name.is_empty():
				materials[current_name] = _make_material(Color(current_color.r, current_color.g, current_color.b, current_alpha))
			current_name = str(parts[1]) if parts.size() >= 2 else ""
			current_color = Color(0.8, 0.8, 0.8)
			current_alpha = 1.0
		elif keyword == "Kd" and parts.size() >= 4:
			current_color = Color(str(parts[1]).to_float(), str(parts[2]).to_float(), str(parts[3]).to_float())
		elif keyword == "d" and parts.size() >= 2:
			current_alpha = str(parts[1]).to_float()
	if not current_name.is_empty():
		materials[current_name] = _make_material(Color(current_color.r, current_color.g, current_color.b, current_alpha))
	return materials


static func _ensure_surface(material_name: String, surface_vertices: Dictionary, surface_normals: Dictionary) -> void:
	if surface_vertices.has(material_name):
		return
	surface_vertices[material_name] = PackedVector3Array()
	surface_normals[material_name] = PackedVector3Array()


static func _parse_face_vertex_index(token: String, vertex_count: int) -> int:
	var raw_index := int(token.split("/", false)[0])
	return vertex_count + raw_index if raw_index < 0 else raw_index - 1


static func _add_triangle(
	material_name: String,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	surface_vertices: Dictionary,
	surface_normals: Dictionary
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	surface_vertices[material_name].append_array(PackedVector3Array([a, b, c]))
	surface_normals[material_name].append_array(PackedVector3Array([normal, normal, normal]))


static func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
