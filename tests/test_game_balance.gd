extends SceneTree

const GameBalance = preload("res://scripts/game_balance.gd")


func _initialize() -> void:
	_test_starting_values()
	_test_deck_formulas()
	_test_level_and_map_size_are_independent_inputs()
	_test_reward_formulas()
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
	_assert(counts["road_distribution"] == {"straight": 3, "corner": 3, "t_junction": 3, "four_way": 2, "dead_end": 3}, "Expected road subtype formulas to include more four-way intersections and dead ends")
	_assert(counts["special_roads"] == {"enemy": 4, "loot": 2, "berry": 2}, "Expected 5x5 level one encounter counts")
	_assert(GameBalance.deck_component_counts(1, 5) == {"base": 18, "level": 0, "player_special": 0}, "Expected level one to use only the base deck")

	var level_two := GameBalance.deck_counts(2, 7)
	_assert(level_two["road_distribution"] == {"straight": 4, "corner": 4, "t_junction": 4, "four_way": 3, "dead_end": 4}, "Expected level two road subtype distribution")
	_assert(level_two["special_roads"] == {"enemy": 6, "loot": 3, "berry": 3}, "Expected 7x7 level two encounter counts")
	_assert(GameBalance.deck_component_counts(2, 7) == {"base": 18, "level": 7, "player_special": 0}, "Expected level two to add seven level cards to the base deck")


func _test_level_and_map_size_are_independent_inputs() -> void:
	var level_two := GameBalance.deck_counts(2, 7)
	var level_three := GameBalance.deck_counts(3, 7)
	_assert(int(level_two["total_cards"]) == int(level_three["total_cards"]), "Expected equal authored map sizes to use the same base deck size before a difficulty penalty applies")
	_assert(int(level_three["special_roads"]["enemy"]) == int(level_two["special_roads"]["enemy"]) + 1, "Expected the higher level on the same map size to add an enemy road")
	_assert(GameBalance.enemy_power_range(2) == Vector2i(4, 6), "Expected level two enemy range")
	_assert(GameBalance.enemy_power_range(3) == Vector2i(7, 9), "Expected level three enemy range")


func _test_reward_formulas() -> void:
	_assert(GameBalance.berry_food(5) == 3 and GameBalance.berry_food(9) == 5, "Expected berry food to scale from map size")
	var enemy_rewards := GameBalance.enemy_rewards(2)
	_assert(int(enemy_rewards["gold_min"]) == 4 and int(enemy_rewards["gold_max"]) == 8, "Expected level two enemy gold rewards")
func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
