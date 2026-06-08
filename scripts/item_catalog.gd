class_name ItemCatalog
extends RefCounted

const BINOCULARS_DROP_CHANCE := 0.15
const BINOCULARS := {
	"name": "Binoculars",
	"effect": "Place cards further away.",
	"target_range_bonus": 1,
}


static func make_binoculars() -> Dictionary:
	return BINOCULARS.duplicate(true)
