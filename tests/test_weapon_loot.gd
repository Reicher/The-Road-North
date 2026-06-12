extends SceneTree

const PLAYER_REWARDS_SCRIPT := preload("res://scripts/player_rewards.gd")
const DECK_BUILDER_SCRIPT := preload("res://scripts/deck_builder.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const ItemCatalog := preload("res://scripts/item_catalog.gd")
const ItemIconLibrary := preload("res://scripts/item_icon_library.gd")

const SAMPLE_COUNT := 20000


func _initialize() -> void:
	_test_weapon_catalog()
	_test_enemy_power_ranges()
	_test_enemy_loot_is_only_gold()
	_test_cache_loot_distribution()
	_test_cache_weapon_tiers()
	_test_cache_loot_uses_available_weighted_powers()
	_test_cache_loot_falls_back_when_all_weighted_powers_are_missing()
	quit()


func _test_weapon_catalog() -> void:
	var expected_names := ["Walking Stick", "Dagger", "Hatchet", "Machete", "Sword", "Mace", "Spear", "Sword & Shield", "Great Axe"]
	for power_bonus in range(1, 10):
		var weapon := WeaponCatalog.make_weapon(power_bonus)
		_assert(weapon.get("name", "") == expected_names[power_bonus - 1], "Expected every requested weapon to exist")
		_assert(int(weapon.get("power_bonus", 0)) == power_bonus, "Expected weapons to expose power_bonus directly")
		_assert(weapon.get("effect", "") == "+%d Power" % power_bonus, "Expected weapon effect text to match power_bonus")
		_assert(ItemIconLibrary.get_icon(weapon) != null, "Expected every weapon to have an item icon")


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


func _test_enemy_loot_is_only_gold() -> void:
	for enemy_rank in range(3):
		var rewards = PLAYER_REWARDS_SCRIPT.new()
		rewards.set_loot_seed(20000 + enemy_rank)
		var enemy_power := enemy_rank + 1
		for _index in SAMPLE_COUNT:
			var loot: Array = rewards._make_enemy_loot({
				"power": enemy_power,
				"enemy_min_power": 1,
			})
			_assert(loot.size() == 1 and loot[0].get("kind", "") == "gold", "Expected enemies to drop exactly one gold entry")
			var gold_amount := _gold_amount(loot)
			_assert(gold_amount >= 2 and gold_amount <= 5, "Expected level one enemy gold range")
		rewards.free()


func _test_cache_loot_distribution() -> void:
	var builder = DECK_BUILDER_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 56789
	var counts := {2: 0, 3: 0, 4: 0}
	var weapon_count := 0
	var binoculars_count := 0
	for _index in SAMPLE_COUNT:
		var encounter: Dictionary = builder._make_reward_encounter(1, rng, 1)
		var loot: Array = encounter["loot"]
		_assert(loot.size() == 1 and loot[0].get("kind", "") == "item", "Expected caches to drop exactly one item")
		var item := _weapon_from_loot(loot)
		if not item.is_empty():
			weapon_count += 1
			counts[int(item["power_bonus"])] += 1
		if not _binoculars_from_loot(loot).is_empty():
			binoculars_count += 1
	_assert(weapon_count + binoculars_count == SAMPLE_COUNT, "Expected every cache item to be a weapon or Binoculars")
	_assert(_conditional_ratio_is_close(counts[2], weapon_count, 0.55), "Expected level one cache Dagger chance to be 55 percent when a weapon drops")
	_assert(_conditional_ratio_is_close(counts[3], weapon_count, 0.30), "Expected level one cache Hatchet chance to be 30 percent when a weapon drops")
	_assert(_conditional_ratio_is_close(counts[4], weapon_count, 0.15), "Expected level one cache Machete chance to be 15 percent when a weapon drops")
	_assert(_ratio_is_close(binoculars_count, ItemCatalog.BINOCULARS_DROP_CHANCE), "Expected caches on every level to have a 15 percent Binoculars chance")
	builder.free()


func _test_cache_weapon_tiers() -> void:
	var builder = DECK_BUILDER_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6122026
	for level in range(1, 4):
		var expected_min := 2 if level == 1 else level * 3 - 1
		var expected_max := mini(level * 3 + 1, 9)
		var seen_powers := {}
		for _index in SAMPLE_COUNT:
			var item := _weapon_from_loot(builder._make_reward_encounter(1, rng, level)["loot"])
			if item.is_empty():
				continue
			var power_bonus := int(item["power_bonus"])
			_assert(power_bonus >= expected_min and power_bonus <= expected_max, "Expected cache weapon power to stay in its level tier")
			seen_powers[power_bonus] = true
		_assert(seen_powers.size() == expected_max - expected_min + 1, "Expected every cache weapon in the level tier to be obtainable")
	builder.free()


func _test_cache_loot_uses_available_weighted_powers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 67890
	var counts := {8: 0, 9: 0}
	for _index in SAMPLE_COUNT:
		var weapon := WeaponCatalog.roll_weapon(rng, 8, {0: 0.55, 1: 0.30, 2: 0.15})
		counts[int(weapon["power_bonus"])] += 1
	_assert(_ratio_is_close(counts[8], 0.55 / 0.85), "Expected missing cache weapon powers to be ignored and weights normalized")
	_assert(_ratio_is_close(counts[9], 0.30 / 0.85), "Expected cache weights to normalize across existing weapons")


func _test_cache_loot_falls_back_when_all_weighted_powers_are_missing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 78901
	var weapon := WeaponCatalog.roll_weapon(rng, 10, {0: 0.55, 1: 0.30, 2: 0.15})
	_assert(weapon.get("name", "") == "Great Axe", "Expected high-level caches to still give the strongest existing weapon")


func _gold_amount(loot: Array) -> int:
	for entry in loot:
		if entry is Dictionary and entry.get("kind", "") == "gold":
			return int(entry.get("amount", 0))
	return 0


func _weapon_from_loot(loot: Array) -> Dictionary:
	for entry in loot:
		if entry is Dictionary and entry.get("kind", "") == "item" and int(entry.get("item", {}).get("power_bonus", 0)) > 0:
			return entry.get("item", {})
	return {}


func _binoculars_from_loot(loot: Array) -> Dictionary:
	for entry in loot:
		if entry is Dictionary and entry.get("kind", "") == "item" and entry.get("item", {}).get("name", "") == "Binoculars":
			return entry.get("item", {})
	return {}


func _ratio_is_close(count: int, expected: float) -> bool:
	return absf(float(count) / float(SAMPLE_COUNT) - expected) < 0.02


func _conditional_ratio_is_close(count: int, total: int, expected: float) -> bool:
	return total > 0 and absf(float(count) / float(total) - expected) < 0.03


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
