class_name ItemIconLibrary
extends RefCounted

const ICON_PATHS := {
	"dagger": "res://assets/images/item_dagger.png",
	"item": "res://assets/images/item_item.png",
	"katana": "res://assets/images/item_katana.png",
	"knife": "res://assets/images/item_knife.png",
	"machete": "res://assets/images/item_machete.png",
	"sword": "res://assets/images/item_sword.png",
}

static var _cache: Dictionary = {}


static func get_icon(item: Dictionary) -> Texture2D:
	var item_name := str(item.get("name", "item")).to_lower()
	var path := str(ICON_PATHS.get(item_name, ICON_PATHS["item"]))
	if _cache.has(path):
		return _cache[path]
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if error != OK or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_cache[path] = texture
	return texture
