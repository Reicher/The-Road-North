class_name EnemyView
extends Node3D

@export_range(16.0, 256.0, 1.0) var tile_size := 96.0:
	set(value):
		tile_size = value
		_rebuild()

@export var enemy_data := {}:
	set(value):
		enemy_data = value
		visible = not enemy_data.is_empty()
		_rebuild()


func _ready() -> void:
	visible = not enemy_data.is_empty()
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	if enemy_data.is_empty():
		return

	var body_color := Color(0.55, 0.10, 0.13)
	var eye_color := Color(1.0, 0.84, 0.34)
	_add_sphere("Body", tile_size * 0.14, Vector3(0.0, tile_size * 0.18, 0.0), body_color)
	_add_sphere("Head", tile_size * 0.10, Vector3(0.0, tile_size * 0.34, -tile_size * 0.035), body_color.lightened(0.08))
	_add_sphere("LeftEye", tile_size * 0.025, Vector3(-tile_size * 0.035, tile_size * 0.36, -tile_size * 0.11), eye_color)
	_add_sphere("RightEye", tile_size * 0.025, Vector3(tile_size * 0.035, tile_size * 0.36, -tile_size * 0.11), eye_color)

	if enemy_data.get("revealed", false) != true:
		_add_box("QuestionMark", Vector3(tile_size * 0.035, tile_size * 0.20, tile_size * 0.035), Vector3(0.0, tile_size * 0.54, 0.0), eye_color)


func _add_sphere(node_name: String, radius: float, local_position: Vector3, color: Color) -> void:
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


func _add_box(node_name: String, size: Vector3, local_position: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	add_child(instance)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
