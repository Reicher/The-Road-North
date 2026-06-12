class_name GamePlayer
extends Node3D

const GameBalance = preload("res://scripts/game_balance.gd")
const ModelAssets = preload("res://scripts/model_assets.gd")

signal food_changed(food: int)
signal gold_changed(gold: int)
signal health_changed(health: int)
signal base_power_changed(base_power: int)
signal move_started(target_position: Vector2i)
signal moved(grid_position: Vector2i)
signal game_over(reason: String)
signal run_won

@export var map_path: NodePath
@export var inventory_path: NodePath
@export var loot_ui_path: NodePath
@export var rewards_path: NodePath = NodePath("Rewards")
@export var start_position := Vector2i(-1, -1)
@export var starting_food := GameBalance.STARTING_FOOD
@export var starting_gold := 0
@export var starting_health := GameBalance.STARTING_HEALTH
@export var starting_max_health := GameBalance.STARTING_HEALTH
@export var base_power := GameBalance.BASE_POWER
@export_range(0.0, 2.0, 0.01) var move_duration := 0.85
@export_range(1, 8, 1) var move_hop_count := 5
@export_range(0.0, 1.0, 0.01) var move_hop_height_tiles := 0.16
@export_range(0.0, 30.0, 0.5) var move_hop_tilt_degrees := 9.0
@export_range(0.0, 3.0, 0.01) var combat_bump_duration := 0.72
@export_range(0.0, 2.0, 0.01) var post_combat_loot_delay := 0.45

var grid_position := Vector2i.ZERO
var food := 0
var gold := 0
var health := 0
var max_health := 3
var input_enabled := true

var _map: GameMap
var _inventory: InventoryUI
var _loot_ui: LootUI
var _rewards: PlayerRewards
var _moving := false
var _move_target := Vector2i.ZERO
var _combat_running := false
var _game_over := false
var _run_won := false
var _visual_root: Node3D


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_inventory = get_node_or_null(inventory_path) as InventoryUI
	_loot_ui = get_node_or_null(loot_ui_path) as LootUI
	_rewards = get_node_or_null(rewards_path) as PlayerRewards
	if _rewards == null:
		push_warning("Player needs a Rewards child at rewards_path.")
		return
	_rewards.setup(self, _inventory, _loot_ui, _map)
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
	max_health = maxi(1, starting_max_health)
	health = clampi(starting_health, 0, max_health)
	if not _map.tile_pressed.is_connected(_on_tile_pressed):
		_map.tile_pressed.connect(_on_tile_pressed)

	_rebuild_visuals()


func can_move_to(target_position: Vector2i) -> bool:
	if _map == null or _game_over or _run_won or _moving or _combat_running:
		return false
	if food <= 0:
		return false
	return _map.can_move_between(grid_position, target_position)


func move_to(target_position: Vector2i) -> bool:
	if not can_move_to(target_position):
		return false

	var input_enabled_before_move := input_enabled
	_moving = true
	move_started.emit(target_position)
	food -= 1
	food_changed.emit(food)

	var enemy_data: Dictionary = _get_enemy_data(target_position)
	if not enemy_data.is_empty() and int(enemy_data.get("health", 0)) > 0:
		_move_into_enemy(target_position, enemy_data, input_enabled_before_move)
		return true

	var target_world_position := _map.grid_to_world(target_position)
	if move_duration <= 0.0:
		position = target_world_position
		_finish_move(target_position)
		return true

	_move_target = target_position
	_start_hop_move(target_world_position, move_duration, _on_move_tween_finished)
	return true


func is_in_combat() -> bool:
	return _combat_running


func set_health(value: int, check_game_over := true) -> void:
	var clamped_value := clampi(value, 0, max_health)
	if health == clamped_value:
		return
	health = clamped_value
	health_changed.emit(health)
	if check_game_over:
		_check_game_over()


