class_name CardDefinition
extends Resource

const ROAD_CATEGORY := "Road"
const EVENT_CATEGORY := "Event"

@export var category := ROAD_CATEGORY
@export var title := ""
@export var detail := ""
@export var tile_definition: Resource
@export var event_type := ""
@export var encounter := {}
@export var card_color := Color.TRANSPARENT


func to_card_data() -> Dictionary:
	var card_data := {
		"card_definition": self,
		"category": category,
	}
	if not title.is_empty():
		card_data["title"] = title
	if not detail.is_empty():
		card_data["detail"] = detail
	if tile_definition != null:
		card_data["tile_definition"] = tile_definition
	if not event_type.is_empty():
		card_data["event_type"] = event_type
	if not encounter.is_empty():
		card_data["encounter"] = encounter.duplicate(true)
	if card_color != Color.TRANSPARENT:
		card_data["card_color"] = card_color
	return card_data
