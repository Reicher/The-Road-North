class_name GameBalance
extends RefCounted

const STARTING_HEALTH := 4
const BASE_POWER := 1
const STARTING_FOOD := 10


static func deck_counts(level: int, map_size: int) -> Dictionary:
	var safe_level := maxi(1, level)
	var safe_map_size := maxi(1, map_size)
	var shortest_path_steps := safe_map_size - 1
	var base_total_cards := roundi(float(safe_map_size) * 3.5 + 0.5)
	var difficulty_card_penalty := floori(float(safe_level - 1) / 3.0)
	var total_cards := maxi(shortest_path_steps * 3, base_total_cards - difficulty_card_penalty)
	var road_cards := roundi(float(total_cards) * 0.75)
	var event_cards := total_cards - road_cards

	return {
		"map_area": safe_map_size * safe_map_size,
		"shortest_path_steps": shortest_path_steps,
		"base_total_cards": base_total_cards,
		"difficulty_card_penalty": difficulty_card_penalty,
		"total_cards": total_cards,
		"road_cards": road_cards,
		"event_cards": event_cards,
		"road_distribution": road_distribution(road_cards),
		"special_roads": special_road_counts(safe_level, safe_map_size, road_cards),
	}


static func road_distribution(road_cards: int) -> Dictionary:
	var t_junction := roundi(float(road_cards) * 0.20)
	var four_way := roundi(float(road_cards) * 0.15)
	var dead_end := roundi(float(road_cards) * 0.20)
	var simple_roads := maxi(0, road_cards - t_junction - four_way - dead_end)
	var straight := ceili(float(simple_roads) / 2.0)
	var corner := simple_roads - straight
	return {
		"straight": straight,
		"corner": corner,
		"t_junction": t_junction,
		"four_way": four_way,
		"dead_end": dead_end,
	}


static func special_road_counts(level: int, map_size: int, road_cards: int) -> Dictionary:
	var enemy_roads := roundi(float(map_size) * 0.60) + level
	var loot_roads := maxi(2, floori(float(map_size + 1) / 2.0) - 1)
	var berry_roads := maxi(2, floori(float(map_size + 1) / 2.0) - 1)
	var remaining := maxi(0, road_cards)

	enemy_roads = mini(enemy_roads, remaining)
	remaining -= enemy_roads
	loot_roads = mini(loot_roads, remaining)
	remaining -= loot_roads
	berry_roads = mini(berry_roads, remaining)
	return {
		"enemy": enemy_roads,
		"loot": loot_roads,
		"berry": berry_roads,
	}


static func enemy_power_range(level: int) -> Vector2i:
	var safe_level := maxi(1, level)
	return Vector2i((safe_level - 1) * 3 + 1, safe_level * 3)


static func berry_food(map_size: int) -> int:
	return clampi(roundi(float(map_size) / 2.0), 3, 6)


static func enemy_rewards(level: int) -> Dictionary:
	var safe_level := maxi(1, level)
	return {
		"gold_min": safe_level * 2,
		"gold_max": safe_level * 3 + 2,
	}
