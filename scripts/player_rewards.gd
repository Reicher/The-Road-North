class_name PlayerRewards
extends Node

var _player: GamePlayer
var _inventory: InventoryUI
var _loot_ui: Node
var _loot_rng := RandomNumberGenerator.new()


func setup(player: GamePlayer, inventory: InventoryUI, loot_ui: Node) -> void:
	_player = player
	_inventory = inventory
	_loot_ui = loot_ui
	_loot_rng.randomize()


func get_attack_bonus() -> int:
	if _inventory == null:
		return 0
	return _inventory.get_attack_bonus()


func get_armor_bonus() -> int:
	if _inventory == null:
		return 0
	return _inventory.get_armor_bonus()


func open_enemy_loot(enemy_data: Dictionary) -> void:
	if _loot_ui == null:
		return
	var loot := _make_enemy_loot(enemy_data)
	if not loot.is_empty():
		_loot_ui.call("open_loot", loot)


func collect_landmark_loot(loot: Array) -> void:
	if loot.is_empty():
		return
	if _loot_ui != null:
		_loot_ui.call("open_loot", loot)
		return
	for entry in loot:
		if entry is Dictionary:
			_collect_landmark_loot_entry(entry)


func _collect_landmark_loot_entry(entry: Dictionary) -> void:
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
	var value := _loot_rng.randi_range(1, 5)
	var enemy_attack := int(enemy_data.get("attack", 0))
	var enemy_armor := int(enemy_data.get("armor", 0))
	if enemy_attack >= enemy_armor:
		return {
			"name": "Sword",
			"effect": "+%d Attack" % value,
			"attack": value,
			"armor": 0,
		}
	return {
		"name": "Armor",
		"effect": "+%d Armor" % value,
		"attack": 0,
		"armor": value,
	}
