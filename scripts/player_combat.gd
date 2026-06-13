class_name PlayerCombat
extends Node

var _player: GamePlayer
var _map: GameMap


func setup(player: GamePlayer, map: GameMap) -> void:
	_player = player
	_map = map


func get_enemy_data(target_position: Vector2i) -> Dictionary:
	if _map == null:
		return {}
	var tile_data: Variant = _map.get_tile(target_position)
	if not (tile_data is Dictionary):
		return {}
	var encounter: Dictionary = tile_data.get("encounter", {})
	if str(encounter.get("type", "")) != GameMap.ENCOUNTER_ENEMY:
		return {}
	return encounter


func get_risk_level(enemy_data: Dictionary) -> String:
	return _player.get_combat_risk_level(int(enemy_data.get("power", 0)))


func reveal_enemy_at(target_position: Vector2i, enemy_data: Dictionary) -> void:
	if _map == null:
		return
	enemy_data["revealed"] = true
	_map.update_encounter_data(target_position, enemy_data)


func clear_enemy_at(target_position: Vector2i) -> void:
	if _map != null:
		_map.clear_encounter(target_position)
