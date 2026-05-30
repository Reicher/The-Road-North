class_name GamePlayer
extends Node3D

const PLAYER_REWARDS_SCRIPT := preload("res://scripts/player_rewards.gd")
const PLAYER_COMBAT_SCRIPT := preload("res://scripts/player_combat.gd")
const DEFAULT_FOOD_MAP_AREA_DIVISOR := 4.0

signal food_changed(food: int)
signal gold_changed(gold: int)
signal health_changed(health: int)
signal move_started(target_position: Vector2i)
signal moved(grid_position: Vector2i)
signal move_blocked(target_position: Vector2i, reason: String)
signal game_over(reason: String)
signal run_won

@export var map_path: NodePath
@export var food_label_path: NodePath
@export var health_label_path: NodePath
@export var inventory_path: NodePath
@export var loot_ui_path: NodePath
@export var rewards_path: NodePath = NodePath("Rewards")
@export var combat_path: NodePath = NodePath("Combat")
@export var start_position := Vector2i(-1, -1)
@export var starting_food := -1
@export var starting_gold := 0
@export var starting_health := 3
@export var power := 0
@export_range(0.0, 1.0, 0.01) var move_duration := 0.16
@export_range(0.0, 3.0, 0.01) var combat_bump_duration := 0.72
@export_range(0.0, 2.0, 0.01) var post_combat_loot_delay := 0.45
@export var pawn_color := Color(0.93, 0.56, 0.25)
@export var pawn_shadow_color := Color(0.18, 0.16, 0.14, 0.32)

var grid_position := Vector2i.ZERO
var food := 0
var gold := 0
var health := 0
var input_enabled := true

var _map: GameMap
var _food_label: Label
var _health_label: Label
var _inventory: InventoryUI
var _loot_ui: Node
var _rewards: Node
var _combat: Node
var _moving := false
var _move_target := Vector2i.ZERO
var _combat_running := false
var _game_over := false
var _run_won := false
var _visual_root: Node3D


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_food_label = get_node_or_null(food_label_path) as Label
	_health_label = get_node_or_null(health_label_path) as Label
	_inventory = get_node_or_null(inventory_path) as InventoryUI
	_loot_ui = get_node_or_null(loot_ui_path)
	_rewards = _get_or_create_rewards()
	_rewards.setup(self, _inventory, _loot_ui, _map)
	_combat = _get_or_create_combat()
	_combat.setup(self, _map)
	_ensure_visuals()

	if _map == null:
		push_warning("Player needs a GameMap at map_path.")
		return

	if start_position.x < 0 or start_position.y < 0:
		start_position = Vector2i(_map.playable_width / 2, _map.playable_height - 1)

	grid_position = start_position
	position = _map.grid_to_world(grid_position)
	food = starting_food if starting_food >= 0 else _get_default_starting_food()
	gold = starting_gold
	health = starting_health
	_update_food_label()
	_update_health_label()

	if not _map.tile_pressed.is_connected(_on_tile_pressed):
		_map.tile_pressed.connect(_on_tile_pressed)

	_rebuild_visuals()


func can_move_to(target_position: Vector2i) -> bool:
	if _map == null or _moving or _combat_running or _game_over or _run_won or food <= 0:
		return false
	return _map.can_move_between(grid_position, target_position)


func move_to(target_position: Vector2i) -> bool:
	if _map == null:
		move_blocked.emit(target_position, "missing_map")
		return false
	if _game_over:
		move_blocked.emit(target_position, "game_over")
		return false
	if _run_won:
		move_blocked.emit(target_position, "run_won")
		return false
	if _moving:
		move_blocked.emit(target_position, "moving")
		return false
	if _combat_running:
		move_blocked.emit(target_position, "combat")
		return false
	if food <= 0:
		move_blocked.emit(target_position, "no_food")
		return false
	if not _map.can_move_between(grid_position, target_position):
		move_blocked.emit(target_position, "invalid_road")
		return false

	_moving = true
	move_started.emit(target_position)
	food -= 1
	_update_food_label()
	food_changed.emit(food)

	var enemy_data: Dictionary = _combat.get_enemy_data(target_position)
	if not enemy_data.is_empty() and int(enemy_data.get("health", 0)) > 0:
		_move_into_enemy(target_position, enemy_data)
		return true

	var target_world_position := _map.grid_to_world(target_position)
	if move_duration <= 0.0:
		position = target_world_position
		_finish_move(target_position)
		return true

	_move_target = target_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_world_position, move_duration)
	tween.finished.connect(_on_move_tween_finished)
	return true


func is_moving() -> bool:
	return _moving


func is_in_combat() -> bool:
	return _combat_running


func set_health(value: int, check_game_over := true) -> void:
	if health == value:
		return
	health = value
	_update_health_label()
	health_changed.emit(health)
	if check_game_over:
		_check_game_over()


func add_food(amount: int) -> void:
	if amount <= 0:
		return
	food += amount
	_update_food_label()
	food_changed.emit(food)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func _get_default_starting_food() -> int:
	return maxi(1, roundi(float(_map.playable_width * _map.playable_height) / DEFAULT_FOOD_MAP_AREA_DIVISOR))


func _ensure_visuals() -> void:
	if _visual_root != null:
		return
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)


