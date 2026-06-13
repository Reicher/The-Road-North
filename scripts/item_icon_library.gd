class_name ItemIconLibrary
extends RefCounted

const ICON_PATHS := {
	"binoculars": "res://assets/images/items/item_binoculars.png",
	"dagger": "res://assets/images/items/item_dagger.png",
	"field medic's bag": "res://assets/images/items/item_field_medics_bag.png",
	"goldsmith's scale": "res://assets/images/items/item_goldsmiths_scale.png",
	"great axe": "res://assets/images/items/item_great_axe.png",
	"guiding charm": "res://assets/images/items/item_guiding_charm.png",
	"hatchet": "res://assets/images/items/item_hatchet.png",
	"item": "res://assets/images/items/item_fallback.png",
	"mace": "res://assets/images/items/item_mace.png",
	"machete": "res://assets/images/items/item_machete.png",
	"spear": "res://assets/images/items/item_spear.png",
	"sword": "res://assets/images/items/item_sword.png",
	"sword & shield": "res://assets/images/items/item_sword_and_shield.png",
	"walking stick": "res://assets/images/items/item_walking_stick.png",
}

static var _cache: Dictionary = {}


## Call between level loads to free unused icon memory.
static func clear_cache() -> void:
	_cache.clear()


static func get_icon(item: Dictionary) -> Texture2D:
	var item_name := str(item.get("name", "item")).to_lower()
	var path := str(ICON_PATHS.get(item_name, ICON_PATHS["item"]))
	if _cache.has(path):
		return _cache[path]
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Could not load item icon: %s" % path)
		return null
	_cache[path] = texture
	return texture
