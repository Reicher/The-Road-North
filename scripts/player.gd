class_name GamePlayer
extends Node2D

signal food_changed(food: int)
signal health_changed(health: int)
signal moved(grid_position: Vector2i)
signal move_blocked(target_position: Vector2i, reason: String)
signal game_over(reason: String)

@export var map_path: NodePath
@export var food_label_path: NodePath
@export var health_label_path: NodePath
@export var inventory_path: NodePath
@export var start_position := Vector2i(-1, -1)
@export var starting_food := -1
@export var starting_health := 5
@export var attack := 0
@export var armor := 0
@export_range(0.0, 1.0, 0.01) var move_duration := 0.16
@export_range(0.0, 3.0, 0.01) var combat_bump_duration := 0.72
@export_range(0.0, 3.0, 0.01) var combat_round_pause := 1.05
@export_range(0.0, 3.0, 0.01) var damage_number_duration := 1.35
@export var pawn_color := Color(0.93, 0.56, 0.25)
@export var pawn_shadow_color := Color(0.18, 0.16, 0.14, 0.32)

var grid_position := Vector2i.ZERO
var food := 0
var health := 0
var input_enabled := true

var _map: GameMap
var _food_label: Label
var _health_label: Label
var _inventory: InventoryUI
var _moving := false
var _move_target := Vector2i.ZERO
var _combat_running := false
var _game_over := false


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_food_label = get_node_or_null(food_label_path) as Label
	_health_label = get_node_or_null(health_label_path) as Label
	_inventory = get_node_or_null(inventory_path) as InventoryUI

	if _map == null:
		push_warning("Player needs a GameMap at map_path.")
		return

	if start_position.x < 0 or start_position.y < 0:
		start_position = Vector2i(_map.playable_width / 2, _map.playable_height - 1)

	grid_position = start_position
	position = _map.grid_to_world(grid_position)
	food = starting_food if starting_food >= 0 else _map.playable_width * 3
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
	return _map.can_move_between(grid_position, target_position)


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

	_moving = true
	food -= 1
	_update_food_label()
	food_changed.emit(food)

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


func _on_tile_pressed(target_position: Vector2i) -> void:
	if not input_enabled:
		return
	move_to(target_position)


func _finish_move(target_position: Vector2i) -> void:
	var previous_position := grid_position
	grid_position = target_position
	_moving = false
	moved.emit(grid_position)
	_start_enemy_combat(grid_position, target_position - previous_position)
	if not _combat_running:
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
	var bonus := 0
	if _inventory != null:
		bonus = _inventory.get_attack_bonus()
	return attack + bonus


func get_total_armor() -> int:
	var bonus := 0
	if _inventory != null:
		bonus = _inventory.get_armor_bonus()
	return armor + bonus


func _start_enemy_combat(target_position: Vector2i, entry_delta: Vector2i) -> void:
	if _map == null or _combat_running:
		return
	var tile_data: Variant = _map.get_tile(target_position)
	if not (tile_data is Dictionary):
		return
	var enemy_data: Dictionary = tile_data.get("enemy", {})
	if enemy_data.is_empty() or int(enemy_data.get("health", 0)) <= 0:
		return
	_run_enemy_combat(target_position, entry_delta)


func _run_enemy_combat(target_position: Vector2i, entry_delta: Vector2i) -> void:
	_combat_running = true
	var previous_input_enabled := input_enabled
	input_enabled = false

	var tile_data: Dictionary = _map.get_tile(target_position)
	var enemy_data: Dictionary = tile_data.get("enemy", {})
	enemy_data["revealed"] = true
	_update_enemy_visual(target_position, enemy_data)
	var visual_tile := _find_visual_tile(target_position)
	if visual_tile != null:
		await _take_combat_stances(target_position, visual_tile, entry_delta)

	while health > 0 and int(enemy_data.get("health", 0)) > 0:
		var player_damage: int = maxi(0, get_total_attack() - int(enemy_data.get("armor", 0)))
		var enemy_damage: int = maxi(0, int(enemy_data.get("attack", 0)) - get_total_armor())

		await _play_combat_clash(target_position, visual_tile, entry_delta)

		enemy_data["health"] = maxi(0, int(enemy_data.get("health", 0)) - player_damage)
		set_health(maxi(0, health - enemy_damage))
		_update_enemy_visual(target_position, enemy_data)
		var tile_center := _map.grid_to_world(target_position)
		_spawn_damage_number(tile_center + Vector2(28.0, -30.0), player_damage, Color(1.0, 0.77, 0.28))
		_spawn_damage_number(tile_center + Vector2(-28.0, 18.0), enemy_damage, Color(1.0, 0.28, 0.22))

		if player_damage == 0 and enemy_damage == 0:
			break
		if is_inside_tree():
			await get_tree().create_timer(combat_round_pause).timeout

	if int(enemy_data.get("health", 0)) <= 0:
		_map.clear_enemy(target_position)
		if visual_tile != null:
			visual_tile.set_enemy_data({})
			visual_tile.enemy_offset = Vector2.ZERO
	else:
		_update_enemy_visual(target_position, enemy_data)
		if visual_tile != null:
			visual_tile.enemy_offset = Vector2.ZERO

	position = _map.grid_to_world(target_position)
	input_enabled = previous_input_enabled
	_combat_running = false
	_check_game_over()


func _take_combat_stances(target_position: Vector2i, visual_tile: RoadTile, entry_delta: Vector2i) -> void:
	if not is_inside_tree():
		return
	var tile_center := _map.grid_to_world(target_position)
	var stance_offset := _combat_stance_offset(entry_delta)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", tile_center - stance_offset, combat_bump_duration * 0.5)
	tween.tween_property(visual_tile, "enemy_offset", stance_offset, combat_bump_duration * 0.5)
	await tween.finished


func _play_combat_clash(target_position: Vector2i, visual_tile: RoadTile, entry_delta: Vector2i) -> void:
	if not is_inside_tree():
		return
	var tile_center := _map.grid_to_world(target_position)
	var stance_offset := _combat_stance_offset(entry_delta)
	var clash_offset := stance_offset * 0.18
	var half_duration := combat_bump_duration * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", tile_center - clash_offset, half_duration)
	if visual_tile != null:
		tween.tween_property(visual_tile, "enemy_offset", clash_offset, half_duration)
	await tween.finished

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", tile_center - stance_offset, half_duration)
	if visual_tile != null:
		tween.tween_property(visual_tile, "enemy_offset", stance_offset, half_duration)
	await tween.finished


func _combat_stance_offset(entry_delta: Vector2i) -> Vector2:
	var tile_size := 64.0
	if _map != null:
		tile_size = _map.tile_size
	var direction := Vector2(entry_delta)
	if direction.length_squared() == 0.0:
		direction = Vector2.UP
	else:
		direction = direction.normalized()
	return direction * tile_size * 0.22


func _spawn_damage_number(world_position: Vector2, amount: int, color: Color) -> void:
	if not is_inside_tree():
		return
	var label := Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.03, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.size = Vector2(48.0, 28.0)
	label.position = world_position - label.size * 0.5
	get_parent().add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -30.0), damage_number_duration)
	tween.tween_property(label, "modulate:a", 0.0, damage_number_duration)
	tween.finished.connect(label.queue_free)


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
