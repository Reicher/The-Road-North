extends SceneTree

const PLAYER_REWARDS_SCRIPT := preload("res://scripts/player_rewards.gd")
const DECK_BUILDER_SCRIPT := preload("res://scripts/deck_builder.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")

const SAMPLE_COUNT := 20000


func _initialize() -> void:
	_test_weapon_catalog()
	_test_enemy_power_ranges()
	_test_enemy_drop_chances_and_gold()
	_test_enemy_weapon_distribution()
	_test_enemy_loot_normalizes_missing_power()
	_test_cache_loot_distribution()
	_test_cache_loot_normalizes_missing_power()
	_test_cache_loot_falls_back_when_all_weighted_powers_are_missing()
	quit()


func _test_weapon_catalog() -> void:
	var expected_names := ["Knife", "Dagger", "Machete", "Sword", "Katana"]
	for power_bonus in range(1, 6):
		var weapon := WeaponCatalog.make_weapon(power_bonus)
		_assert(weapon.get("name", "") == expected_names[power_bonus - 1], "Expected every requested weapon to exist")
		_assert(int(weapon.get("power_bonus", 0)) == power_bonus, "Expected weapons to expose power_bonus directly")
		_assert(weapon.get("effect", "") == "+%d Power" % power_bonus, "Expected weapon effect text to match power_bonus")


func _test_enemy_power_ranges() -> void:
	var builder = DECK_BUILDER_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for level in range(1, 4):
		var enemy_min_power := level * 3 - 2
		var enemy_max_power := level * 3
		var seen_powers := {}
		for _index in 100:
			var enemy: Dictionary = builder._make_enemy_encounter(rng, level)
			var enemy_power := int(enemy["power"])
			_assert(enemy_power >= enemy_min_power and enemy_power <= enemy_max_power, "Expected enemy power to stay within its level range")
			_assert(int(enemy["enemy_min_power"]) == enemy_min_power, "Expected enemy encounter to store its level minimum power")
			seen_powers[enemy_power] = true
		_assert(seen_powers.size() == 3, "Expected every level to generate all three enemy power values")
	builder.free()


func _test_enemy_drop_chances_and_gold() -> void:
	for enemy_rank in range(3):
		var rewards = PLAYER_REWARDS_SCRIPT.new()
		rewards.set_loot_seed(20000 + enemy_rank)
		var drop_count := 0
		var enemy_power := enemy_rank + 1
		for _index in SAMPLE_COUNT:
			var loot: Array = rewards._make_enemy_loot({
				"power": enemy_power,
				"enemy_min_power": 1,
			})
			var gold_amount := _gold_amount(loot)
			_assert(gold_amount >= 2 and gold_amount <= 5, "Expected level one enemy gold range")
			if not _item_from_loot(loot).is_empty():
				drop_count += 1
		_assert(_ratio_is_close(drop_count, 0.35), "Expected enemy item chance to scale from level")
		rewards.free()


func _test_enemy_weapon_distribution() -> void:
	var rewards = PLAYER_REWARDS_SCRIPT.new()
	rewards.set_loot_seed(34567)
	var counts := {2: 0, 3: 0, 4: 0}
	for _index in SAMPLE_COUNT:
		var weapon: Dictionary = rewards._make_enemy_item({"power": 3})
		counts[int(weapon["power_bonus"])] += 1
	_assert(_ratio_is_close(counts[2], 0.30), "Expected enemy weapon target minus one chance to be 30 percent")
	_assert(_ratio_is_close(counts[3], 0.50), "Expected enemy weapon target chance to be 50 percent")
	_assert(_ratio_is_close(counts[4], 0.20), "Expected enemy weapon target plus one chance to be 20 percent")
	rewards.free()


func _test_enemy_loot_normalizes_missing_power() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 45678
	var counts := {4: 0, 5: 0}
	for _index in SAMPLE_COUNT:
		var weapon := WeaponCatalog.roll_weapon(rng, 5, {-1: 0.30, 0: 0.50, 1: 0.20})
		counts[int(weapon["power_bonus"])] += 1
	_assert(_ratio_is_close(counts[4], 0.30 / 0.80), "Expected missing enemy weapon powers to be ignored and weights normalized")
	_assert(_ratio_is_close(counts[5], 0.50 / 0.80), "Expected existing enemy weapon weights to retain their relative proportions")


func _test_cache_loot_distribution() -> void:
	var builder = DECK_BUILDER_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 56789
	var counts := {2: 0, 3: 0, 4: 0}
	var item_count := 0
	for _index in SAMPLE_COUNT:
		var encounter: Dictionary = builder._make_reward_encounter(1, rng, 1)
		var loot: Array = encounter["loot"]
		var gold_amount := _gold_amount(loot)
		_assert(gold_amount >= 2 and gold_amount <= 4, "Expected level one cache gold range")
		var item := _item_from_loot(loot)
		if not item.is_empty():
			item_count += 1
			counts[int(item["power_bonus"])] += 1
	_assert(_ratio_is_close(item_count, 0.25), "Expected level one cache item chance")
	_assert(_conditional_ratio_is_close(counts[2], item_count, 0.55), "Expected level one cache Dagger chance to be 55 percent when an item drops")
	_assert(_conditional_ratio_is_close(counts[3], item_count, 0.30), "Expected level one cache Machete chance to be 30 percent when an item drops")
	_assert(_conditional_ratio_is_close(counts[4], item_count, 0.15), "Expected level one cache Sword chance to be 15 percent when an item drops")
	builder.free()


func _test_cache_loot_normalizes_missing_power() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 67890
	var counts := {4: 0, 5: 0}
	for _index in SAMPLE_COUNT:
		var weapon := WeaponCatalog.roll_weapon(rng, 4, {0: 0.55, 1: 0.30, 2: 0.15})
		counts[int(weapon["power_bonus"])] += 1
	_assert(_ratio_is_close(counts[4], 0.55 / 0.85), "Expected missing cache weapon powers to be ignored and weights normalized")
	_assert(_ratio_is_close(counts[5], 0.30 / 0.85), "Expected cache weights to normalize across existing weapons")


func _test_cache_loot_falls_back_when_all_weighted_powers_are_missing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 78901
	var weapon := WeaponCatalog.roll_weapon(rng, 10, {0: 0.55, 1: 0.30, 2: 0.15})
	_assert(weapon.get("name", "") == "Katana", "Expected high-level caches to still give the strongest existing weapon")


func _gold_amount(loot: Array) -> int:
	for entry in loot:
		if entry is Dictionary and entry.get("kind", "") == "gold":
			return int(entry.get("amount", 0))
	return 0


func _item_from_loot(loot: Array) -> Dictionary:
	for entry in loot:
		if entry is Dictionary and entry.get("kind", "") == "item":
			return entry.get("item", {})
	return {}


func _item_count(loot: Array) -> int:
	return 0 if _item_from_loot(loot).is_empty() else 1


func _ratio_is_close(count: int, expected: float) -> bool:
	return absf(float(count) / float(SAMPLE_COUNT) - expected) < 0.02


func _conditional_ratio_is_close(count: int, total: int, expected: float) -> bool:
	return total > 0 and absf(float(count) / float(total) - expected) < 0.03


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
