class_name GamePlayer
extends Node3D

const GameBalance = preload("res://scripts/game_balance.gd")
const ModelAssets = preload("res://scripts/model_assets.gd")
const RoadPath = preload("res://scripts/road_path.gd")

signal food_changed(food: int)
signal gold_changed(gold: int)
signal health_changed(health: int)
signal base_power_changed(base_power: int)
signal move_started(target_position: Vector2i)
signal moved(grid_position: Vector2i)
signal move_failed(grid_position: Vector2i)
signal permanent_encounter_reached(grid_position: Vector2i, encounter: Dictionary)
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
@export_range(0.0, 2.0, 0.01) var combat_roll_duration := 0.65

var grid_position := Vector2i.ZERO
var food := 0
var gold := 0
var health := 0
var max_health := 3
var input_enabled := true:
	set(value):
		input_enabled = value
		if not input_enabled:
			clear_tile_selection()

var _map: GameMap
var _inventory: InventoryUI
var _loot_ui: LootUI
var _rewards: PlayerRewards
var _moving := false
var _move_target := Vector2i.ZERO
var _route_destination := Vector2i.ZERO
var _combat_running := false
var _game_over := false
var _run_won := false
var _visual_root: Node3D
var _combat_overlay: Control
var _movement_selection: MovementSelectionUI
var _selected_tile := Vector2i(-1, -1)
var _inventory_max_health_bonus := 0
var _combat_roll_queue: Array[Vector2i] = []
var _combat_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_map = get_node_or_null(map_path) as GameMap
	_inventory = get_node_or_null(inventory_path) as InventoryUI
	_loot_ui = get_node_or_null(loot_ui_path) as LootUI
	_rewards = get_node_or_null(rewards_path) as PlayerRewards
	_combat_overlay = get_node_or_null("CombatPopupLayer/CombatPopup") as Control
	_movement_selection = get_node_or_null("MovementSelection") as MovementSelectionUI
	_combat_rng.randomize()
	if _rewards == null:
		push_warning("Player needs a Rewards child at rewards_path.")
		return
	_rewards.setup(self, _inventory, _loot_ui, _map)
	if _inventory != null and not _inventory.stats_changed.is_connected(_on_inventory_stats_changed):
		_inventory.stats_changed.connect(_on_inventory_stats_changed)
	if _loot_ui != null and not _loot_ui.closed.is_connected(continue_route_after_encounter):
		_loot_ui.closed.connect(continue_route_after_encounter)
	_ensure_visuals()

	if _map == null:
		push_warning("Player needs a GameMap at map_path.")
		return

	if start_position.x < 0 or start_position.y < 0:
		start_position = Vector2i(_map.playable_width / 2, _map.playable_height - 1)

	grid_position = start_position
	position = RoadPath.get_world_anchor(_map, grid_position)
	food = starting_food if starting_food >= 0 else _get_default_starting_food()
	gold = starting_gold
	max_health = maxi(1, starting_max_health)
	health = clampi(starting_health, 0, max_health)
	_inventory_max_health_bonus = _get_inventory_max_health_bonus()
	if _inventory_max_health_bonus > 0:
		max_health += _inventory_max_health_bonus
		health += _inventory_max_health_bonus
	if not _map.tile_pressed.is_connected(_on_tile_pressed):
		_map.tile_pressed.connect(_on_tile_pressed)
	if _movement_selection != null and not _movement_selection.confirmed.is_connected(confirm_selected_move):
		_movement_selection.confirmed.connect(confirm_selected_move)

	_rebuild_visuals()
	refresh_enemy_risk_colors()


func can_move_to(target_position: Vector2i) -> bool:
	if _map == null or _game_over or _run_won or _combat_running:
		return false
	if target_position == grid_position:
		return true
	if food <= 0:
		return false
	return not _map.find_shortest_path(grid_position, target_position).is_empty()