func set_max_health(value: int) -> void:
	var next_max_health := maxi(1, value)
	if max_health == next_max_health:
		return
	max_health = next_max_health
	health = mini(health, max_health)
	health_changed.emit(health)
	_check_game_over()


func set_base_power(value: int) -> void:
	if base_power == value:
		return
	base_power = value
	base_power_changed.emit(base_power)


func get_progression_state() -> Dictionary:
	return {
		"food": food,
		"gold": gold,
		"health": health,
		"max_health": max_health,
		"base_power": base_power,
	}


func apply_progression_state(state: Dictionary, emit_changes := true) -> void:
	food = int(state.get("food", food))
	gold = int(state.get("gold", gold))
	max_health = maxi(1, int(state.get("max_health", max_health)))
	health = clampi(int(state.get("health", health)), 0, max_health)
	base_power = int(state.get("base_power", base_power))
	if not emit_changes:
		return
	food_changed.emit(food)
	gold_changed.emit(gold)
	health_changed.emit(health)
	base_power_changed.emit(base_power)


func add_food(amount: int) -> void:
	if amount <= 0:
		return
	food += amount
	food_changed.emit(food)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func _get_default_starting_food() -> int:
	return GameBalance.STARTING_FOOD


func _ensure_visuals() -> void:
	if _visual_root != null:
		return
	_visual_root = get_node_or_null("Visuals") as Node3D
	if _visual_root == null:
		push_warning("Player needs a Visuals child.")


func _rebuild_visuals() -> void:
	if _visual_root == null or _map == null:
		return
	for child in _visual_root.get_children():
		child.queue_free()

	var tile_size := _map.tile_size
	var model := ModelAssets.instantiate_model(ModelAssets.PLAYER_MODEL, "Pawn", Vector3.ZERO, tile_size * ModelAssets.PAWN_MODEL_SCALE)
	if model != null:
		_visual_root.add_child(model)


func _on_tile_pressed(target_position: Vector2i) -> void:
	if not input_enabled:
		return
	move_to(target_position)


func _finish_move(target_position: Vector2i) -> void:
	grid_position = target_position
	_moving = false
	moved.emit(grid_position)
	if check_run_won():
		return
	if health <= 0:
		trigger_game_over("health")
		return
	_resolve_reward_encounter_at(grid_position)
	_check_game_over()


func _on_move_tween_finished() -> void:
	_finish_move(_move_target)


func _start_hop_move(target_world_position: Vector3, duration: float, finished_callback: Callable) -> void:
	var start_world_position := position
	var travel_direction := (target_world_position - start_world_position).normalized()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		_apply_hop_progress(start_world_position, target_world_position, travel_direction, progress)
	, 0.0, 1.0, duration)
	tween.finished.connect(func() -> void:
		position = target_world_position
		_reset_hop_visuals()
		finished_callback.call()
	)


func _apply_hop_progress(start_world_position: Vector3, target_world_position: Vector3, travel_direction: Vector3, progress: float) -> void:
	position = start_world_position.lerp(target_world_position, progress)
	if _visual_root == null or _map == null:
		return

	var hop_progress := fposmod(progress * float(move_hop_count), 1.0)
	if is_equal_approx(progress, 1.0):
		hop_progress = 1.0
	var hop_arc := sin(hop_progress * PI)
	var landing_squash := pow(1.0 - hop_arc, 8.0)
	_visual_root.position.y = hop_arc * _map.tile_size * move_hop_height_tiles
	_visual_root.rotation.x = deg_to_rad(move_hop_tilt_degrees) * travel_direction.z * hop_arc
	_visual_root.rotation.z = -deg_to_rad(move_hop_tilt_degrees) * travel_direction.x * hop_arc
	_visual_root.scale = Vector3(1.0 + landing_squash * 0.05, 1.0 - landing_squash * 0.08, 1.0 + landing_squash * 0.05)


