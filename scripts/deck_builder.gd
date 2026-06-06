class_name DeckBuilder
extends Node

const CARD_DEFINITION_SCRIPT := preload("res://scripts/card_definition.gd")
const WeaponCatalog = preload("res://scripts/weapon_catalog.gd")

const ROAD_CATEGORY := "Road"
const EVENT_CATEGORY := "Event"
const EVENT_DESTROY_TILE := "destroy_tile"
const EVENT_DRAW_TWO := "draw_two"
const EVENT_ROTATE_TILE := "rotate_tile"
const EVENT_LUCKY_FIND := "lucky_find"
const ENCOUNTER_ENEMY := "enemy"
const CACHE_GOLD_MIN := 0
const CACHE_GOLD_MAX := 5
const ROAD_SUBTYPES: Array[String] = ["straight", "corner", "t_junction", "four_way", "dead_end"]


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


func make_debug_hand(kind: String, config: Dictionary) -> Array[Dictionary]:
	var roads := _make_one_of_each_road(config)
	match kind:
		"roads":
			return roads
		"enemies":
			return _make_debug_enemy_roads(roads, int(config.get("level", 1)))
		"rewards":
			return _make_debug_reward_roads(roads, int(config.get("level", 1)))
		"events":
			return _make_event_cards(4)
	return []


func make_most_likely_hand(cards: Array[Dictionary], hand_size: int) -> Array[Dictionary]:
	var grouped_cards: Dictionary = {}
	for card in cards:
		var signature := _debug_card_signature(card)
		if not grouped_cards.has(signature):
			grouped_cards[signature] = []
		grouped_cards[signature].append(card)

	var groups: Array = grouped_cards.values()
	var best := {"weight": -1.0, "selection": []}
	_find_most_likely_selection(groups, 0, mini(hand_size, cards.size()), 1.0, [], best)

	var hand: Array[Dictionary] = []
	var selection: Array = best["selection"]
	for index in groups.size():
		var group: Array = groups[index]
		for card_index in int(selection[index]):
			hand.append((group[card_index] as Dictionary).duplicate(true))
	return hand


func _find_most_likely_selection(groups: Array, group_index: int, remaining: int, weight: float, selection: Array, best: Dictionary) -> void:
	if group_index == groups.size():
		if remaining == 0 and weight > float(best["weight"]):
			best["weight"] = weight
			best["selection"] = selection.duplicate()
		return

	var group: Array = groups[group_index]
	for count in mini(group.size(), remaining) + 1:
		selection.append(count)
		_find_most_likely_selection(groups, group_index + 1, remaining - count, weight * _combination_count(group.size(), count), selection, best)
		selection.pop_back()


func _combination_count(total: int, chosen: int) -> float:
	var result := 1.0
	for index in chosen:
		result *= float(total - index) / float(index + 1)
	return result


func _debug_card_signature(card: Dictionary) -> String:
	var tile_definition: Resource = card.get("tile_definition")
	var road_type := ""
	if tile_definition != null:
		road_type = str(tile_definition.get("display_name"))
	var encounter: Dictionary = card.get("encounter", {})
	return "|".join([
		str(card.get("category", "")),
		road_type,
		str(encounter.get("type", "")),
		str(card.get("event_type", "")),
	])


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
	var level := int(config.get("level", 1))
	_add_enemy_encounters_to_road_cards(cards, rng, float(config.get("enemy_road_card_ratio", 0.0)), level)
	_add_reward_encounters_to_road_cards(cards, rng, float(config.get("reward_road_card_ratio", 0.0)), level)
	return cards


func _make_one_of_each_road(config: Dictionary) -> Array[Dictionary]:
	var definitions: Dictionary = config.get("road_definitions", {})
	var cards: Array[Dictionary] = []
	for subtype in ROAD_SUBTYPES:
		if definitions.has(subtype):
			cards.append(_make_road_card(definitions[subtype]))
	return cards


