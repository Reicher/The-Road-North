class_name RoadPath
extends RefCounted

const DIRECTIONS := {
	"north": Vector2(0.0, -1.0),
	"east": Vector2(1.0, 0.0),
	"south": Vector2(0.0, 1.0),
	"west": Vector2(-1.0, 0.0),
}
const CURVE_SAMPLES := 8


static func is_corner(openings: Dictionary) -> bool:
	var directions := _open_directions(openings)
	return directions.size() == 2 and is_zero_approx(directions[0].dot(directions[1]))


static func get_anchor_offset(openings: Dictionary, tile_size: float) -> Vector2:
	if not is_corner(openings):
		return Vector2.ZERO
	var directions := _open_directions(openings)
	var center := (directions[0] + directions[1]) * tile_size * 0.5
	return center - (directions[0] + directions[1]).normalized() * tile_size * 0.5


static func get_centerline(openings: Dictionary, tile_size: float, samples := CURVE_SAMPLES * 2) -> PackedVector2Array:
	if not is_corner(openings):
		return PackedVector2Array()
	var directions := _open_directions(openings)
	return _arc_points(directions[0], directions[1], tile_size, samples)


static func get_curve_center(openings: Dictionary, tile_size: float) -> Vector2:
	if not is_corner(openings):
		return Vector2.ZERO
	var directions := _open_directions(openings)
	return (directions[0] + directions[1]) * tile_size * 0.5


static func build_move_path(map: GameMap, from_position: Vector2i, to_position: Vector2i, current_world_position: Vector3) -> PackedVector3Array:
	var delta := to_position - from_position
	var direction_name := _direction_name(Vector2(delta))
	var opposite_name: String = str(GameConstants.OPPOSITE_DIRECTIONS.get(direction_name, ""))
	var from_center := map.grid_to_world(from_position)
	var to_center := map.grid_to_world(to_position)
	var from_points := _anchor_to_edge(_get_openings(map, from_position), direction_name, map.tile_size)
	var to_points := _anchor_to_edge(_get_openings(map, to_position), opposite_name, map.tile_size)
	var path := PackedVector3Array([current_world_position])

	for index in range(1, from_points.size()):
		path.append(from_center + Vector3(from_points[index].x, 0.0, from_points[index].y))
	for index in range(to_points.size() - 2, -1, -1):
		path.append(to_center + Vector3(to_points[index].x, 0.0, to_points[index].y))
	return path


static func get_world_anchor(map: GameMap, grid_position: Vector2i) -> Vector3:
	var offset := get_anchor_offset(_get_openings(map, grid_position), map.tile_size)
	return map.grid_to_world(grid_position) + Vector3(offset.x, 0.0, offset.y)


static func sample_path(path: PackedVector3Array, progress: float) -> Dictionary:
	if path.size() < 2:
		return {"position": path[0] if not path.is_empty() else Vector3.ZERO, "direction": Vector3.FORWARD}
	var lengths := PackedFloat32Array()
	var total_length := 0.0
	for index in range(path.size() - 1):
		var length := path[index].distance_to(path[index + 1])
		lengths.append(length)
		total_length += length
	var target_distance := clampf(progress, 0.0, 1.0) * total_length
	var traveled := 0.0
	for index in range(lengths.size()):
		var segment_length := lengths[index]
		if target_distance <= traveled + segment_length or index == lengths.size() - 1:
			var ratio := (target_distance - traveled) / segment_length if segment_length > 0.0 else 1.0
			return {
				"position": path[index].lerp(path[index + 1], clampf(ratio, 0.0, 1.0)),
				"direction": (path[index + 1] - path[index]).normalized(),
			}
		traveled += segment_length
	return {"position": path[-1], "direction": (path[-1] - path[-2]).normalized()}


static func _anchor_to_edge(openings: Dictionary, direction_name: String, tile_size: float) -> PackedVector2Array:
	var direction: Vector2 = DIRECTIONS.get(direction_name, Vector2.ZERO)
	if not is_corner(openings):
		return PackedVector2Array([Vector2.ZERO, direction * tile_size * 0.5])
	var directions := _open_directions(openings)
	var other_direction: Vector2 = directions[1] if directions[0] == direction else directions[0]
	var full_arc := _arc_points(other_direction, direction, tile_size, CURVE_SAMPLES * 2 + 1)
	var half_arc := PackedVector2Array()
	for index in range(CURVE_SAMPLES, full_arc.size()):
		half_arc.append(full_arc[index])
	return half_arc


static func _arc_points(from_direction: Vector2, to_direction: Vector2, tile_size: float, samples: int) -> PackedVector2Array:
	var radius := tile_size * 0.5
	var center := (from_direction + to_direction) * radius
	var from_radial := from_direction * radius - center
	var to_radial := to_direction * radius - center
	var from_angle := from_radial.angle()
	var angle_delta := wrapf(to_radial.angle() - from_angle, -PI, PI)
	var points := PackedVector2Array()
	for index in range(samples):
		var ratio := float(index) / float(samples - 1)
		points.append(center + Vector2.from_angle(from_angle + angle_delta * ratio) * radius)
	return points


static func _get_openings(map: GameMap, grid_position: Vector2i) -> Dictionary:
	var tile_data: Variant = map.get_tile(grid_position)
	if tile_data is Dictionary:
		return tile_data.get("connections", {})
	return map.get_fixed_feature_connections(grid_position)


static func _open_directions(openings: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for direction_name in DIRECTIONS:
		if openings.get(direction_name, false) == true:
			result.append(DIRECTIONS[direction_name])
	return result


static func _direction_name(direction: Vector2) -> String:
	for direction_name in DIRECTIONS:
		if DIRECTIONS[direction_name] == direction:
			return direction_name
	return ""
