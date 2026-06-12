class_name WeaponCatalog
extends RefCounted

const WEAPONS: Array[Dictionary] = [
	{"name": "Walking Stick", "power_bonus": 1},
	{"name": "Dagger", "power_bonus": 2},
	{"name": "Hatchet", "power_bonus": 3},
	{"name": "Machete", "power_bonus": 4},
	{"name": "Sword", "power_bonus": 5},
	{"name": "Mace", "power_bonus": 6},
	{"name": "Spear", "power_bonus": 7},
	{"name": "Sword & Shield", "power_bonus": 8},
	{"name": "Great Axe", "power_bonus": 9},
]


static func make_weapon(power_bonus: int) -> Dictionary:
	var matching_weapons := _weapons_with_power_bonus(power_bonus)
	if matching_weapons.is_empty():
		return {}
	return _with_effect(matching_weapons[0])


static func roll_weapon(rng: RandomNumberGenerator, target_power: int, power_weights: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for power_offset in power_weights:
		var matching_weapons := _weapons_with_power_bonus(target_power + int(power_offset))
		if matching_weapons.is_empty():
			continue
		var weight := float(power_weights[power_offset])
		if weight <= 0.0:
			continue
		candidates.append({
			"weapons": matching_weapons,
			"weight": weight,
		})
		total_weight += weight

	if candidates.is_empty() or total_weight <= 0.0:
		return _closest_weapon(target_power, rng)

	var roll := rng.randf() * total_weight
	for candidate in candidates:
		roll -= float(candidate["weight"])
		if roll <= 0.0:
			return _random_weapon(candidate["weapons"], rng)
	return _random_weapon(candidates.back()["weapons"], rng)


static func _weapons_with_power_bonus(power_bonus: int) -> Array[Dictionary]:
	var matching_weapons: Array[Dictionary] = []
	for weapon in WEAPONS:
		if int(weapon.get("power_bonus", 0)) == power_bonus:
			matching_weapons.append(weapon)
	return matching_weapons


static func _random_weapon(weapons: Array, rng: RandomNumberGenerator) -> Dictionary:
	var weapon: Dictionary = weapons[rng.randi_range(0, weapons.size() - 1)]
	return _with_effect(weapon)


static func _closest_weapon(target_power: int, rng: RandomNumberGenerator) -> Dictionary:
	var closest_distance := 2147483647
	var closest_weapons: Array[Dictionary] = []
	for weapon in WEAPONS:
		var distance := absi(int(weapon.get("power_bonus", 0)) - target_power)
		if distance < closest_distance:
			closest_distance = distance
			closest_weapons.clear()
		if distance == closest_distance:
			closest_weapons.append(weapon)
	if closest_weapons.is_empty():
		return {}
	return _random_weapon(closest_weapons, rng)


static func _with_effect(weapon: Dictionary) -> Dictionary:
	var result := weapon.duplicate(true)
	result["effect"] = "+%d Power" % int(result.get("power_bonus", 0))
	return result
