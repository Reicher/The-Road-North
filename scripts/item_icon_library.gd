class_name ItemIconLibrary
extends RefCounted

const ICON_PATHS := {
	"binoculars": "res://assets/images/item_binoculars.svg",
	"dagger": "res://assets/images/item_dagger.png",
	"item": "res://assets/images/item_item.png",
	"katana": "res://assets/images/item_katana.png",
	"knife": "res://assets/images/item_knife.png",
	"machete": "res://assets/images/item_machete.png",
	"sword": "res://assets/images/item_sword.png",
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