func move_to(target_position: Vector2i) -> bool:
	if not can_move_to(target_position):
		return false
	_map.flash_tile(target_position)
	_route_destination = target_position
	if _moving:
		return true

	_moving = true
	_move_target = target_position
	move_started.emit(target_position)
	if target_position == grid_position:
		if move_duration <= 0.0:
			_reset_hop_visuals()
			_moving = false
			moved.emit(grid_position)
		else:
			_jump_in_place_and_finish()
		return true
	if move_duration <= 0.0:
		_follow_route_immediately(input_enabled)
	else:
		_follow_route(input_enabled)
	return true


func _follow_route_immediately(input_enabled_before_move: bool) -> void:
	while not _game_over and not _run_won and grid_position != _route_destination:
		var path := _map.find_shortest_path(grid_position, _route_destination)
		if path.size() < 2 or food <= 0:
			break
		var next_position := path[1]
		_move_target = next_position
		var enemy_data: Dictionary = _get_enemy_data(next_position)
		if not enemy_data.is_empty() and int(enemy_data.get("health", 0)) > 0:
			_move_into_enemy(next_position, enemy_data, input_enabled_before_move)
			return
		_spend_movement_food()
		position = RoadPath.get_world_anchor(_map, next_position)
		grid_position = next_position
		refresh_enemy_risk_colors()
		if check_run_won():
			_moving = false
			moved.emit(grid_position)
			return
		var reached_encounter := _map.get_encounter(grid_position)
		_resolve_reward_encounter_at(grid_position)
		_check_game_over()
		if _encounter_pauses_route(reached_encounter):
			break
	_moving = false
	moved.emit(grid_position)


func _follow_route(input_enabled_before_move: bool) -> void:
	while is_inside_tree() and not _game_over and not _run_won:
		if grid_position == _route_destination:
			break

		var path := _map.find_shortest_path(grid_position, _route_destination)
		if path.size() < 2 or food <= 0:
			break
		var next_position := path[1]
		_move_target = next_position

		var enemy_data: Dictionary = _get_enemy_data(next_position)
		if not enemy_data.is_empty() and int(enemy_data.get("health", 0)) > 0:
			_move_into_enemy(next_position, enemy_data, input_enabled_before_move)
			return

		_spend_movement_food()
		if move_duration > 0.0:
			await _animate_hop_to_grid_position(next_position, move_duration)
			if not is_inside_tree():
				return
		else:
			position = RoadPath.get_world_anchor(_map, next_position)

		grid_position = next_position
		refresh_enemy_risk_colors()
		if check_run_won():
			_moving = false
			moved.emit(grid_position)
			return
		var reached_encounter := _map.get_encounter(grid_position)
		_resolve_reward_encounter_at(grid_position)
		_check_game_over()
		if _encounter_pauses_route(reached_encounter):
			break

	_moving = false
	moved.emit(grid_position)


func _jump_in_place_and_finish() -> void:
	await _hop_in_place()
	if not is_inside_tree():
		return
	_moving = false
	moved.emit(grid_position)


func play_spawn_hop() -> void:
	await _hop_in_place()


func is_in_combat() -> bool:
	return _combat_running


func queue_combat_rolls(player_roll: int, enemy_roll: int) -> void:
	_combat_roll_queue.append(Vector2i(clampi(player_roll, 1, 6), clampi(enemy_roll, 1, 6)))


func get_combat_risk_level(enemy_power: int) -> String:
	var difference := get_total_power() - enemy_power
	if difference <= -2:
		return "Dangerous"
	if difference == -1:
		return "Risky"
	if difference == 0:
		return "Fair"
	if difference == 1:
		return "Favorable"
	return "Safe"


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
	refresh_enemy_risk_colors()


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
	_inventory_max_health_bonus = _get_inventory_max_health_bonus()
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
	var multiplier := _inventory.get_gold_multiplier() if _inventory != null else 1
	gold += amount * multiplier
	gold_changed.emit(gold)


func _get_inventory_max_health_bonus() -> int:
	return _inventory.get_max_health_bonus() if _inventory != null else 0


