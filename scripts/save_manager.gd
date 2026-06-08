## Simple save/load system for mobile-first persistence.
## Saves progression state to user:// so progress survives app kills.
class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 1


static func save_progression(progression: Dictionary, current_level_index: int) -> bool:
	var save_data := {
		"version": SAVE_VERSION,
		"level_index": current_level_index,
		"progression": progression.duplicate(true),
		"timestamp": Time.get_unix_time_from_system(),
	}

	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: Could not open save file for writing: %s" % SAVE_PATH)
		return false

	file.store_string(json_string)
	file.close()
	return true


static func load_progression() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: Could not open save file for reading: %s" % SAVE_PATH)
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_warning("SaveManager: Failed to parse save file: %s" % json.get_error_message())
		return {}

	var save_data: Variant = json.data
	if not (save_data is Dictionary):
		push_warning("SaveManager: Save data is not a Dictionary.")
		return {}

	if int(save_data.get("version", 0)) != SAVE_VERSION:
		push_warning("SaveManager: Save version mismatch, ignoring save.")
		return {}

	return save_data


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
