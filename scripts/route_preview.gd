class_name RoutePreview
extends MeshInstance3D

const ROUTE_COLOR := Color(1.0, 0.72, 0.08)
const WIDTH_TILE_RATIO := 0.028
const ROAD_HEIGHT := 0.10
const HEIGHT_TILE_RATIO := 0.003

var _full_path := PackedVector3Array()
var _tile_size := 96.0


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var route_material := StandardMaterial3D.new()
	route_material.albedo_color = ROUTE_COLOR
	route_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	route_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = route_material
	hide_route()


func show_route(points: PackedVector3Array, tile_size: float) -> void:
	_full_path = points
	_tile_size = tile_size
	_render_path(_full_path)


func follow_world_position(world_position: Vector3) -> void:
	if _full_path.size() < 2:
		return
	var closest_segment := 0
	var closest_point := _full_path[0]
	var closest_distance := INF
	for index in range(_full_path.size() - 1):
		var point := Geometry3D.get_closest_point_to_segment(world_position, _full_path[index], _full_path[index + 1])
		var distance := point.distance_squared_to(world_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_segment = index
			closest_point = point
	var remaining := PackedVector3Array([closest_point])
	for index in range(closest_segment + 1, _full_path.size()):
		remaining.append(_full_path[index])
	_render_path(remaining)


func hide_route() -> void:
	_full_path.clear()
	mesh = null
	visible = false


func _render_path(points: PackedVector3Array) -> void:
	if points.size() < 2:
		mesh = null
		visible = false
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width := _tile_size * WIDTH_TILE_RATIO * 0.5
	var height := ROAD_HEIGHT + _tile_size * HEIGHT_TILE_RATIO
	var left_points := PackedVector3Array()
	var right_points := PackedVector3Array()
	for index in range(points.size()):
		var previous := points[maxi(0, index - 1)]
		var next := points[mini(points.size() - 1, index + 1)]
		var tangent := Vector2(next.x - previous.x, next.z - previous.z).normalized()
		if tangent.is_zero_approx():
			continue
		var side := Vector2(-tangent.y, tangent.x) * half_width
		left_points.append(Vector3(points[index].x + side.x, height, points[index].z + side.y))
		right_points.append(Vector3(points[index].x - side.x, height, points[index].z - side.y))
	if left_points.size() < 2:
		mesh = null
		visible = false
		return
	for index in range(left_points.size() - 1):
		var a := left_points[index]
		var b := right_points[index]
		var c := right_points[index + 1]
		var d := left_points[index + 1]
		for vertex in [a, b, c, a, c, d]:
			surface.add_vertex(vertex)
	mesh = surface.commit()
	visible = mesh != null