func _on_inventory_stats_changed() -> void:
	refresh_enemy_risk_colors()
	var next_bonus := _get_inventory_max_health_bonus()
	var difference := next_bonus - _inventory_max_health_bonus
	if difference == 0:
		return
	_inventory_max_health_bonus = next_bonus
	max_health = maxi(1, max_health + difference)
	health = clampi(health + difference, 0, max_health)
	health_changed.emit(health)
	_check_game_over()


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
	select_tile(target_position)


func select_tile(target_position: Vector2i) -> void:
	if _map == null or not _map.is_inside_playable_area(target_position):
		clear_tile_selection()
		return
	_selected_tile = target_position
	_map.select_tile(target_position)
	var can_confirm := _is_selectable_movement_destination(target_position)
	if _movement_selection != null:
		_movement_selection.show_selection(
			_get_tile_display_name(target_position),
			target_position,
			_map,
			can_confirm
		)


func confirm_selected_move() -> bool:
	if _selected_tile.x < 0 or not _is_selectable_movement_destination(_selected_tile):
		return false
	var target := _selected_tile
	clear_tile_selection()
	return move_to(target)


func clear_tile_selection() -> void:
	_selected_tile = Vector2i(-1, -1)
	if _map != null:
		_map.clear_selected_tile()
	if _movement_selection != null:
		_movement_selection.hide_selection()


func get_selected_tile() -> Vector2i:
	return _selected_tile


func _is_selectable_movement_destination(target_position: Vector2i) -> bool:
	if target_position == grid_position:
		return can_move_to(target_position)
	var has_road := _map.get_tile(target_position) != null
	var is_bridge := str(_map.get_fixed_feature(target_position).get("type", "")) == GameMap.FEATURE_BRIDGE
	return (has_road or is_bridge) and can_move_to(target_position)


func _get_tile_display_name(target_position: Vector2i) -> String:
	var tile_data: Variant = _map.get_tile(target_position)
	if tile_data is Dictionary:
		var definition: Resource = tile_data.get("definition")
		var tile_name := str(definition.get("display_name")) if definition != null else "Road"
		var encounter_name := _get_encounter_display_name(_map.get_encounter(target_position))
		return tile_name if encounter_name.is_empty() else "%s - %s" % [tile_name, encounter_name]
	var feature_type := str(_map.get_fixed_feature(target_position).get("type", ""))
	match feature_type:
		GameMap.FEATURE_MOUNTAIN:
			return "Mountain"
		GameMap.FEATURE_RIVER:
			return "River"
		GameMap.FEATURE_BRIDGE:
			return "Bridge"
	return "Forest"


func _get_encounter_display_name(encounter: Dictionary) -> String:
	match str(encounter.get("type", "")):
		GameMap.ENCOUNTER_ENEMY:
			return "Enemy"
		GameMap.ENCOUNTER_BERRY_BUSH:
			return "Berry Bush"
		GameMap.ENCOUNTER_CACHE:
			return "Cache"
		GameMap.ENCOUNTER_CAMPFIRE:
			return "Campfire"
		GameMap.ENCOUNTER_TAVERN:
			return "Tavern"
		GameMap.ENCOUNTER_WITCH_HUT:
			return "Witch's Hut"
		GameMap.ENCOUNTER_SHRINE:
			return "Shrine"
		GameMap.ENCOUNTER_GRAVEYARD:
			return "Graveyard"
	return ""


func _hop_in_place() -> void:
	if move_duration <= 0.0 or _visual_root == null or _map == null:
		_reset_hop_visuals()
		return
	var duration := minf(move_duration, 0.38)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		_visual_root.position.y = sin(progress * PI) * _map.tile_size * move_hop_height_tiles
	, 0.0, 1.0, duration)
	await tween.finished
	_reset_hop_visuals()


