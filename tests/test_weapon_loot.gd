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
	_test_encounter_cards_scale_to_current_level()
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
		var enemy_min_power := level
		var enemy_max_power := level + 2
		var seen_powers := {}
		for _index in 100:
			var enemy: Dictionary = builder._make_enemy_encounter(rng, level)
			var enemy_power := int(enemy["power"])
			_assert(enemy_power >= enemy_min_power and enemy_power <= enemy_max_power, "Expected enemy power to stay within its level range")
			_assert(int(enemy["enemy_min_power"]) == enemy_min_power, "Expected enemy encounter to store its level minimum power")
			seen_powers[enemy_power] = true
		_assert(seen_powers.size() == 3, "Expected every level to generate all three enemy power values")
	builder.free()


func _test_encounter_cards_scale_to_current_level() -> void:
	var builder = DECK_BUILDER_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	var cards := [
		{
			"category": GameConstants.EVENT_CATEGORY,
			"event_type": GameConstants.EVENT_TROUBLE,
			"encounter": {"type": GameMap.ENCOUNTER_ENEMY, "power": 9},
		},
		{
			"category": GameConstants.EVENT_CATEGORY,
			"event_type": GameConstants.EVENT_LOST_BELONGINGS,
			"encounter": {"type": GameMap.ENCOUNTER_CACHE, "loot": [{"kind": "item", "item": WeaponCatalog.make_weapon(1)}]},
		},
	]
	builder.scale_encounters_to_level(cards, rng, 4)
	var enemy_encounter: Dictionary = cards[0]["encounter"]
	_assert(int(enemy_encounter["power"]) >= 4 and int(enemy_encounter["power"]) <= 6, "Expected enemy cards to use the current level's power range")
	_assert(int(enemy_encounter["enemy_min_power"]) == 4, "Expected scaled enemy cards to store the current level minimum power")
	var cache_weapon := _weapon_from_loot(cards[1]["encounter"]["loot"])
	_assert(cache_weapon.is_empty() or int(cache_weapon["power_bonus"]) >= 4, "Expected cache cards to use the current level's weapon range")
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
	var future_level_rewards = PLAYER_REWARDS_SCRIPT.new()
	future_level_rewards.set_loot_seed(30000)
	for _index in 100:
		var loot: Array = future_level_rewards._make_enemy_loot({
			"power": 6,
			"enemy_min_power": 4,
		})
		var gold_amount := _gold_amount(loot)
		_assert(gold_amount >= 8 and gold_amount <= 14, "Expected enemy reward fallback to use the encounter level rather than overlapping power")
	future_level_rewards.free()


func _test_cache_loot_distribution() -> void:
	var builder = DECK_BUILDER_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 56789
	var counts := {1: 0, 2: 0, 3: 0, 4: 0}
	var weapon_count := 0
	var utility_count := 0
	var utility_counts := {}
	for _index in SAMPLE_COUNT:
		var encounter: Dictionary = builder._make_reward_encounter(1, rng, 1)
		var loot: Array = encounter["loot"]
		_assert(loot.size() == 1 and loot[0].get("kind", "") == "item", "Expected caches to drop exactly one item")
		var item := _weapon_from_loot(loot)
		if not item.is_empty():
			weapon_count += 1
			counts[int(item["power_bonus"])] += 1
		var utility_item := _utility_item_from_loot(loot)
		if not utility_item.is_empty():
			utility_count += 1
			var utility_name := str(utility_item.get("name", ""))
			utility_counts[utility_name] = int(utility_counts.get(utility_name, 0)) + 1
	_assert(weapon_count + utility_count == SAMPLE_COUNT, "Expected every cache item to be a weapon or utility item")
	var normal_weapon_chance := (1.0 - DeckBuilder.CACHE_RARE_WEAPON_CHANCE) / 3.0
	_assert(_conditional_ratio_is_close(counts[1], weapon_count, normal_weapon_chance), "Expected level one cache Walking Stick chance to share the normal weapon range")
	_assert(_conditional_ratio_is_close(counts[2], weapon_count, normal_weapon_chance), "Expected level one cache Dagger chance to share the normal weapon range")
	_assert(_conditional_ratio_is_close(counts[3], weapon_count, normal_weapon_chance), "Expected level one cache Hatchet chance to share the normal weapon range")
	_assert(_conditional_ratio_is_close(counts[4], weapon_count, DeckBuilder.CACHE_RARE_WEAPON_CHANCE), "Expected level one cache Machete chance to be the rare 15 percent drop")
	_assert(_ratio_is_close(utility_count, ItemCatalog.UTILITY_ITEM_DROP_CHANCE), "Expected caches on every level to have a total 15 percent utility item chance")
	for utility_item in ItemCatalog.UTILITY_ITEMS:
		var utility_name := str(utility_item["name"])
		_assert(_conditional_ratio_is_close(int(utility_counts.get(utility_name, 0)), utility_count, 1.0 / ItemCatalog.UTILITY_ITEMS.size()), "Expected utility cache drops to be evenly distributed")
		_assert(ItemIconLibrary.get_icon(utility_item) != null, "Expected every utility item to have an icon")
	builder.free()


func _test_cache_weapon_tiers() -> void:
	var builder = DECK_BUILDER_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6122026
	for level in range(1, 4):
		var expected_min := level
		var expected_max := mini(level + 3, 9)
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


func _utility_item_from_loot(loot: Array) -> Dictionary:
	for entry in loot:
		if entry is Dictionary and entry.get("kind", "") == "item":
			var item: Dictionary = entry.get("item", {})
			if int(item.get("target_range_bonus", 0)) > 0 \
					or int(item.get("gold_multiplier", 1)) > 1 \
					or int(item.get("max_health_bonus", 0)) > 0 \
					or int(item.get("minimum_hand_size_bonus", 0)) > 0:
				return item
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
