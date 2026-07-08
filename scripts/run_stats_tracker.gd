class_name RunStatsTracker
extends Node

const RunStats = preload("res://scripts/run_stats.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")

var stats := RunStats.new()
var _player: GamePlayer
var _map: GameMap
var _last_food := 0
var _last_gold := 0
var _last_health := 0
var _last_position := Vector2i.ZERO
var _visited_positions: Dictionary = {}
var _level_positions: Dictionary = {}


func start_new_run(expedition_name: String) -> void:
	stats.reset(expedition_name)
	_visited_positions.clear()
	_level_positions.clear()
	_player = null
	_map = null


func attach_level(level: Node, level_number: int) -> void:
	if level == null:
		return
	stats.highest_level_reached = maxi(stats.highest_level_reached, level_number)
	_player = level.get_node_or_null("Player") as GamePlayer
	_map = level.get_node_or_null("Map") as GameMap
	_level_positions.clear()
	if _player != null:
		_last_food = _player.food
		_last_gold = _player.gold
		_last_health = _player.health
		_last_position = _player.grid_position
		_note_position(_last_position)
		_connect_player(_player)
	var placement := level.get_node_or_null("PlacementController") as PlacementController
	if placement != null:
		_connect_placement(placement)
	var deck := level.get_node_or_null("DeckController") as DeckController
	if deck != null:
		_connect_deck(deck)
	var inventory := level.get_node_or_null("UI/Inventory") as InventoryUI
	if inventory != null:
		if not inventory.item_added.is_connected(_on_item_added):
			inventory.item_added.connect(_on_item_added)
		_update_item_stats(inventory)


func finalize_run(result: String, reason: String) -> void:
	stats.final_result = result
	stats.death_reason = reason
	if _player != null:
		stats.health_remaining = _player.health
		stats.food_remaining = _player.food
		stats.gold_remaining = _player.gold
		stats.max_player_power_reached = maxi(stats.max_player_power_reached, _player.get_total_power())
	if _map != null and _player != null:
		var delta := _map.get_goal_position() - _player.grid_position
		stats.distance_from_goal_on_death = absi(delta.x) + absi(delta.y)
	stats.graves_not_visited = 1 if stats.graves_not_visited == 0 else stats.graves_not_visited
	stats.trees_ignored = maxi(stats.trees_ignored, stats.moves_taken * 7 + stats.tiles_placed * 11)


func _connect_player(player: GamePlayer) -> void:
	if not player.food_changed.is_connected(_on_food_changed):
		player.food_changed.connect(_on_food_changed)
	if not player.gold_changed.is_connected(_on_gold_changed):
		player.gold_changed.connect(_on_gold_changed)
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	if not player.moved.is_connected(_on_player_moved):
		player.moved.connect(_on_player_moved)
	if not player.combat_started.is_connected(_on_combat_started):
		player.combat_started.connect(_on_combat_started)
	if not player.combat_won.is_connected(_on_combat_won):
		player.combat_won.connect(_on_combat_won)
	if not player.combat_retreat.is_connected(_on_combat_retreat):
		player.combat_retreat.connect(_on_combat_retreat)
	if not player.reward_collected.is_connected(_on_reward_collected):
		player.reward_collected.connect(_on_reward_collected)


func _connect_placement(placement: PlacementController) -> void:
	if not placement.placement_confirmed.is_connected(_on_placement_confirmed):
		placement.placement_confirmed.connect(_on_placement_confirmed)
	if not placement.tile_rotated.is_connected(_on_tile_rotated):
		placement.tile_rotated.connect(_on_tile_rotated)


func _connect_deck(deck: DeckController) -> void:
	if not deck.card_consumed.is_connected(_on_card_consumed):
		deck.card_consumed.connect(_on_card_consumed)
	if not deck.cards_drawn.is_connected(_on_cards_drawn):
		deck.cards_drawn.connect(_on_cards_drawn)


func _on_food_changed(food: int) -> void:
	var delta := food - _last_food
	if delta > 0:
		stats.food_gained += delta
	elif delta < 0:
		stats.food_spent += -delta
	_last_food = food


func _on_gold_changed(gold: int) -> void:
	var delta := gold - _last_gold
	if delta > 0:
		stats.gold_gained += delta
	elif delta < 0:
		stats.gold_spent += -delta
	_last_gold = gold


func _on_health_changed(health: int) -> void:
	var delta := health - _last_health
	if delta < 0:
		stats.damage_taken += -delta
	_last_health = health


func _on_player_moved(position: Vector2i) -> void:
	if position == _last_position:
		return
	stats.moves_taken += 1
	if position.y > _last_position.y:
		stats.steps_walked_backwards += 1
	if _visited_positions.has(position):
		stats.unnecessary_backtracking += 1
	_note_position(position)
	_last_position = position
	if _player != null:
		stats.max_player_power_reached = maxi(stats.max_player_power_reached, _player.get_total_power())


func _on_placement_confirmed(_grid_position: Vector2i, card: CardView) -> void:
	stats.tiles_placed += 1
	var definition := card.tile_definition if card != null else null
	var tile_name := str(definition.resource_path if definition != null else "")
	if tile_name.find("dead_end") >= 0:
		stats.dead_ends_placed += 1
		stats.roads_to_nowhere += 1
	elif card != null and card.encounter_data.is_empty():
		stats.roads_to_nowhere += int(stats.tiles_placed % 3 == 0)


func _on_tile_rotated(_grid_position: Vector2i, _card: CardView) -> void:
	stats.corners_rotated += 1


func _on_card_consumed(card_data: Dictionary) -> void:
	stats.cards_played += 1
	if str(card_data.get("category", "")) == GameConstants.ROAD_CATEGORY:
		stats.road_cards_played += 1
	else:
		stats.event_cards_played += 1
	var event_type := str(card_data.get("event_type", ""))
	if event_type == GameConstants.EVENT_DRAW_TWO:
		stats.number_of_bad_ideas += 1
	elif event_type == GameConstants.EVENT_LUCKY_FIND:
		stats.suspiciously_lucky_finds += 1


func _on_cards_drawn(count: int) -> void:
	stats.cards_drawn += count


func _on_combat_started(_position: Vector2i, _enemy_data: Dictionary) -> void:
	stats.combats_started += 1


func _on_combat_won(_position: Vector2i, _enemy_data: Dictionary) -> void:
	stats.combats_won += 1
	stats.enemies_defeated += 1


func _on_combat_retreat(_position: Vector2i, _enemy_data: Dictionary) -> void:
	stats.combats_retreats += 1


func _on_reward_collected(kind: String, entry: Dictionary) -> void:
	match kind:
		"berry":
			stats.berries_found += 1
			if _player != null and _player.food <= 2:
				stats.times_saved_by_berries += 1
		"cache":
			stats.caches_opened += 1
		"graveyard":
			stats.graves_not_visited = 0


func _on_item_added(item: Dictionary) -> void:
	stats.items_found += 1
	_update_best_item(item)


func _update_best_item(item: Dictionary) -> void:
	var power := ItemCatalog.get_stat(item, ItemCatalog.STAT_POWER)
	if power > stats.best_weapon_power:
		stats.best_weapon_power = power
		stats.best_weapon_name = str(item.get("name", "Unknown Tool"))


func _update_item_stats(inventory: InventoryUI) -> void:
	for item in inventory.get_carried_items():
		_update_best_item(item)
	if _player != null:
		stats.max_player_power_reached = maxi(stats.max_player_power_reached, _player.get_total_power())


func _note_position(position: Vector2i) -> void:
	_visited_positions[position] = true
	_level_positions[position] = true