func _make_debug_enemy_roads(roads: Array[Dictionary], level: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var minimum_power := maxi(1, level) * 3 - 2
	for index in roads.size():
		var card: Dictionary = roads[index].duplicate(true)
		_set_card_encounter(card, {
			"type": ENCOUNTER_ENEMY,
			"revealed": false,
			"health": 1,
			"max_health": 1,
			"power": minimum_power + index % 3,
			"enemy_min_power": minimum_power,
		})
		card["detail"] = "Enemy waits on this road."
		cards.append(card)
	return cards


func _make_debug_reward_roads(roads: Array[Dictionary], level: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for road in roads:
		for reward_index in 2:
			var card: Dictionary = road.duplicate(true)
			_set_card_encounter(card, _make_reward_encounter(reward_index, rng, level))
			card["detail"] = _encounter_detail(card["encounter"])
			cards.append(card)
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


func _add_enemy_encounters_to_road_cards(cards: Array[Dictionary], rng: RandomNumberGenerator, enemy_ratio: float, level: int) -> void:
	var enemy_count := roundi(float(cards.size()) * enemy_ratio)
	_shuffle_cards(cards, rng)

	for index in mini(enemy_count, cards.size()):
		var card: Dictionary = cards[index]
		_set_card_encounter(card, _make_enemy_encounter(rng, level))
		card["detail"] = "Enemy waits on this road."
		cards[index] = card


func _make_enemy_encounter(rng: RandomNumberGenerator, level: int) -> Dictionary:
	var level_number := maxi(1, level)
	var enemy_max_power := level_number * 3
	var enemy_min_power := enemy_max_power - 2
	return {
		"type": ENCOUNTER_ENEMY,
		"revealed": false,
		"health": 1,
		"max_health": 1,
		"power": rng.randi_range(enemy_min_power, enemy_max_power),
		"enemy_min_power": enemy_min_power,
	}


func _add_reward_encounters_to_road_cards(cards: Array[Dictionary], rng: RandomNumberGenerator, reward_ratio: float, level: int) -> void:
	var reward_count := roundi(float(cards.size()) * reward_ratio)
	var eligible_indices: Array[int] = []
	for index in cards.size():
		if not cards[index].has("encounter"):
			eligible_indices.append(index)
	_shuffle_ints(eligible_indices, rng)

	for index in mini(reward_count, eligible_indices.size()):
		var card_index := eligible_indices[index]
		var card: Dictionary = cards[card_index]
		_set_card_encounter(card, _make_reward_encounter(index, rng, level))
		card["detail"] = _encounter_detail(card["encounter"])
		cards[card_index] = card


func _set_card_encounter(card: Dictionary, encounter: Dictionary) -> void:
	card["encounter"] = encounter
	var definition = card.get("card_definition")
	if definition is CARD_DEFINITION_SCRIPT:
		definition.encounter = encounter.duplicate(true)


func _make_reward_encounter(index: int, rng: RandomNumberGenerator, level: int) -> Dictionary:
	var reward_types: Array[String] = [GameMap.ENCOUNTER_BERRY_BUSH, GameMap.ENCOUNTER_CACHE]
	var kind: String = reward_types[index % reward_types.size()]
	if kind == GameMap.ENCOUNTER_BERRY_BUSH:
		return {
			"type": kind,
			"loot": [{"kind": "food", "amount": 3}],
		}
	return {
		"type": kind,
		"loot": [
			{
				"kind": "item",
				"item": WeaponCatalog.roll_weapon(rng, maxi(1, level) + 1, {
					0: 0.55,
					1: 0.30,
					2: 0.15,
				}),
			},
			{
				"kind": "gold",
				"amount": rng.randi_range(CACHE_GOLD_MIN, CACHE_GOLD_MAX),
			},
		],
	}


func _encounter_detail(encounter: Dictionary) -> String:
	var kind := str(encounter.get("type", ""))
	if kind == GameMap.ENCOUNTER_BERRY_BUSH:
		return "Plus food"
	if kind == GameMap.ENCOUNTER_CACHE:
		return "Plus treasure"
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
