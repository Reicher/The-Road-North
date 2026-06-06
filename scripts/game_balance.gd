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
	var straight := roundi(float(road_cards) * 0.30)
	var corner := roundi(float(road_cards) * 0.30)
	var t_junction := roundi(float(road_cards) * 0.20)
	var four_way := roundi(float(road_cards) * 0.10)
	return {
		"straight": straight,
		"corner": corner,
		"t_junction": t_junction,
		"four_way": four_way,
		"dead_end": road_cards - straight - corner - t_junction - four_way,
	}


static func special_road_counts(level: int, map_size: int, road_cards: int) -> Dictionary:
	var enemy_roads := roundi(float(map_size) * 0.45) + level
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


static func loot_road_rewards(level: int) -> Dictionary:
	var safe_level := maxi(1, level)
	return {
		"gold_min": safe_level + 1,
		"gold_max": safe_level * 2 + 2,
		"item_chance": minf(0.20 + float(safe_level) * 0.05, 0.45),
	}


static func enemy_rewards(level: int) -> Dictionary:
	var safe_level := maxi(1, level)
	return {
		"gold_min": safe_level * 2,
		"gold_max": safe_level * 3 + 2,
		"item_chance": minf(0.30 + float(safe_level) * 0.05, 0.55),
	}


static func shop_values(shop_level: int) -> Dictionary:
	var safe_level := maxi(1, shop_level)
	var small_food_amount := 2 + safe_level
	var big_food_amount := small_food_amount * 2
	var low_power_bonus := safe_level
	var high_power_bonus := safe_level + 1
	return {
		"small_food_amount": small_food_amount,
		"small_food_price": 2 + safe_level,
		"big_food_amount": big_food_amount,
		"big_food_price": roundi(float(big_food_amount) * 0.8),
		"heal_1_price": 4 + safe_level,
		"low_power_bonus": low_power_bonus,
		"low_power_item_price": power_item_price(low_power_bonus),
		"high_power_bonus": high_power_bonus,
		"high_power_item_price": power_item_price(high_power_bonus),
		"random_item_price": 4 + safe_level,
	}


static func power_item_price(bonus: int) -> int:
	return bonus * 3 + maxi(0, bonus - 2)
