## Single source of truth for game-wide constants.
## Other scripts should reference these instead of re-declaring duplicates.
class_name GameConstants
extends RefCounted

# --- Card Categories ---
const ROAD_CATEGORY := "Road"
const EVENT_CATEGORY := "Event"

# --- Encounter Types ---
const ENCOUNTER_ENEMY := "enemy"
const ENCOUNTER_BERRY_BUSH := "berry_bush"
const ENCOUNTER_CACHE := "cache"
const ENCOUNTER_CAMPFIRE := "campfire"
const ENCOUNTER_TAVERN := "tavern"
const ENCOUNTER_WITCH_HUT := "witch_hut"
const ENCOUNTER_SHRINE := "shrine"
const ENCOUNTER_GRAVEYARD := "graveyard"

const PERMANENT_ENCOUNTER_TYPES: Array[String] = [
	ENCOUNTER_CAMPFIRE,
	ENCOUNTER_TAVERN,
	ENCOUNTER_WITCH_HUT,
	ENCOUNTER_SHRINE,
]

const REUSABLE_ENCOUNTER_TYPES: Array[String] = [
	ENCOUNTER_CAMPFIRE,
	ENCOUNTER_TAVERN,
	ENCOUNTER_WITCH_HUT,
	ENCOUNTER_SHRINE,
	ENCOUNTER_GRAVEYARD,
]

# --- Map Features ---
const FEATURE_MOUNTAIN := "mountain"
const FEATURE_RIVER := "river"
const FEATURE_BRIDGE := "bridge"

# --- Event Types ---
const EVENT_DESTROY_TILE := "destroy_tile"
const EVENT_DRAW_TWO := "draw_two"
const EVENT_ROTATE_TILE := "rotate_tile"
const EVENT_LUCKY_FIND := "lucky_find"
const EVENT_CLEAR_PATH := "clear_path"
const EVENT_TROUBLE := "trouble"
const EVENT_WILD_BERRIES := "wild_berries"
const EVENT_LOST_BELONGINGS := "lost_belongings"
const EVENT_RESTART_LEVEL := "restart_level"
const EVENT_SLEEP := "sleep"

const TARGETED_EVENT_TYPES: Array[String] = [
	EVENT_DESTROY_TILE,
	EVENT_ROTATE_TILE,
	EVENT_CLEAR_PATH,
	EVENT_TROUBLE,
	EVENT_WILD_BERRIES,
	EVENT_LOST_BELONGINGS,
]

const ENCOUNTER_EVENT_TYPES: Array[String] = [
	EVENT_CLEAR_PATH,
	EVENT_TROUBLE,
	EVENT_WILD_BERRIES,
	EVENT_LOST_BELONGINGS,
]

# --- Deck Sources ---
const DECK_SOURCE_BASE := "base"
const DECK_SOURCE_LEVEL := "level"
const DECK_SOURCE_PLAYER_SPECIAL := "player_special"

# --- Directions ---
const DIRECTIONS: Dictionary = {
	"north": Vector2i(0, -1),
	"east": Vector2i(1, 0),
	"south": Vector2i(0, 1),
	"west": Vector2i(-1, 0),
}

const OPPOSITE_DIRECTIONS: Dictionary = {
	"north": "south",
	"east": "west",
	"south": "north",
	"west": "east",
}

# --- Stat Icon Paths ---
const STAT_ICON_PATHS := {
	"food": "res://assets/images/stats/stat_food.png",
	"gold": "res://assets/images/stats/stat_gold.png",
	"health": "res://assets/images/stats/stat_health.png",
	"deck": "res://assets/images/stats/stat_deck.png",
	"power": "res://assets/images/stats/stat_power.png",
}


## Returns a unique string signature for a card dictionary.
## Used by shop removal and deck modifier tracking.
static func card_signature(card: Dictionary) -> String:
	var encounter: Dictionary = card.get("encounter", {})
	var encounter_type := str(encounter.get("type", ""))
	if encounter_type in PERMANENT_ENCOUNTER_TYPES:
		var special_definition: Resource = card.get("tile_definition")
		var road_name := str(special_definition.get("display_name")) if special_definition != null else "Unassigned"
		return "special_road:%s:%s" % [encounter_type, road_name]
	var definition: Resource = card.get("tile_definition")
	if definition != null:
		return "road:%s" % str(definition.get("display_name"))
	return "event:%s" % str(card.get("event_type", card.get("title", "")))