func _rebuild_visuals() -> void:
	if _visual_root == null or _map == null:
		return
	for child in _visual_root.get_children():
		child.queue_free()

	var tile_size := _map.tile_size
	var radius := tile_size * 0.16
	_add_cylinder("Shadow", radius * 1.05, tile_size * 0.025, Vector3(0.0, tile_size * 0.012, 0.0), pawn_shadow_color)
	_add_sphere("Body", radius, Vector3(0.0, tile_size * 0.20, 0.0), pawn_color)
	_add_sphere("Head", radius * 0.62, Vector3(0.0, tile_size * 0.42, -tile_size * 0.02), pawn_color.lightened(0.18))


func _add_cylinder(node_name: String, radius: float, height: float, local_position: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	_visual_root.add_child(instance)


func _add_sphere(node_name: String, radius: float, local_position: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _make_material(color)
	_visual_root.add_child(instance)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _on_tile_pressed(target_position: Vector2i) -> void:
	if not input_enabled:
		return
	move_to(target_position)


func _finish_move(target_position: Vector2i) -> void:
	grid_position = target_position
	_moving = false
	moved.emit(grid_position)
	if _check_run_won():
		return
	_check_game_over()
	if _game_over:
		return
	_resolve_reward_encounter_at(grid_position)


func _on_move_tween_finished() -> void:
	_finish_move(_move_target)


func _update_food_label() -> void:
	if _food_label != null:
		_food_label.text = "Food: %d" % food


func _update_health_label() -> void:
	if _health_label != null:
		_health_label.text = "Health: %d" % health


func get_total_power() -> int:
	return power + _rewards.get_power_bonus()


func _move_into_enemy(target_position: Vector2i, enemy_data: Dictionary) -> void:
	_combat_running = true
	var previous_input_enabled := input_enabled
	input_enabled = false

	_combat.reveal_enemy_at(target_position, enemy_data)
	_set_visual_encounter_data(target_position, enemy_data)

	var target_world_position := _map.grid_to_world(target_position)
	if combat_bump_duration <= 0.0:
		position = target_world_position
		_finish_enemy_move(target_position, enemy_data, previous_input_enabled)
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", target_world_position, combat_bump_duration)
	tween.finished.connect(func() -> void:
		_finish_enemy_move(target_position, enemy_data, previous_input_enabled)
	)


func _finish_enemy_move(target_position: Vector2i, enemy_data: Dictionary, previous_input_enabled: bool) -> void:
	var enemy_damage: int = _combat.get_damage_from(enemy_data)
	set_health(maxi(0, health - enemy_damage), false)

	position = _map.grid_to_world(target_position)
	grid_position = target_position
	_moving = false
	moved.emit(grid_position)
	if _check_run_won():
		_combat_running = false
		return
	_check_game_over()
	if _game_over:
		_combat_running = false
		return

	_combat.clear_enemy_at(target_position)
	_clear_visual_encounter_data(target_position)

	if post_combat_loot_delay > 0.0:
		await get_tree().create_timer(post_combat_loot_delay).timeout
	_show_enemy_loot(enemy_data)
	input_enabled = previous_input_enabled
	_combat_running = false
	_check_game_over()


func _set_visual_encounter_data(target_position: Vector2i, encounter_data: Dictionary) -> void:
	var visual_tile := _find_visual_tile(target_position)
	if visual_tile != null:
		visual_tile.set_encounter_data(encounter_data)


func _clear_visual_encounter_data(target_position: Vector2i) -> void:
	var visual_tile := _find_visual_tile(target_position)
	if visual_tile != null:
		visual_tile.set_encounter_data({})
		visual_tile.enemy_offset = Vector3.ZERO


func _find_visual_tile(target_position: Vector2i) -> RoadTile:
	var parent := get_parent()
	if parent == null:
		return null
	var roads := parent.get_node_or_null("Roads") as Roads
	if roads == null:
		return null
	return roads.get_visual_tile(target_position)


func _show_enemy_loot(enemy_data: Dictionary) -> void:
	_rewards.open_enemy_loot(enemy_data)


func _resolve_reward_encounter_at(target_position: Vector2i) -> void:
	if _map == null:
		return
	if _rewards.collect_reward_at(target_position):
		_clear_visual_encounter_data(target_position)


func _get_or_create_rewards() -> Node:
	var rewards := get_node_or_null(rewards_path)
	if rewards != null:
		return rewards
	rewards = PLAYER_REWARDS_SCRIPT.new()
	rewards.name = "Rewards"
	add_child(rewards)
	return rewards


func _get_or_create_combat() -> Node:
	var combat := get_node_or_null(combat_path)
	if combat != null:
		return combat
	combat = PLAYER_COMBAT_SCRIPT.new()
	combat.name = "Combat"
	add_child(combat)
	return combat


func _check_game_over() -> void:
	if _game_over or _run_won:
		return
	if _map != null and grid_position == _map.get_goal_position():
		_check_run_won()
		return
	var reason := ""
	if health <= 0:
		reason = "health"
	elif food <= 0:
		reason = "food"
	if reason.is_empty():
		return
	_game_over = true
	input_enabled = false
	game_over.emit(reason)


func _check_run_won() -> bool:
	if _map == null or _game_over or _run_won:
		return false
	if grid_position != _map.get_goal_position():
		return false
	_run_won = true
	input_enabled = false
	run_won.emit()
	return true