func _reset_hop_visuals() -> void:
	if _visual_root == null:
		return
	_visual_root.position = Vector3.ZERO
	_visual_root.rotation = Vector3.ZERO
	_visual_root.scale = Vector3.ONE


func get_total_power() -> int:
	return base_power + _rewards.get_power_bonus()


func _move_into_enemy(target_position: Vector2i, enemy_data: Dictionary, previous_input_enabled: bool) -> void:
	_combat_running = true
	input_enabled = false

	_reveal_enemy_at(target_position, enemy_data)
	_set_visual_encounter_data(target_position, enemy_data)

	var target_world_position := _map.grid_to_world(target_position)
	var combat_direction := target_world_position - position
	if combat_bump_duration <= 0.0:
		position = target_world_position
		_finish_enemy_move(target_position, enemy_data, previous_input_enabled, combat_direction)
		return

	_start_hop_move(target_world_position, combat_bump_duration, func() -> void:
		_finish_enemy_move(target_position, enemy_data, previous_input_enabled, combat_direction)
	)


func _finish_enemy_move(target_position: Vector2i, enemy_data: Dictionary, previous_input_enabled: bool, combat_direction: Vector3) -> void:
	var enemy_damage := maxi(0, int(enemy_data.get("power", 0)) - get_total_power())
	set_health(maxi(0, health - enemy_damage), false)

	position = _map.grid_to_world(target_position)
	grid_position = target_position
	_moving = false
	moved.emit(grid_position)
	if check_run_won():
		_combat_running = false
		return
	if health <= 0:
		trigger_game_over("health")
		_combat_running = false
		return

	_map.clear_encounter(target_position)
	await _play_enemy_defeat(target_position, combat_direction)
	if not is_inside_tree():
		return
	_clear_visual_encounter_data(target_position)

	if post_combat_loot_delay > 0.0:
		await get_tree().create_timer(post_combat_loot_delay).timeout
	if not is_inside_tree():
		return
	_rewards.open_enemy_loot(enemy_data)
	input_enabled = previous_input_enabled
	_combat_running = false
	_check_game_over()


func _play_enemy_defeat(target_position: Vector2i, combat_direction: Vector3) -> void:
	var visual_tile := _find_visual_tile(target_position)
	if visual_tile == null:
		return
	var enemy_view := visual_tile.get_node_or_null("Enemy") as EnemyView
	if enemy_view != null:
		await enemy_view.play_defeat(combat_direction)


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


func _resolve_reward_encounter_at(target_position: Vector2i) -> void:
	if _map == null:
		return
	if _rewards.collect_reward_at(target_position):
		_clear_visual_encounter_data(target_position)


func trigger_game_over(reason: String) -> void:
	if _game_over or _run_won:
		return
	_game_over = true
	input_enabled = false
	game_over.emit(reason)


func _check_game_over() -> void:
	if _game_over or _run_won:
		return
	if _map != null and grid_position == _map.get_goal_position():
		check_run_won()
		return
	var reason := ""
	if health <= 0:
		reason = "health"
	elif food <= 0:
		reason = "food"
	if reason.is_empty():
		return
	trigger_game_over(reason)


func check_run_won() -> bool:
	if _map == null or _game_over or _run_won:
		return false
	if grid_position != _map.get_goal_position():
		return false
	_run_won = true
	input_enabled = false
	run_won.emit()
	return true


func _get_enemy_data(target_position: Vector2i) -> Dictionary:
	if _map == null:
		return {}
	var tile_data: Variant = _map.get_tile(target_position)
	if not (tile_data is Dictionary):
		return {}
	var encounter: Dictionary = tile_data.get("encounter", {})
	if str(encounter.get("type", "")) != GameMap.ENCOUNTER_ENEMY:
		return {}
	return encounter


func _reveal_enemy_at(target_position: Vector2i, enemy_data: Dictionary) -> void:
	if _map == null:
		return
	enemy_data["revealed"] = true
	_map.update_encounter_data(target_position, enemy_data)
