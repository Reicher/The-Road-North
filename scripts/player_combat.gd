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


func get_damage_from(enemy_data: Dictionary) -> int:
	return maxi(0, int(enemy_data.get("attack", 0)) - _player.get_total_armor())
