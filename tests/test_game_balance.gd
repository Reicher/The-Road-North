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
	_assert(GameBalance.BASE_POWER == 0, "Expected run base power to start at zero before item bonuses")
	_assert(GameBalance.STARTING_FOOD == 10, "Expected run starting food to be ten")


func _test_deck_formulas() -> void:
	var counts := GameBalance.deck_counts(1, 5)
	_assert(int(counts["map_area"]) == 25, "Expected map area to use authored map size")
	_assert(int(counts["shortest_path_steps"]) == 4, "Expected shortest path steps to be map size minus one")
	_assert(int(counts["total_cards"]) == 18, "Expected level one to use the authored base deck size")
	_assert(GameBalance.deck_component_counts(1, 5) == {"base": 18, "level": 0, "player_special": 0}, "Expected level one to use only the base deck")

	var level_two := GameBalance.deck_counts(2, 7)
	_assert(int(level_two["total_cards"]) == 30, "Expected Level 2 total size to follow the authored deck recipes")
	_assert(GameBalance.deck_component_counts(2, 7) == {"base": 18, "level": 12, "player_special": 0}, "Expected level two to add its twelve-card authored pack")
	var level_three := GameBalance.deck_counts(3, 9)
	_assert(int(level_three["total_cards"]) == 32, "Expected Level 3 total size to follow the authored deck recipes")
	_assert(GameBalance.deck_component_counts(3, 9) == {"base": 18, "level": 14, "player_special": 0}, "Expected level three to add its fourteen-card authored pack")


func _test_level_and_map_size_are_independent_inputs() -> void:
	var level_two := GameBalance.deck_counts(2, 7)
	var level_three := GameBalance.deck_counts(3, 7)
	_assert(int(level_two["total_cards"]) == 30 and int(level_three["total_cards"]) == 32, "Expected authored levels to use their resource-defined deck sizes")
	_assert(int(level_three["special_roads"]["enemy"]) == int(level_two["special_roads"]["enemy"]) + 1, "Expected the higher level on the same map size to add an enemy road")
	_assert(GameBalance.enemy_power_range(2) == Vector2i(2, 4), "Expected level two enemy range")
	_assert(GameBalance.enemy_power_range(3) == Vector2i(3, 5), "Expected level three enemy range")


func _test_reward_formulas() -> void:
	_assert(GameBalance.berry_food(5) == 3 and GameBalance.berry_food(9) == 5, "Expected berry food to scale from map size")
	var enemy_rewards := GameBalance.enemy_rewards(2)
	_assert(int(enemy_rewards["gold_min"]) == 4 and int(enemy_rewards["gold_max"]) == 8, "Expected level two enemy gold rewards")
func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
