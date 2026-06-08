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
const EVENT_AMBUSH := "ambush"
const EVENT_WILD_BERRIES := "wild_berries"
const EVENT_LOST_BELONGINGS := "lost_belongings"
const EVENT_RESTART_LEVEL := "restart_level"

const TARGETED_EVENT_TYPES: Array[String] = [
	EVENT_DESTROY_TILE,
	EVENT_ROTATE_TILE,
	EVENT_CLEAR_PATH,
	EVENT_AMBUSH,
	EVENT_WILD_BERRIES,
	EVENT_LOST_BELONGINGS,
]

const ENCOUNTER_EVENT_TYPES: Array[String] = [
	EVENT_CLEAR_PATH,
	EVENT_AMBUSH,
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
	"food": "res://assets/images/stat_food.png",
	"gold": "res://assets/images/stat_gold.png",
	"health": "res://assets/images/stat_health.png",
	"deck": "res://assets/images/stat_deck.png",
	"power": "res://assets/images/stat_power.png",
}


## Returns a unique string signature for a card dictionary.
## Used by shop removal and deck modifier tracking.
static func card_signature(card: Dictionary) -> String:
	var definition: Resource = card.get("tile_definition")
	if definition != null:
		return "road:%s" % str(definition.get("display_name"))
	return "event:%s" % str(card.get("event_type", card.get("title", "")))
