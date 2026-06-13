class_name DeckRecipes
extends Resource

@export var base_deck: Dictionary = {}
@export var level_decks: Dictionary = {}


func get_base_deck() -> Dictionary:
	return base_deck


func get_level_deck(level: int) -> Dictionary:
	return level_decks.get(level, {})


func card_count(recipe: Dictionary) -> int:
	return _count_entries(recipe.get("roads", {})) \
		+ _count_entries(recipe.get("events", {}))


func base_card_count() -> int:
	return card_count(base_deck)


func level_card_count(level: int) -> int:
	return card_count(get_level_deck(level))


func _count_entries(entries: Dictionary) -> int:
	var total := 0
	for count in entries.values():
		total += int(count)
	return total
