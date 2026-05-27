class_name GamePlayer
extends Node2D

const PLAYER_REWARDS_SCRIPT := preload("res://scripts/player_rewards.gd")
const PLAYER_COMBAT_SCRIPT := preload("res://scripts/player_combat.gd")

signal food_changed(food: int)
signal gold_changed(gold: int)
signal health_changed(health: int)
signal moved(grid_position: Vector2i)
signal move_blocked(target_position: Vector2i, reason: String)
signal game_over(reason: String)

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
@export var attack := 0
@export var armor := 0
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


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_food_label = get_node_or_null(food_label_path) as Label
	_health_label = get_node_or_null(health_label_path) as Label
	_inventory = get_node_or_null(inventory_path) as InventoryUI
	_loot_ui = get_node_or_null(loot_ui_path)
	_rewards = _get_or_create_rewards()
	_rewards.setup(self, _inventory, _loot_ui)
	_combat = _get_or_create_combat()
	_combat.setup(self, _map)

	if _map == null:
		push_warning("Player needs a GameMap at map_path.")
		return

	if start_position.x < 0 or start_position.y < 0:
		start_position = Vector2i(_map.playable_width / 2, _map.playable_height - 1)

	grid_position = start_position
	position = _map.grid_to_world(grid_position)
	food = starting_food if starting_food >= 0 else _map.playable_width * 2
	gold = starting_gold
	health = starting_health
	_update_food_label()
	_update_health_label()

	if not _map.tile_pressed.is_connected(_on_tile_pressed):
		_map.tile_pressed.connect(_on_tile_pressed)

	queue_redraw()


func _draw() -> void:
	var tile_size := 64.0
	if _map != null:
		tile_size = _map.tile_size

	var radius := tile_size * 0.18
	draw_circle(Vector2(0.0, radius * 0.55), radius * 0.9, pawn_shadow_color)
	draw_circle(Vector2.ZERO, radius, pawn_color)
	draw_circle(Vector2(0.0, -radius * 0.38), radius * 0.42, pawn_color.lightened(0.18))


func can_move_to(target_position: Vector2i) -> bool:
	if _map == null or _moving or _combat_running or _game_over or food <= 0:
		return false
	return _map.can_move_between(grid_position, target_position) and _combat.can_defeat_enemy_at(target_position)


func move_to(target_position: Vector2i) -> bool:
	if _map == null:
		move_blocked.emit(target_position, "missing_map")
		return false
	if _game_over:
		move_blocked.emit(target_position, "game_over")
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
	if not _combat.can_defeat_enemy_at(target_position):
		return false

	_moving = true
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


func set_health(value: int) -> void:
	if health == value:
		return
	health = value
	_update_health_label()
	health_changed.emit(health)
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


func _on_tile_pressed(target_position: Vector2i) -> void:
	if not input_enabled:
		return
	if _combat.is_blocked_by_enemy_armor(grid_position, target_position):
		return
	move_to(target_position)


func _finish_move(target_position: Vector2i) -> void:
	grid_position = target_position
	_moving = false
	_collect_landmark_at(grid_position)
	moved.emit(grid_position)
	_check_game_over()


func _on_move_tween_finished() -> void:
	_finish_move(_move_target)


func _update_food_label() -> void:
	if _food_label != null:
		_food_label.text = "Food: %d" % food


func _update_health_label() -> void:
	if _health_label != null:
		_health_label.text = "Health: %d" % health


func get_total_attack() -> int:
	return attack + _rewards.get_attack_bonus()


func get_total_armor() -> int:
	return armor + _rewards.get_armor_bonus()


func _move_into_enemy(target_position: Vector2i, enemy_data: Dictionary) -> void:
	_combat_running = true
	var previous_input_enabled := input_enabled
	input_enabled = false

	enemy_data["revealed"] = true
	_update_enemy_visual(target_position, enemy_data)

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
	set_health(maxi(0, health - enemy_damage))

	var visual_tile := _find_visual_tile(target_position)
	_map.clear_enemy(target_position)
	if visual_tile != null:
		visual_tile.set_enemy_data({})
		visual_tile.enemy_offset = Vector2.ZERO

	position = _map.grid_to_world(target_position)
	grid_position = target_position
	_moving = false
	if post_combat_loot_delay > 0.0:
		await get_tree().create_timer(post_combat_loot_delay).timeout
	_show_enemy_loot(enemy_data)
	input_enabled = previous_input_enabled
	_combat_running = false
	_collect_landmark_at(grid_position)
	moved.emit(grid_position)
	_check_game_over()


func _update_enemy_visual(target_position: Vector2i, enemy_data: Dictionary) -> void:
	_map.update_enemy_data(target_position, enemy_data)
	var visual_tile := _find_visual_tile(target_position)
	if visual_tile != null:
		visual_tile.set_enemy_data(enemy_data)


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


func _collect_landmark_at(target_position: Vector2i) -> void:
	if _map == null:
		return
	var landmark := _map.consume_landmark(target_position)
	if landmark.is_empty():
		return
	var visual_tile := _find_visual_tile(target_position)
	if visual_tile != null:
		visual_tile.landmark_data = {}
	var loot: Array = landmark.get("loot", [])
	_rewards.collect_landmark_loot(loot)


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
	if _game_over:
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
