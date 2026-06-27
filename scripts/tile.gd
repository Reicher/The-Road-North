class_name RoadTile
extends Node3D

@export var definition: Resource:
	set(value):
		definition = value
		_refresh_visuals()

@export_range(0, 3, 1) var rotation_steps := 0:
	set(value):
		rotation_steps = posmod(value, 4)
		_refresh_visuals()

@export_range(16.0, 256.0, 1.0) var tile_size := 96.0:
	set(value):
		tile_size = value
		_refresh_visuals()

@export var tile_tint := Color.WHITE:
	set(value):
		tile_tint = value
		_refresh_visuals()

@export var highlight_enabled := false:
	set(value):
		highlight_enabled = value
		_refresh_visuals()

@export var highlight_color := Color(0.25, 0.85, 0.35, 0.38):
	set(value):
		highlight_color = value
		_refresh_visuals()

@export var encounter_data := {}:
	set(value):
		encounter_data = value
		if _encounter_uses_plaza(value):
			_encounter_plaza_visible = true
		_refresh_visuals()

@export var encounter_power_visible := true:
	set(value):
		encounter_power_visible = value
		_refresh_visuals()

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
		_refresh_visuals()

var _visuals: Node
var _encounter_plaza_visible := false


func _ready() -> void:
	_resolve_visuals()
	_refresh_visuals()


func rotate_clockwise() -> void:
	rotation_steps += 1


func set_highlight(enabled: bool, color: Color = highlight_color) -> void:
	highlight_color = color
	highlight_enabled = enabled


func get_openings() -> Dictionary:
	if definition == null or not definition.has_method("get_rotated_openings"):
		return {}
	return definition.get_rotated_openings(rotation_steps)


func set_encounter_data(value: Dictionary) -> void:
	encounter_data = value


func set_preview_encounter_data(value: Dictionary) -> void:
	# Preview tiles are reused between cards and must not retain a plaza from
	# an encounter shown by the previous card.
	_encounter_plaza_visible = _encounter_uses_plaza(value)
	encounter_data = value


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	if not _resolve_visuals():
		return
	_visuals.render(
		definition,
		rotation_steps,
		tile_size,
		tile_tint,
		highlight_enabled,
		highlight_color,
		encounter_data,
		_encounter_plaza_visible,
		enemy_offset if enemy_offset is Vector3 else Vector3.ZERO,
		encounter_power_visible
	)


func _resolve_visuals() -> bool:
	_visuals = get_node_or_null("Visuals")
	if _visuals == null:
		push_warning("RoadTile needs a Visuals child.")
		return false
	return true


func _encounter_type() -> String:
	return str(encounter_data.get("type", ""))


func _encounter_uses_plaza(value: Dictionary) -> bool:
	var encounter_type := str(value.get("type", ""))
	return not encounter_type.is_empty() and encounter_type not in [
		GameMap.ENCOUNTER_ENEMY,
		GameMap.ENCOUNTER_BERRY_BUSH,
	]