func _animate_hop_to_grid_position(target_position: Vector2i, duration: float) -> void:
	var path := RoadPath.build_move_path(_map, grid_position, target_position, position)
	var target_world_position := path[-1]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		var sample := RoadPath.sample_path(path, progress)
		_apply_hop_at_position(sample["position"], sample["direction"], progress)
	, 0.0, 1.0, duration)
	await tween.finished
	position = target_world_position
	_reset_hop_visuals()


func _apply_hop_progress(start_world_position: Vector3, target_world_position: Vector3, travel_direction: Vector3, progress: float) -> void:
	_apply_hop_at_position(start_world_position.lerp(target_world_position, progress), travel_direction, progress)


func _apply_hop_at_position(world_position: Vector3, travel_direction: Vector3, progress: float) -> void:
	position = world_position
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


func refresh_enemy_risk_colors() -> void:
	if _map == null:
		return
	for position_variant in _map.tiles.keys():
		var tile_position: Vector2i = position_variant
		var encounter := _map.get_encounter(tile_position)
		if str(encounter.get("type", "")) != GameMap.ENCOUNTER_ENEMY:
			continue
		var visual_encounter := encounter.duplicate(true)
		visual_encounter["risk_level"] = get_combat_risk_level(int(encounter.get("power", 0)))
		_set_visual_encounter_data(tile_position, visual_encounter)


func _set_enemy_combat_status_visible(status_visible: bool) -> void:
	if _map == null:
		return
	for position_variant in _map.tiles.keys():
		var visual_tile := _find_visual_tile(position_variant)
		if visual_tile == null:
			continue
		var enemy_view := visual_tile.get_node_or_null("Enemy") as EnemyView
		if enemy_view != null:
			enemy_view.set_combat_status_visible(status_visible)


func _move_into_enemy(target_position: Vector2i, enemy_data: Dictionary, previous_input_enabled: bool) -> void:
	_combat_running = true
	input_enabled = false
	var origin_position := grid_position

	_reveal_enemy_at(target_position, enemy_data)
	var visual_enemy_data := enemy_data.duplicate(true)
	visual_enemy_data["risk_level"] = get_combat_risk_level(int(enemy_data.get("power", 0)))
	_set_visual_encounter_data(target_position, visual_enemy_data)
	_set_enemy_combat_status_visible(false)

	var target_world_position := RoadPath.get_world_anchor(_map, target_position)
	var combat_direction := target_world_position - position
	var player_power := get_total_power()
	var enemy_power := int(enemy_data.get("power", 0))
	_spend_movement_food()
	if move_duration > 0.0:
		await _animate_hop_to_grid_position(target_position, move_duration)
		if not is_inside_tree():
			return
	else:
		position = target_world_position
	grid_position = target_position

	if _combat_overlay == null:
		return
	_combat_overlay.open_preview(player_power, enemy_power, get_combat_risk_level(enemy_power))
	while is_inside_tree() and health > 0:
		var action: String = await _wait_for_combat_action()
		if action == "retreat":
			_combat_overlay.close()
			await _retreat_from_enemy(origin_position, previous_input_enabled)
			return
		if action != "fight":
			continue

		var rolls := _roll_combat_dice()
		_combat_overlay.start_rolling()
		if combat_roll_duration > 0.0:
			await get_tree().create_timer(combat_roll_duration).timeout
			if not is_inside_tree():
				return
		var player_score := player_power + rolls.x
		var enemy_score := enemy_power + rolls.y
		if player_score > enemy_score:
			_combat_overlay.show_round_result(rolls.x, rolls.y, "Victory", true)
			await _finish_enemy_victory(target_position, enemy_data, combat_direction)
			_combat_overlay.enable_ok()
			await _combat_overlay.ok_pressed
			if not is_inside_tree():
				return
			_combat_overlay.close()
			_finish_combat(previous_input_enabled)
			moved.emit(grid_position)
			if check_run_won():
				return
			_check_game_over()
			continue_route_after_encounter()
			return
		if enemy_score > player_score:
			set_health(maxi(0, health - 1), false)
			_combat_overlay.show_round_result(rolls.x, rolls.y, "Defeat", false)
			if health <= 0:
				_combat_overlay.close()
				_moving = false
				trigger_game_over("health")
				_combat_running = false
				return
		else:
			_combat_overlay.show_round_result(rolls.x, rolls.y, "Tie", false)


