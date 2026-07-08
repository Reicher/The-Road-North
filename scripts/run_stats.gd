class_name RunStats
extends RefCounted

const DEFAULT_EXPEDITION_NAME := "Räsers"

const STAT_DEFINITIONS := [
	{"id": "highest_level_reached", "label": "Level Reached", "higher_is_better": true},
	{"id": "moves_taken", "label": "Moves Taken", "higher_is_better": true},
	{"id": "tiles_placed", "label": "Tiles Placed", "higher_is_better": true},
	{"id": "cards_played", "label": "Cards Played", "higher_is_better": true},
	{"id": "cards_drawn", "label": "Cards Drawn", "higher_is_better": true},
	{"id": "road_cards_played", "label": "Road Cards", "higher_is_better": true},
	{"id": "event_cards_played", "label": "Event Cards", "higher_is_better": true},
	{"id": "enemies_defeated", "label": "Enemies Defeated", "higher_is_better": true},
	{"id": "combats_started", "label": "Combats Started", "higher_is_better": true},
	{"id": "combats_won", "label": "Combats Won", "higher_is_better": true},
	{"id": "combats_retreats", "label": "Retreats Filed", "higher_is_better": true},
	{"id": "damage_taken", "label": "Damage Taken", "higher_is_better": true},
	{"id": "food_spent", "label": "Food Spent", "higher_is_better": true},
	{"id": "food_gained", "label": "Food Gained", "higher_is_better": true},
	{"id": "gold_gained", "label": "Gold Collected", "higher_is_better": true},
	{"id": "gold_spent", "label": "Gold Spent", "higher_is_better": true},
	{"id": "caches_opened", "label": "Caches Opened", "higher_is_better": true},
	{"id": "berries_found", "label": "Berries Found", "higher_is_better": true},
	{"id": "items_found", "label": "Items Found", "higher_is_better": true},
	{"id": "best_weapon_power", "label": "Best Weapon Power", "higher_is_better": true},
	{"id": "max_player_power_reached", "label": "Max Power", "higher_is_better": true},
	{"id": "health_remaining", "label": "Health Remaining", "higher_is_better": true},
	{"id": "food_remaining", "label": "Food Remaining", "higher_is_better": true},
	{"id": "gold_remaining", "label": "Gold Remaining", "higher_is_better": true},
	{"id": "distance_from_goal_on_death", "label": "Distance From Goal", "higher_is_better": false},
	{"id": "steps_walked_backwards", "label": "Steps Backwards", "higher_is_better": true},
	{"id": "dead_ends_placed", "label": "Dead Ends Placed", "higher_is_better": true},
	{"id": "corners_rotated", "label": "Corners Rotated", "higher_is_better": true},
	{"id": "roads_to_nowhere", "label": "Roads To Nowhere", "higher_is_better": true},
	{"id": "times_saved_by_berries", "label": "Saved By Berries", "higher_is_better": true},
	{"id": "unnecessary_backtracking", "label": "Backtracking", "higher_is_better": true},
	{"id": "suspiciously_lucky_finds", "label": "Lucky Finds", "higher_is_better": true},
	{"id": "number_of_bad_ideas", "label": "Bad Ideas", "higher_is_better": true},
	{"id": "graves_not_visited", "label": "Graves Ignored", "higher_is_better": true},
	{"id": "trees_ignored", "label": "Trees Ignored", "higher_is_better": true},
]

var expedition_name := DEFAULT_EXPEDITION_NAME
var final_result := ""
var death_reason := ""
var highest_level_reached := 1
var moves_taken := 0
var tiles_placed := 0
var cards_played := 0
var cards_drawn := 0
var road_cards_played := 0
var event_cards_played := 0
var enemies_defeated := 0
var combats_started := 0
var combats_won := 0
var combats_retreats := 0
var damage_taken := 0
var food_spent := 0
var food_gained := 0
var gold_gained := 0
var gold_spent := 0
var caches_opened := 0
var berries_found := 0
var items_found := 0
var best_weapon_name := "Walking Stick"
var best_weapon_power := 1
var max_player_power_reached := 1
var health_remaining := 0
var food_remaining := 0
var gold_remaining := 0
var distance_from_goal_on_death := 0
var steps_walked_backwards := 0
var dead_ends_placed := 0
var corners_rotated := 0
var roads_to_nowhere := 0
var times_saved_by_berries := 0
var unnecessary_backtracking := 0
var suspiciously_lucky_finds := 0
var number_of_bad_ideas := 0
var graves_not_visited := 0
var trees_ignored := 0


func reset(name: String) -> void:
	var trimmed := name.strip_edges()
	expedition_name = DEFAULT_EXPEDITION_NAME if trimmed.is_empty() else trimmed
	final_result = ""
	death_reason = ""
	highest_level_reached = 1
	for definition in STAT_DEFINITIONS:
		var stat_id := str(definition["id"])
		if stat_id != "highest_level_reached":
			set(stat_id, 0)
	best_weapon_name = "Walking Stick"
	best_weapon_power = 1
	max_player_power_reached = 1


func get_stat_value(stat_id: String) -> Variant:
	return get(stat_id)


func to_record_context() -> Dictionary:
	return {
		"expedition_name": expedition_name,
		"final_result": final_result,
		"highest_level_reached": highest_level_reached,
		"death_reason": death_reason,
	}


func display_cards() -> Array[Dictionary]:
	return [
		{"id": "highest_level_reached", "label": "Level Reached", "value": str(highest_level_reached)},
		{"id": "tiles_placed", "label": "Tiles Placed", "value": str(tiles_placed)},
		{"id": "cards_played", "label": "Cards Played", "value": str(cards_played)},
		{"id": "food_spent", "label": "Food Spent", "value": str(food_spent)},
		{"id": "enemies_defeated", "label": "Enemies Defeated", "value": str(enemies_defeated)},
		{"id": "gold_gained", "label": "Gold Collected", "value": str(gold_gained)},
		{"id": "best_weapon_power", "label": "Best Weapon", "value": "%s +%d" % [best_weapon_name, best_weapon_power]},
		{"id": "steps_walked_backwards", "label": "Steps Backwards", "value": str(steps_walked_backwards)},
		{"id": "roads_to_nowhere", "label": "Roads To Nowhere", "value": str(roads_to_nowhere)},
		{"id": "dead_ends_placed", "label": "Dead Ends Placed", "value": str(dead_ends_placed)},
		{"id": "distance_from_goal_on_death", "label": "Distance From Goal", "value": "%d tiles" % distance_from_goal_on_death},
		{"id": "trees_ignored", "label": "Trees Ignored", "value": str(trees_ignored)},
		{"id": "damage_taken", "label": "Damage Taken", "value": str(damage_taken)},
		{"id": "berries_found", "label": "Berries Found", "value": str(berries_found)},
		{"id": "caches_opened", "label": "Caches Opened", "value": str(caches_opened)},
		{"id": "suspiciously_lucky_finds", "label": "Lucky Finds", "value": str(suspiciously_lucky_finds)},
	]
