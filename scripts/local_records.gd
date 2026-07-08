class_name LocalRecords
extends RefCounted

const RunStats = preload("res://scripts/run_stats.gd")
const SAVE_PATH := "user://records.json"


static func update_with_run(stats: RunStats) -> Dictionary:
	var records := _load_records()
	var new_records: Dictionary = {}
	var context := stats.to_record_context()
	for definition in RunStats.STAT_DEFINITIONS:
		var stat_id := str(definition["id"])
		var value: Variant = stats.get_stat_value(stat_id)
		if not (value is int or value is float):
			continue
		var previous: Dictionary = records.get(stat_id, {})
		if previous.is_empty() or _beats(value, previous.get("best_value", value), bool(definition["higher_is_better"])):
			var record := {
				"stat_id": stat_id,
				"stat_label": str(definition["label"]),
				"best_value": value,
				"expedition_name": context["expedition_name"],
				"date_time": Time.get_datetime_string_from_system(false, true),
				"final_result": context["final_result"],
				"highest_level_reached": context["highest_level_reached"],
				"death_reason": context["death_reason"],
			}
			if not previous.is_empty():
				record["previous_value"] = previous.get("best_value")
				record["previous_expedition_name"] = previous.get("expedition_name", "")
			records[stat_id] = record
			new_records[stat_id] = record
	_save_records(records)
	return new_records


static func _beats(value: Variant, previous: Variant, higher_is_better: bool) -> bool:
	if higher_is_better:
		return float(value) > float(previous)
	return float(value) < float(previous)


static func _load_records() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _save_records(records: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save local records to %s." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(records, "\t"))
