class_name PlayerRewards
extends Node

var _player: GamePlayer
var _inventory: InventoryUI
var _loot_ui: Node
var _map: GameMap
var _loot_rng := RandomNumberGenerator.new()


func setup(player: GamePlayer, inventory: InventoryUI, loot_ui: Node, map: GameMap = null) -> void:
	_player = player
	_inventory = inventory
	_loot_ui = loot_ui
	_map = map
	_loot_rng.randomize()


func get_power_bonus() -> int:
	if _inventory == null:
		return 0
	return _inventory.get_power_bonus()


func open_enemy_loot(enemy_data: Dictionary) -> void:
	if _loot_ui == null:
		return
	var loot := _make_enemy_loot(enemy_data)
	if not loot.is_empty():
		_loot_ui.call("open_loot", loot)


func collect_loot(loot: Array) -> void:
	if loot.is_empty():
		return
	if _loot_ui != null:
		_loot_ui.call("open_loot", loot)
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
	var loot: Array[Dictionary] = []
	loot.append({
		"kind": "food",
		"amount": 1,
	})
	loot.append({
		"kind": "gold",
		"amount": 1,
	})
	loot.append({
		"kind": "item",
		"item": _make_enemy_item(enemy_data),
	})
	return loot


func _make_enemy_item(enemy_data: Dictionary) -> Dictionary:
	var enemy_power := int(enemy_data.get("power", 1))
	var value: int = clampi(enemy_power, 1, 4)
	var names := {
		1: "Knife",
		2: "Machete",
		3: "Sword",
		4: "Katana",
	}
	return {
		"name": str(names[value]),
		"effect": "+%d Power" % value,
		"power": value,
	}
