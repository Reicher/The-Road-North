class_name ItemIconLibrary
extends RefCounted

const ItemCatalog = preload("res://scripts/item_catalog.gd")

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


static func update_size_badge(control: Control, item: Dictionary) -> void:
	var badge := control.get_node_or_null("ItemSizeBadge") as Label
	if item.is_empty():
		if badge != null:
			badge.visible = false
		return
	if badge == null:
		badge = Label.new()
		badge.name = "ItemSizeBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.position = Vector2(-24.0, 2.0)
		badge.size = Vector2(22.0, 22.0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 18)
		badge.add_theme_color_override("font_color", Color(0.18, 0.12, 0.07))
		badge.add_theme_color_override("font_shadow_color", Color(1.0, 0.95, 0.78))
		badge.add_theme_constant_override("shadow_offset_x", 1)
		badge.add_theme_constant_override("shadow_offset_y", 1)
		control.add_child(badge)
	badge.text = ItemCatalog.size_symbol(item)
	badge.tooltip_text = "Large item" if str(item.get("size", ItemCatalog.SIZE_SMALL)) == ItemCatalog.SIZE_LARGE else "Small item"
	badge.visible = true
