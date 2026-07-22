class_name LevelCatalog
extends Resource

@export var level_scenes: Array[PackedScene] = []
@export var level_names: PackedStringArray = PackedStringArray()
@export var map_sizes: PackedInt32Array = PackedInt32Array()


func size() -> int:
	return level_scenes.size()


func get_level(index: int) -> Dictionary:
	if level_scenes.is_empty():
		return {}
	var clamped_index := clampi(index, 0, level_scenes.size() - 1)
	return {
		"scene": level_scenes[clamped_index],
		"name": _name_at(clamped_index),
		"map_size": _map_size_at(clamped_index),
	}


func _name_at(index: int) -> String:
	if index >= 0 and index < level_names.size() and not level_names[index].is_empty():
		return level_names[index]
	return "Level %d" % (index + 1)


func _map_size_at(index: int) -> int:
	if index >= 0 and index < map_sizes.size():
		return map_sizes[index]
	return 5
