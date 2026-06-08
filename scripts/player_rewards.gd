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


func open_enemy_loot(enemy_data: Dictionary) -> void:
	if _loot_ui == null:
		return
	var loot := _make_enemy_loot(enemy_data)
	if not loot.is_empty():
		_loot_ui.open_loot(loot)


func collect_loot(loot: Array) -> void:
	if loot.is_empty():
		return
	if _loot_ui != null:
		_loot_ui.open_loot(loot)
		return
	for entry in loot:
		if entry is Dictionary:
			_collect_loot_entry(entry)


func collect_reward_at(target_position: Vector2i) -> bool:
	if _map == null:
		return false
	var encounter := _map.get_encounter(target_position)
	if encounter.is_empty() or str(encounter.get("type", "")) == GameMap.ENCOUNTER_ENEMY:
		return false
	encounter = _map.consume_encounter(target_position)
	var loot: Array = encounter.get("loot", [])
	collect_loot(loot)
	return true


func _collect_loot_entry(entry: Dictionary) -> void:
	if _player == null:
		return
	var kind := str(entry.get("kind", "item"))
	if kind == "food":
		_player.add_food(int(entry.get("amount", 0)))
	elif kind == "gold":
		_player.add_gold(int(entry.get("amount", 0)))
	elif kind == "item" and _inventory != null:
		_inventory.add_item(entry.get("item", {}).duplicate(true))


func _make_enemy_loot(enemy_data: Dictionary) -> Array[Dictionary]:
	var enemy_power := maxi(1, int(enemy_data.get("power", 1)))
	var default_level := floori(float(enemy_power - 1) / 3.0) + 1
	var level_rewards := GameBalance.enemy_rewards(default_level)
	return [{
		"kind": "gold",
		"amount": _loot_rng.randi_range(int(enemy_data.get("gold_min", level_rewards["gold_min"])), int(enemy_data.get("gold_max", level_rewards["gold_max"]))),
	}]
