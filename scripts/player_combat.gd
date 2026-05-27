extends Node

var _player: GamePlayer
var _map: GameMap


func setup(player: GamePlayer, map: GameMap) -> void:
	_player = player
	_map = map


func can_defeat_enemy_at(target_position: Vector2i) -> bool:
	var enemy_data := get_enemy_data(target_position)
	if enemy_data.is_empty():
		return true
	if int(enemy_data.get("health", 0)) <= 0:
		return true
	return _player.get_total_attack() > int(enemy_data.get("armor", 0))


func is_blocked_by_enemy_armor(from_position: Vector2i, target_position: Vector2i) -> bool:
	return _map != null and _map.can_move_between(from_position, target_position) and not can_defeat_enemy_at(target_position)


func get_enemy_data(target_position: Vector2i) -> Dictionary:
	if _map == null:
		return {}
	var tile_data: Variant = _map.get_tile(target_position)
	if not (tile_data is Dictionary):
		return {}
	return tile_data.get("enemy", {})


func get_damage_from(enemy_data: Dictionary) -> int:
	return maxi(0, int(enemy_data.get("attack", 0)) - _player.get_total_armor())
