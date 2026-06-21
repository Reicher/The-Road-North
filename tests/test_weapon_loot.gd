extends SceneTree

const DECK_BUILDER_SCRIPT := preload("res://scripts/deck_builder.gd")
const ItemCatalog := preload("res://scripts/item_catalog.gd")
const ItemIconLibrary := preload("res://scripts/item_icon_library.gd")

const SAMPLE_COUNT := 20000


func _initialize() -> void:
	_test_item_catalog_schema_and_scoring()
	_test_dynamic_rarity_groups()
	_test_rarity_roll_distribution()
	_test_every_item_is_in_the_starting_loot_pool()
	_test_cache_loot_is_not_level_specific()
	_test_shop_enforces_the_large_item_limit()
	quit()


func _test_item_catalog_schema_and_scoring() -> void:
	var expected_names := ["Walking Stick", "Dagger", "Hatchet", "Machete", "Sword", "Mace", "Spear", "Sword & Shield", "Great Axe"]
	var items := ItemCatalog.all_items()
	_assert(items.size() == 13, "Expected all nine weapons and four utility items in one catalog")
	for item in items:
		_assert(item.has("stats") and item.has("item_score") and item.has("rarity") and item.has("size"), "Expected every item to expose the new item fields")
		_assert(ItemCatalog.calculate_item_score(item) == int(item["item_score"]), "Expected item_score to be calculated from stats and special effects")
		_assert(str(item["size"]) in [ItemCatalog.SIZE_LARGE, ItemCatalog.SIZE_SMALL], "Expected every item to have a supported size")
		_assert(ItemIconLibrary.get_icon(item) != null, "Expected every catalog item to have an icon")
	for index in expected_names.size():
		var weapon := ItemCatalog.get_item(expected_names[index])
		_assert(ItemCatalog.get_stat(weapon, ItemCatalog.STAT_POWER) == index + 1, "Expected weapon power in the stats dictionary")
		_assert(weapon["size"] == ItemCatalog.SIZE_LARGE, "Expected carried weapons to use the single large-item slot")
	_assert(ItemCatalog.get_item("Binoculars")["size"] == ItemCatalog.SIZE_SMALL, "Expected Binoculars to be a small tool")
	_assert(ItemCatalog.get_item("Guiding Charm")["size"] == ItemCatalog.SIZE_SMALL, "Expected Guiding Charm to be a small passive item")
	_assert(ItemCatalog.get_item("Field Medic's Bag")["size"] == ItemCatalog.SIZE_LARGE, "Expected Field Medic's Bag to be large equipment")


func _test_dynamic_rarity_groups() -> void:
	var previous_score := -1
	for item in ItemCatalog.all_items():
		_assert(int(item["item_score"]) >= previous_score, "Expected the startup catalog to be sorted by item_score")
		previous_score = int(item["item_score"])
		if not (item.get("special_effects", {}) as Dictionary).is_empty():
			_assert(str(item["rarity"]) in [ItemCatalog.RARITY_RARE, ItemCatalog.RARITY_EPIC], "Expected special-effect items to be at least Rare")
	for rarity in ItemCatalog.RARITY_ORDER:
		_assert(not ItemCatalog.items_for_rarity(rarity).is_empty(), "Expected every rarity to have loot candidates")


func _test_rarity_roll_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 56789
	var counts := {}
	for rarity in ItemCatalog.RARITY_ORDER:
		counts[rarity] = 0
	for _index in SAMPLE_COUNT:
		var rarity := ItemCatalog.roll_rarity(rng)
		counts[rarity] = int(counts[rarity]) + 1
	for rarity in ItemCatalog.RARITY_ORDER:
		var ratio := float(counts[rarity]) / float(SAMPLE_COUNT)
		_assert(absf(ratio - float(ItemCatalog.RARITY_WEIGHTS[rarity])) < 0.02, "Expected chest rarity roll to follow %s weight" % rarity)


func _test_every_item_is_in_the_starting_loot_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6122026
	var seen := {}
	for _index in SAMPLE_COUNT:
		var item := ItemCatalog.roll_loot_item(rng)
		seen[str(item.get("name", ""))] = true
	for item in ItemCatalog.all_items():
		_assert(seen.has(str(item["name"])), "Expected %s in the loot pool from game start" % item["name"])


func _test_cache_loot_is_not_level_specific() -> void:
	var builder = DECK_BUILDER_SCRIPT.new()
	var first_rng := RandomNumberGenerator.new()
	var late_rng := RandomNumberGenerator.new()
	first_rng.seed = 24680
	late_rng.seed = 24680
	for _index in 100:
		var first_item: Dictionary = builder._make_reward_encounter(GameMap.ENCOUNTER_CACHE, first_rng, 1)["loot"][0]["item"]
		var late_item: Dictionary = builder._make_reward_encounter(GameMap.ENCOUNTER_CACHE, late_rng, 9)["loot"][0]["item"]
		_assert(first_item["name"] == late_item["name"], "Expected cache item rolls to ignore level")
	builder.free()


func _test_shop_enforces_the_large_item_limit() -> void:
	var shop := ShopUI.new()
	shop.progression = {
		"gold": 100,
		"inventory": [ItemCatalog.get_item("Walking Stick"), {}, {}],
	}
	shop.item_offers.append(ItemCatalog.get_item("Hatchet").merged({"price": 1}, true))
	_assert(not shop.buy_item_to_slot(0, 1), "Expected the shop to reject a second large item")
	shop.progression["inventory"][0] = {}
	_assert(shop.buy_item_to_slot(0, 1), "Expected a large item to fit after the carried large item is removed")
	shop.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
