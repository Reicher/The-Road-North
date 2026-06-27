class_name ItemCatalog
extends RefCounted

const STAT_MAX_HEALTH := "max_health"
const STAT_POWER := "power"
const STAT_SIGHT := "sight"
const STAT_MAX_HAND_SIZE := "max_hand_size"
const SUPPORTED_STATS: Array[String] = [
	STAT_MAX_HEALTH,
	STAT_POWER,
	STAT_SIGHT,
	STAT_MAX_HAND_SIZE,
]

const SIZE_LARGE := "large"
const SIZE_SMALL := "small"
const RARITY_COMMON := "Common"
const RARITY_UNCOMMON := "Uncommon"
const RARITY_RARE := "Rare"
const RARITY_EPIC := "Epic"
const RARITY_ORDER: Array[String] = [RARITY_COMMON, RARITY_UNCOMMON, RARITY_RARE, RARITY_EPIC]
const RARITY_WEIGHTS := {
	RARITY_COMMON: 0.50,
	RARITY_UNCOMMON: 0.30,
	RARITY_RARE: 0.15,
	RARITY_EPIC: 0.05,
}

# Static source data. item_score and rarity are deliberately assigned at startup.
const ITEM_DEFINITIONS: Array[Dictionary] = [
	{"name": "Walking Stick", "stats": {STAT_POWER: 1}, "size": SIZE_LARGE},
	{"name": "Short Blade", "stats": {STAT_POWER: 1}, "size": SIZE_SMALL},
	{"name": "Bent Spear", "stats": {STAT_POWER: 2, STAT_SIGHT: -1}, "size": SIZE_LARGE},
	{"name": "Old Sword", "stats": {STAT_POWER: 2, STAT_SIGHT: -1}, "size": SIZE_LARGE},
	{"name": "Dagger", "stats": {STAT_POWER: 2}, "size": SIZE_SMALL},
	{"name": "Hatchet", "stats": {STAT_POWER: 3}, "size": SIZE_SMALL},
	{"name": "Hunter's Knife", "stats": {STAT_POWER: 1, STAT_SIGHT: 1}, "size": SIZE_SMALL},
	{"name": "Heavy Club", "stats": {STAT_POWER: 4, STAT_SIGHT: -1}, "size": SIZE_LARGE},
	{"name": "Scout's Spear", "stats": {STAT_POWER: 3, STAT_MAX_HAND_SIZE: 1}, "size": SIZE_LARGE},
	{"name": "Cursed Blade", "stats": {STAT_POWER: 7, STAT_MAX_HAND_SIZE: -1}, "size": SIZE_LARGE},
	{"name": "Watchman's Lantern", "stats": {STAT_SIGHT: 2, STAT_POWER: -1}, "size": SIZE_SMALL},
	{"name": "Traveler's Pack", "stats": {STAT_MAX_HEALTH: 1, STAT_MAX_HAND_SIZE: 1, STAT_POWER: -1}, "size": SIZE_SMALL},
	{"name": "Machete", "stats": {STAT_POWER: 4}, "size": SIZE_LARGE},
	{"name": "Sword", "stats": {STAT_POWER: 5}, "size": SIZE_LARGE},
	{"name": "Mace", "stats": {STAT_POWER: 6}, "size": SIZE_LARGE},
	{"name": "Spear", "stats": {STAT_POWER: 7}, "size": SIZE_LARGE},
	{"name": "Sword & Shield", "stats": {STAT_POWER: 8, STAT_MAX_HEALTH: 1}, "size": SIZE_LARGE},
	{"name": "Great Axe", "stats": {STAT_POWER: 9}, "size": SIZE_LARGE},
	{"name": "Binoculars", "stats": {STAT_SIGHT: 1}, "size": SIZE_SMALL},
	{
		"name": "Goldsmith's Scale",
		"stats": {},
		"special_effects": {"gold_multiplier": 2},
		"special_effect_score": 4,
		"size": SIZE_SMALL,
	},
	{"name": "Field Medic's Bag", "stats": {STAT_MAX_HEALTH: 2}, "size": SIZE_LARGE},
	{"name": "Guiding Charm", "stats": {STAT_MAX_HAND_SIZE: 1}, "size": SIZE_SMALL},
]

static var _items: Array[Dictionary] = []


static func initialize() -> void:
	if not _items.is_empty():
		return
	for definition in ITEM_DEFINITIONS:
		var item := normalize_item(definition)
		item["item_score"] = calculate_item_score(item)
		_items.append(item)
	_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_comparison := int(a["item_score"]) < int(b["item_score"])
		if int(a["item_score"]) == int(b["item_score"]):
			return str(a["name"]) < str(b["name"])
		return score_comparison
	)
	_assign_rarities()


static func all_items() -> Array[Dictionary]:
	initialize()
	var result: Array[Dictionary] = []
	for item in _items:
		result.append(item.duplicate(true))
	return result


static func get_item(item_name: String) -> Dictionary:
	initialize()
	for item in _items:
		if str(item.get("name", "")) == item_name:
			return item.duplicate(true)
	return {}


