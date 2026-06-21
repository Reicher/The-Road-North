class_name ItemCatalog
extends RefCounted

const UTILITY_ITEM_DROP_CHANCE := 0.15
const BINOCULARS := {
	"name": "Binoculars",
	"effect": "+1 Sight",
	"sight_bonus": 1,
}
const GOLDSMITHS_SCALE := {
	"name": "Goldsmith's Scale",
	"effect": "Gain twice as much gold.",
	"gold_multiplier": 2,
}
const FIELD_MEDICS_BAG := {
	"name": "Field Medic's Bag",
	"effect": "+2 Max Health",
	"max_health_bonus": 2,
}
const GUIDING_CHARM := {
	"name": "Guiding Charm",
	"effect": "Minimum hand size +1.",
	"minimum_hand_size_bonus": 1,
}

const UTILITY_ITEMS: Array[Dictionary] = [
	BINOCULARS,
	GOLDSMITHS_SCALE,
	FIELD_MEDICS_BAG,
	GUIDING_CHARM,
]


static func roll_utility_item(rng: RandomNumberGenerator) -> Dictionary:
	return UTILITY_ITEMS[rng.randi_range(0, UTILITY_ITEMS.size() - 1)].duplicate(true)