func _finish_enemy_victory(target_position: Vector2i, enemy_data: Dictionary, combat_direction: Vector3) -> void:
	_map.clear_encounter(target_position)
	await _play_enemy_defeat(target_position, combat_direction)
	if not is_inside_tree():
		return
	_clear_visual_encounter_data(target_position)

	_moving = false

	_rewards.open_enemy_loot(enemy_data)


func _retreat_from_enemy(origin_position: Vector2i, previous_input_enabled: bool) -> void:
	var origin_world_position := RoadPath.get_world_anchor(_map, origin_position)
	if move_duration > 0.0:
		await _animate_hop_to_grid_position(origin_position, move_duration)
		if not is_inside_tree():
			return
	else:
		position = origin_world_position
	grid_position = origin_position
	_moving = false
	_route_destination = grid_position
	_finish_combat(previous_input_enabled)
	move_failed.emit(grid_position)
	_check_game_over()


func _wait_for_combat_action() -> String:
	var action := {"value": ""}
	var fight_callback := func() -> void: action["value"] = "fight"
	var retreat_callback := func() -> void: action["value"] = "retreat"
	_combat_overlay.fight_pressed.connect(fight_callback, CONNECT_ONE_SHOT)
	_combat_overlay.retreat_pressed.connect(retreat_callback, CONNECT_ONE_SHOT)
	while str(action["value"]).is_empty():
		await get_tree().process_frame
	if _combat_overlay.fight_pressed.is_connected(fight_callback):
		_combat_overlay.fight_pressed.disconnect(fight_callback)
	if _combat_overlay.retreat_pressed.is_connected(retreat_callback):
		_combat_overlay.retreat_pressed.disconnect(retreat_callback)
	return str(action["value"])

func _roll_combat_dice() -> Vector2i:
	if not _combat_roll_queue.is_empty():
		return _combat_roll_queue.pop_front()
	return Vector2i(_combat_rng.randi_range(1, 6), _combat_rng.randi_range(1, 6))


func _finish_combat(previous_input_enabled: bool) -> void:
	if _combat_overlay != null:
		_combat_overlay.close()
	refresh_enemy_risk_colors()
	input_enabled = previous_input_enabled
	_combat_running = false


func continue_route_after_encounter() -> bool:
	if _moving or _combat_running or _game_over or _run_won:
		return false
	if grid_position == _route_destination or food <= 0:
		return false
	if _map.find_shortest_path(grid_position, _route_destination).size() < 2:
		return false
	_moving = true
	_move_target = _route_destination
	move_started.emit(_route_destination)
	if move_duration <= 0.0:
		_follow_route_immediately(input_enabled)
	else:
		_follow_route(input_enabled)
	return true


func _encounter_pauses_route(encounter: Dictionary) -> bool:
	if encounter.is_empty():
		return false
	if str(encounter.get("type", "")) in GameConstants.REUSABLE_ENCOUNTER_TYPES:
		return true
	return _loot_ui != null and _loot_ui.is_open()


func _spend_movement_food() -> void:
	food -= 1
	food_changed.emit(food)


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
	var encounter := _map.get_encounter(target_position)
	if str(encounter.get("type", "")) in GameConstants.REUSABLE_ENCOUNTER_TYPES:
		permanent_encounter_reached.emit(target_position, encounter.duplicate(true))
		return
	if _rewards.collect_reward_at(target_position):
		if str(encounter.get("type", "")) == GameMap.ENCOUNTER_BERRY_BUSH:
			_set_visual_encounter_data(target_position, {"type": GameMap.ENCOUNTER_BERRY_BUSH, "depleted": true})
		else:
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
