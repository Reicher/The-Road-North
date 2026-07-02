class_name PlayerRewards
extends Node

const GameBalance = preload("res://scripts/game_balance.gd")

var _player: GamePlayer
var _inventory: InventoryUI
var _loot_ui: LootUI
var _map: GameMap
var _loot_rng := RandomNumberGenerator.new()


func setup(player: GamePlayer, inventory: InventoryUI, loot_ui: LootUI, map: GameMap = null) -> void:
	_player = player
	_inventory = inventory
	_loot_ui = loot_ui
	_map = map
	_loot_rng.randomize()


func get_power_bonus() -> int:
	if _inventory == null:
		return 0
	return _inventory.get_power_bonus()


func set_loot_seed(seed: int) -> void:
	_loot_rng.seed = seed


func open_enemy_loot(enemy_data: Dictionary) -> int:
	if _loot_ui == null:
		return 0
	var loot := _make_enemy_loot(enemy_data)
	var gold_before := _player.gold if _player != null else 0
	if not loot.is_empty():
		_loot_ui.open_loot(loot)
	return (_player.gold - gold_before) if _player != null else 0


func collect_loot(loot: Array) -> void:
	if loot.is_empty():
		return
	if _loot_ui != null:
		_loot_ui.open_loot(loot)
		return
	for entry in loot:
		if entry is Dictionary:
			collect_entry(entry)


func collect_reward_at(target_position: Vector2i) -> bool:
	if _map == null:
		return false
	var encounter := _map.get_encounter(target_position)
	if encounter.is_empty() or str(encounter.get("type", "")) == GameMap.ENCOUNTER_ENEMY:
		return false
	if str(encounter.get("type", "")) in GameConstants.REUSABLE_ENCOUNTER_TYPES:
		return false
	var consumed := _map.consume_encounter(target_position)
	var loot: Array = consumed.get("loot", [])
	collect_loot(loot)
	return true


func collect_entry(entry: Dictionary) -> bool:
	if _player == null:
		return false
	var kind := str(entry.get("kind", "item"))
	if kind == "food":
		_player.add_food(int(entry.get("amount", 0)))
		return true
	if kind == "gold":
		_player.add_gold(int(entry.get("amount", 0)))
		return true
	if kind == "item" and _inventory != null:
		return _inventory.add_item(entry.get("item", {}).duplicate(true))
	return false


func _make_enemy_loot(enemy_data: Dictionary) -> Array[Dictionary]:
	var enemy_power := maxi(1, int(enemy_data.get("power", 1)))
	var default_level := maxi(1, int(enemy_data.get("enemy_min_power", enemy_power)))
	var level_rewards := GameBalance.enemy_rewards(default_level)
	return [{
		"kind": "gold",
		"amount": _loot_rng.randi_range(int(enemy_data.get("gold_min", level_rewards["gold_min"])), int(enemy_data.get("gold_max", level_rewards["gold_max"]))),
	}]
