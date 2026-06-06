extends SceneTree

const GameBalance = preload("res://scripts/game_balance.gd")


func _initialize() -> void:
	_test_starting_values()
	_test_deck_formulas()
	_test_level_and_map_size_are_independent_inputs()
	_test_reward_formulas()
	_test_shop_formulas()
	quit()


func _test_starting_values() -> void:
	_assert(GameBalance.STARTING_HEALTH == 4, "Expected run starting health to be four")
	_assert(GameBalance.BASE_POWER == 1, "Expected run base power to be one")
	_assert(GameBalance.STARTING_FOOD == 10, "Expected run starting food to be ten")


func _test_deck_formulas() -> void:
	var counts := GameBalance.deck_counts(1, 5)
	_assert(int(counts["map_area"]) == 25, "Expected map area to use authored map size")
	_assert(int(counts["shortest_path_steps"]) == 4, "Expected shortest path steps to be map size minus one")
	_assert(int(counts["total_cards"]) == 18, "Expected level one 5x5 deck formula")
	_assert(int(counts["road_cards"]) == 14 and int(counts["event_cards"]) == 4, "Expected 75 percent road cards and remaining event cards")
	_assert(counts["road_distribution"] == {"straight": 4, "corner": 4, "t_junction": 3, "four_way": 1, "dead_end": 2}, "Expected road subtype formulas with dead ends receiving the remainder")
	_assert(counts["special_roads"] == {"enemy": 3, "loot": 2, "berry": 2}, "Expected 5x5 level one encounter counts")


func _test_level_and_map_size_are_independent_inputs() -> void:
	var level_two := GameBalance.deck_counts(2, 7)
	var level_three := GameBalance.deck_counts(3, 7)
	_assert(int(level_two["total_cards"]) == int(level_three["total_cards"]), "Expected equal authored map sizes to use the same base deck size before a difficulty penalty applies")
	_assert(int(level_three["special_roads"]["enemy"]) == int(level_two["special_roads"]["enemy"]) + 1, "Expected the higher level on the same map size to add an enemy road")
	_assert(GameBalance.enemy_power_range(2) == Vector2i(4, 6), "Expected level two enemy range")
	_assert(GameBalance.enemy_power_range(3) == Vector2i(7, 9), "Expected level three enemy range")


func _test_reward_formulas() -> void:
	_assert(GameBalance.berry_food(5) == 3 and GameBalance.berry_food(9) == 5, "Expected berry food to scale from map size")
	var loot_rewards := GameBalance.loot_road_rewards(2)
	_assert(int(loot_rewards["gold_min"]) == 3 and int(loot_rewards["gold_max"]) == 6 and is_equal_approx(float(loot_rewards["item_chance"]), 0.30), "Expected level two loot road rewards")
	var enemy_rewards := GameBalance.enemy_rewards(2)
	_assert(int(enemy_rewards["gold_min"]) == 4 and int(enemy_rewards["gold_max"]) == 8 and is_equal_approx(float(enemy_rewards["item_chance"]), 0.40), "Expected level two enemy rewards")


func _test_shop_formulas() -> void:
	var shop := GameBalance.shop_values(3)
	_assert(int(shop["small_food_amount"]) == 5 and int(shop["small_food_price"]) == 5, "Expected small food shop values")
	_assert(int(shop["big_food_amount"]) == 10 and int(shop["big_food_price"]) == 8, "Expected big food shop values")
	_assert(int(shop["heal_1_price"]) == 7 and int(shop["random_item_price"]) == 7, "Expected healing and random item prices")
	_assert(int(shop["low_power_bonus"]) == 3 and int(shop["low_power_item_price"]) == 10, "Expected low power item values")
	_assert(int(shop["high_power_bonus"]) == 4 and int(shop["high_power_item_price"]) == 14, "Expected high power item values")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
