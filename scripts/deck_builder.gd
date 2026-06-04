class_name DeckBuilder
extends Node

const CARD_DEFINITION_SCRIPT := preload("res://scripts/card_definition.gd")

const ROAD_CATEGORY := "Road"
const EVENT_CATEGORY := "Event"
const EVENT_DESTROY_TILE := "destroy_tile"
const EVENT_DRAW_TWO := "draw_two"
const EVENT_ROTATE_TILE := "rotate_tile"
const EVENT_LUCKY_FIND := "lucky_find"
const ENCOUNTER_ENEMY := "enemy"


func make_deck(deck_size: int, rng: RandomNumberGenerator, config: Dictionary) -> Array[Dictionary]:
	var road_ratio := float(config.get("road_card_ratio", 0.75))
	var road_count := roundi(float(deck_size) * road_ratio)
	var event_count: int = maxi(0, deck_size - road_count)

	var cards: Array[Dictionary] = []
	for road_card in _make_road_cards(road_count, rng, config):
		cards.append(road_card)
	for event_card in _make_event_cards(event_count):
		cards.append(event_card)
	return cards


func _make_road_cards(count: int, rng: RandomNumberGenerator, config: Dictionary) -> Array[Dictionary]:
	var definitions: Dictionary = config.get("road_definitions", {})
	var road_distribution: Dictionary = config.get("road_distribution", {})
	var counts := _counts_from_distribution(count, road_distribution)
	var cards: Array[Dictionary] = []
	for subtype in counts:
		if not definitions.has(subtype):
			continue
		var card_count: int = counts[subtype]
		for _index in card_count:
			cards.append(_make_road_card(definitions[subtype]))
	_add_enemy_encounters_to_road_cards(cards, rng, float(config.get("enemy_road_card_ratio", 0.0)), int(config.get("enemy_level", 1)))
	_add_reward_encounters_to_road_cards(cards, rng, float(config.get("reward_road_card_ratio", 0.0)))
	return cards


func _make_event_cards(count: int) -> Array[Dictionary]:
	var event_templates: Array[Dictionary] = [
		{"title": "Mirage", "detail": "Destroy a placed tile.", "event_type": EVENT_DESTROY_TILE},
		{"title": "Idea", "detail": "Draw two extra cards.", "event_type": EVENT_DRAW_TWO},
		{"title": "Doubt", "detail": "Rotate a placed tile.", "event_type": EVENT_ROTATE_TILE},
		{"title": "Lucky Find", "detail": "Gain food or gold.", "event_type": EVENT_LUCKY_FIND},
	]
	var cards: Array[Dictionary] = []
	for index in count:
		var template: Dictionary = event_templates[index % event_templates.size()]
		cards.append(_make_event_card(template["title"], template["detail"], template["event_type"]))
	return cards


func _make_road_card(tile_definition_resource: Resource) -> Dictionary:
	var definition = CARD_DEFINITION_SCRIPT.new()
	definition.category = ROAD_CATEGORY
	definition.tile_definition = tile_definition_resource
	return definition.to_card_data()


func _make_event_card(title: String, detail: String, event_type: String) -> Dictionary:
	var definition = CARD_DEFINITION_SCRIPT.new()
	definition.category = EVENT_CATEGORY
	definition.title = title
	definition.detail = detail
	definition.event_type = event_type
	return definition.to_card_data()


func _counts_from_distribution(total: int, distribution: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	var fractions: Array[Dictionary] = []
	var assigned := 0
	var weight_total := 0.0

	for key in distribution:
		weight_total += float(distribution[key])
	if is_zero_approx(weight_total):
		return counts

	for key in distribution:
		var exact_count := float(total) * float(distribution[key]) / weight_total
		var base_count := floori(exact_count)
		counts[key] = base_count
		fractions.append({
			"key": key,
			"fraction": exact_count - float(base_count),
		})
		assigned += base_count

	fractions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["fraction"]) > float(b["fraction"]))

	var remaining := total - assigned
	for index in remaining:
		var key: String = fractions[index % fractions.size()]["key"]
		counts[key] += 1

	return counts


func _add_enemy_encounters_to_road_cards(cards: Array[Dictionary], rng: RandomNumberGenerator, enemy_ratio: float, enemy_level: int) -> void:
	var enemy_count := roundi(float(cards.size()) * enemy_ratio)
	_shuffle_cards(cards, rng)

	for index in mini(enemy_count, cards.size()):
		var card: Dictionary = cards[index]
		_set_card_encounter(card, _make_enemy_encounter(rng, enemy_level))
		card["title"] = _encounter_title_for_card(card)
		card["detail"] = "Enemy waits on this road."
		cards[index] = card


func _make_enemy_encounter(rng: RandomNumberGenerator, enemy_level: int) -> Dictionary:
	return {
		"type": ENCOUNTER_ENEMY,
		"revealed": false,
		"health": 1,
		"max_health": 1,
		"power": maxi(1, enemy_level) * rng.randi_range(1, 3),
	}


func _add_reward_encounters_to_road_cards(cards: Array[Dictionary], rng: RandomNumberGenerator, reward_ratio: float) -> void:
	var reward_count := roundi(float(cards.size()) * reward_ratio)
	var eligible_indices: Array[int] = []
	for index in cards.size():
		if not cards[index].has("encounter"):
			eligible_indices.append(index)
	_shuffle_ints(eligible_indices, rng)

	for index in mini(reward_count, eligible_indices.size()):
		var card_index := eligible_indices[index]
		var card: Dictionary = cards[card_index]
		_set_card_encounter(card, _make_reward_encounter(index))
		card["title"] = _encounter_title_for_card(card)
		card["detail"] = _encounter_detail(card["encounter"])
		cards[card_index] = card


func _set_card_encounter(card: Dictionary, encounter: Dictionary) -> void:
	card["encounter"] = encounter
	var definition = card.get("card_definition")
	if definition is CARD_DEFINITION_SCRIPT:
		definition.encounter = encounter.duplicate(true)


func _make_reward_encounter(index: int) -> Dictionary:
	var reward_types: Array[String] = [GameMap.ENCOUNTER_BERRY_BUSH, GameMap.ENCOUNTER_CACHE]
	var kind: String = reward_types[index % reward_types.size()]
	if kind == GameMap.ENCOUNTER_BERRY_BUSH:
		return {
			"type": kind,
			"loot": [{"kind": "food", "amount": 3}],
		}
	return {
		"type": kind,
		"loot": [{
			"kind": "item",
			"item": {
				"name": "Knife",
				"effect": "+1 Power",
				"power": 1,
			},
		}],
	}


func _encounter_title_for_card(card: Dictionary) -> String:
	var encounter: Dictionary = card.get("encounter", {})
	var prefix := "Encounter"
	var kind := str(encounter.get("type", ""))
	if kind == ENCOUNTER_ENEMY:
		prefix = "Enemy"
	elif kind == GameMap.ENCOUNTER_BERRY_BUSH:
		prefix = "Berry Bush"
	elif kind == GameMap.ENCOUNTER_CACHE:
		prefix = "Cache"
	var definition: Resource = card.get("tile_definition")
	if definition == null:
		return prefix
	return "%s %s" % [prefix, str(definition.get("display_name"))]


func _encounter_detail(encounter: Dictionary) -> String:
	var kind := str(encounter.get("type", ""))
	if kind == GameMap.ENCOUNTER_BERRY_BUSH:
		return "Grants food when reached."
	if kind == GameMap.ENCOUNTER_CACHE:
		return "Contains an item when reached."
	return "Reward waits on this road."


func _shuffle_cards(cards: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var card := cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = card


func _shuffle_ints(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
