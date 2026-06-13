class_name EnemyView
extends Node3D

const ENEMY_COLOR := Color(0.78, 0.12, 0.10)
const POWER_DISPLAY_PIXEL_SIZE := 0.0015
const POWER_ICON := preload("res://assets/images/stats/stat_power.png")
const ModelAssets = preload("res://scripts/model_assets.gd")

@export_range(0.0, 1.0, 0.01) var knock_down_duration := 0.24
@export_range(0.0, 1.0, 0.01) var fade_out_duration := 0.32
@export_range(0.0, 120.0, 1.0) var knock_down_degrees := 82.0

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


func play_defeat(knock_direction: Vector3) -> void:
	if enemy_data.is_empty() or not visible:
		return

	var flat_direction := Vector3(knock_direction.x, 0.0, knock_direction.z).normalized()
	if flat_direction.is_zero_approx():
		flat_direction = Vector3.FORWARD
	var fall_axis := Vector3(flat_direction.z, 0.0, -flat_direction.x)
	var target_rotation := fall_axis * deg_to_rad(knock_down_degrees)
	var target_position := position + flat_direction * tile_size * 0.12

	if knock_down_duration > 0.0:
		var knock_tween := create_tween()
		knock_tween.set_trans(Tween.TRANS_QUAD)
		knock_tween.set_ease(Tween.EASE_OUT)
		knock_tween.set_parallel(true)
		knock_tween.tween_property(self, "rotation", target_rotation, knock_down_duration)
		knock_tween.tween_property(self, "position", target_position, knock_down_duration)
		await knock_tween.finished
		if not is_inside_tree():
			return
	else:
		rotation = target_rotation
		position = target_position

	if fade_out_duration > 0.0:
		var fade_tween := create_tween()
		fade_tween.set_trans(Tween.TRANS_QUAD)
		fade_tween.set_ease(Tween.EASE_IN)
		fade_tween.set_parallel(true)
		fade_tween.tween_property(self, "scale", Vector3.ONE * 0.82, fade_out_duration)
		_tween_visual_alpha(fade_tween, self, fade_out_duration)
		await fade_tween.finished
		if not is_inside_tree():
			return

	visible = false


func set_combat_status_visible(status_visible: bool) -> void:
	for node_name in ["PowerLabel", "PowerIcon"]:
		var status_node := get_node_or_null(node_name) as Node3D
		if status_node != null:
			status_node.visible = status_visible


func _rebuild() -> void:
	if not is_inside_tree():
		return
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	for child in get_children():
		child.free()
	if enemy_data.is_empty():
		return

	var eye_color := Color(1.0, 0.84, 0.34)
	var model := ModelAssets.instantiate_model(ModelAssets.ENEMY_MODEL, "EnemyModel", Vector3.ZERO, tile_size * ModelAssets.PAWN_MODEL_SCALE)
	if model != null:
		_apply_material_override(model, _make_material(ENEMY_COLOR))
		add_child(model)

	if enemy_data.get("revealed", false) != true:
		_add_box("QuestionMark", Vector3(tile_size * 0.035, tile_size * 0.20, tile_size * 0.035), Vector3(0.0, tile_size * 0.54, 0.0), eye_color)
	else:
		_add_power_display(int(enemy_data.get("power", 0)), str(enemy_data.get("risk_level", "")))


func _apply_material_override(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_override(child, material)


func _tween_visual_alpha(tween: Tween, node: Node, duration: float) -> void:
	if node is GeometryInstance3D:
		tween.tween_property(node, "transparency", 1.0, duration)
	if node is Label3D or node is Sprite3D:
		tween.tween_property(node, "modulate:a", 0.0, duration)
	for child in node.get_children():
		_tween_visual_alpha(tween, child, duration)


func _add_power_display(power: int, risk_level: String) -> void:
	var label := Label3D.new()
	label.name = "PowerLabel"
	label.text = str(power)
	label.font_size = PlayerStatsUI.STAT_VALUE_FONT_SIZE
	label.modulate = _risk_color(risk_level)
	label.outline_modulate = Color(0.16, 0.05, 0.04)
	label.outline_size = 3
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = POWER_DISPLAY_PIXEL_SIZE
	label.position = Vector3(tile_size * 0.09, tile_size * 0.52, 0.0)
	add_child(label)

	var icon := Sprite3D.new()
	icon.name = "PowerIcon"
	icon.texture = POWER_ICON
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.fixed_size = true
	icon.pixel_size = POWER_DISPLAY_PIXEL_SIZE
	icon.scale = Vector3.ONE * (PlayerStatsUI.STAT_ICON_SIZE / float(POWER_ICON.get_width()))
	icon.position = Vector3(tile_size * -0.09, tile_size * 0.52, 0.0)
	add_child(icon)


func _risk_color(risk_level: String) -> Color:
	match risk_level:
		"Dangerous":
			return Color(1.0, 0.22, 0.16)
		"Risky":
			return Color(1.0, 0.56, 0.18)
		"Fair":
			return Color(1.0, 0.88, 0.30)
		"Favorable":
			return Color(0.55, 0.92, 0.36)
		"Safe":
			return Color(0.24, 0.90, 0.52)
		_:
			return Color(1.0, 0.94, 0.76)


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