static func items_for_rarity(rarity: String) -> Array[Dictionary]:
	initialize()
	var result: Array[Dictionary] = []
	for item in _items:
		if str(item.get("rarity", "")) == rarity:
			result.append(item.duplicate(true))
	return result


static func roll_loot_item(rng: RandomNumberGenerator) -> Dictionary:
	initialize()
	var rarity := roll_rarity(rng)
	var candidates := items_for_rarity(rarity)
	if candidates.is_empty():
		# Small catalogs may not fill every percentile. Use the nearest lower group.
		for index in range(RARITY_ORDER.find(rarity) - 1, -1, -1):
			candidates = items_for_rarity(RARITY_ORDER[index])
			if not candidates.is_empty():
				break
	if candidates.is_empty():
		return {}
	return candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)


static func roll_rarity(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	var threshold := 0.0
	for rarity in RARITY_ORDER:
		threshold += float(RARITY_WEIGHTS[rarity])
		if roll < threshold:
			return rarity
	return RARITY_EPIC


static func calculate_item_score(item: Dictionary) -> int:
	var score := 0
	var stats: Dictionary = item.get("stats", {})
	for value in stats.values():
		score += int(value)
	return score + int(item.get("special_effect_score", 0))


static func normalize_item(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var result := item.duplicate(true)
	var stats: Dictionary = result.get("stats", {}).duplicate(true)
	for mapping in [
		["max_health_bonus", STAT_MAX_HEALTH],
		["power_bonus", STAT_POWER],
		["sight_bonus", STAT_SIGHT],
		["minimum_hand_size_bonus", STAT_MAX_HAND_SIZE],
	]:
		if result.has(mapping[0]) and not stats.has(mapping[1]):
			stats[mapping[1]] = int(result[mapping[0]])
	result["stats"] = stats
	var special_effects: Dictionary = result.get("special_effects", {}).duplicate(true)
	if result.has("gold_multiplier"):
		special_effects["gold_multiplier"] = int(result["gold_multiplier"])
	if not special_effects.is_empty():
		result["special_effects"] = special_effects
	result["size"] = str(result.get("size", _default_size_for_name(str(result.get("name", "")))))
	result["item_score"] = calculate_item_score(result)
	result["rarity"] = str(result.get("rarity", RARITY_COMMON))
	if not result.has("effect"):
		result["effect"] = describe_effect(result)
	for legacy_key in ["max_health_bonus", "power_bonus", "sight_bonus", "minimum_hand_size_bonus", "gold_multiplier"]:
		result.erase(legacy_key)
	return result


static func get_stat(item: Dictionary, stat_name: String) -> int:
	var stats: Dictionary = item.get("stats", {})
	if stats.has(stat_name):
		return int(stats[stat_name])
	var legacy_keys := {
		STAT_MAX_HEALTH: "max_health_bonus",
		STAT_POWER: "power_bonus",
		STAT_SIGHT: "sight_bonus",
		STAT_MAX_HAND_SIZE: "minimum_hand_size_bonus",
	}
	return int(item.get(legacy_keys.get(stat_name, ""), 0))


static func get_special_effect(item: Dictionary, effect_name: String, default_value: int = 0) -> int:
	var effects: Dictionary = item.get("special_effects", {})
	return int(effects.get(effect_name, item.get(effect_name, default_value)))


static func describe_effect(item: Dictionary) -> String:
	var parts: Array[String] = []
	var labels := {
		STAT_MAX_HEALTH: "Max Health",
		STAT_POWER: "Power",
		STAT_SIGHT: "Sight",
		STAT_MAX_HAND_SIZE: "Max Hand Size",
	}
	for stat_name in SUPPORTED_STATS:
		var value := get_stat(item, stat_name)
		if value != 0:
			parts.append("%+d %s" % [value, labels[stat_name]])
	if get_special_effect(item, "gold_multiplier", 1) > 1:
		parts.append("Gain twice as much gold.")
	return "\n".join(parts)


static func size_symbol(item: Dictionary) -> String:
	return "▲" if str(item.get("size", SIZE_SMALL)) == SIZE_LARGE else ""


static func _default_size_for_name(item_name: String) -> String:
	if item_name in ["Walking Stick", "Bent Spear", "Old Sword", "Heavy Club", "Scout's Spear", "Cursed Blade", "Machete", "Sword", "Mace", "Spear", "Sword & Shield", "Great Axe", "Field Medic's Bag"]:
		return SIZE_LARGE
	return SIZE_SMALL


static func _assign_rarities() -> void:
	var item_count := _items.size()
	for index in item_count:
		# Rank percentiles keep a non-empty Epic group once at least four items exist.
		var percentile := float(index + 1) / float(item_count)
		var rarity := RARITY_EPIC
		if percentile <= 0.50:
			rarity = RARITY_COMMON
		elif percentile <= 0.80:
			rarity = RARITY_UNCOMMON
		elif percentile <= 0.95:
			rarity = RARITY_RARE
		if (_items[index].get("special_effects", {}) as Dictionary).size() > 0 and rarity in [RARITY_COMMON, RARITY_UNCOMMON]:
			rarity = RARITY_RARE
		_items[index]["rarity"] = rarity
