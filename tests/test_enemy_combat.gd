extends SceneTree

const MAP_SCENE := preload("res://scenes/map.tscn")
const ROADS_SCRIPT := preload("res://scripts/roads.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STRAIGHT := preload("res://data/road_straight.tres")
const T_JUNCTION := preload("res://data/road_t_junction.tres")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var root := Node2D.new()
	get_root().add_child(root)
	var map := MAP_SCENE.instantiate() as GameMap
	map.name = "Map"
	root.add_child(map)
	var roads := ROADS_SCRIPT.new() as Roads
	roads.name = "Roads"
	roads.map_path = NodePath("../Map")
	roads.seed_start_and_goal = false
	root.add_child(roads)
	roads._ready()
	roads.force_place_tile(Vector2i(4, 8), T_JUNCTION, 0)
	_assert(roads.place_tile(Vector2i(4, 7), STRAIGHT, 0, {"type": GameMap.ENCOUNTER_ENEMY, "power": 1}), "Expected enemy tile placement")

	var player := PLAYER_SCENE.instantiate() as GamePlayer
	player.name = "Player"
	player.map_path = NodePath("../Map")
	player.start_position = Vector2i(4, 8)
	player.starting_food = 4
	player.starting_health = 3
	player.starting_max_health = 3
	player.base_power = 1
	player.move_duration = 0.0
	player.combat_roll_duration = 0.05
	root.add_child(player)
	player._ready()
	var popup := player.get_node("CombatPopupLayer/CombatPopup") as CombatOverlay

	player.queue_combat_rolls(1, 6)
	player.queue_combat_rolls(3, 3)
	player.queue_combat_rolls(6, 1)
	_assert(player.move_to(Vector2i(4, 7)), "Expected enemy movement to start combat")
	await process_frame
	_assert(player.grid_position == Vector2i(4, 7), "Expected player to walk onto enemy tile before combat")
	_assert(player.food == 3, "Expected entering enemy tile to cost one food immediately")
	_assert(popup.visible and popup.mouse_filter == Control.MOUSE_FILTER_STOP, "Expected blocking combat popup")
	_assert((popup.get_node("Dimmer") as ColorRect).color.a == 0.0, "Expected combat popup not to tint the map or resource UI")
	_assert(int(popup.get_node("Panel/Margin/Stack/Calculation/Fighters/Player/DiceRow/Dice").get("value")) == 0, "Expected unknown player die before first roll")
	_assert(_label(popup, "Panel/Margin/Stack/Totals/EnemySum").text == "?", "Expected unknown enemy total before first roll")
	_assert(_label(popup, "Panel/Margin/Stack/Calculation/Fighters/VS").text == "VS", "Expected VS between fighter columns")
	_assert((popup.get_node("Panel/Margin/Stack/Calculation/Fighters/Player/Power/Icon") as TextureRect).texture == load("res://assets/images/stats/stat_power.png"), "Expected player power symbol")
	_assert(_label(popup, "Panel/Margin/Stack/Calculation/Fighters/Player/Power/Value").text == "1", "Expected player power number without text prefix")
	_assert(_label(popup, "Panel/Margin/Stack/Calculation/Fighters/Player/DiceRow/Plus").text == "+", "Expected plus sign beside player die")
	_assert((popup.get_node("Panel/Margin/Stack/Calculation/SumLine") as ColorRect).custom_minimum_size.y >= 5.0, "Expected visible full-width sum line")
	var player_column := popup.get_node("Panel/Margin/Stack/Calculation/Fighters/Player") as Control
	var enemy_column := popup.get_node("Panel/Margin/Stack/Calculation/Fighters/Enemy") as Control
	var player_sum := _label(popup, "Panel/Margin/Stack/Totals/PlayerSum")
	var enemy_sum := _label(popup, "Panel/Margin/Stack/Totals/EnemySum")
	_assert(is_equal_approx(player_column.get_global_rect().get_center().x, player_sum.get_global_rect().get_center().x), "Expected player total centered under player column")
	_assert(is_equal_approx(enemy_column.get_global_rect().get_center().x, enemy_sum.get_global_rect().get_center().x), "Expected enemy total centered under enemy column")
	_assert((popup.get_node("TitleBanner") as PanelContainer).offset_top < (popup.get_node("Panel") as PanelContainer).offset_top, "Expected title banner to break above main panel border")
	_assert(_button(popup, "Panel/Margin/Stack/Buttons/FightButton").visible, "Expected Fight button before first roll")
	_assert(_button(popup, "Panel/Margin/Stack/Buttons/RetreatButton").visible, "Expected Retreat button before first roll")

	await process_frame
	_button(popup, "Panel/Margin/Stack/Buttons/FightButton").pressed.emit()
	await _wait_until(func() -> bool: return _button(popup, "Panel/Margin/Stack/Buttons/FightButton").disabled)
	_assert(popup.get_node("Panel/Margin/Stack/Buttons").visible, "Expected buttons to remain visible while rolling")
	_assert(_button(popup, "Panel/Margin/Stack/Buttons/FightButton").disabled and _button(popup, "Panel/Margin/Stack/Buttons/RetreatButton").disabled, "Expected buttons disabled while rolling")
	await _wait_until(func() -> bool: return _label(popup, "Panel/Margin/Stack/Totals/Result").text == "Defeat")
	_assert(player.health == 2, "Expected defeat to deal exactly one health")
	_assert(_label(popup, "Panel/Margin/Stack/Totals/ResultDetail").text == "-1 HP", "Expected defeat result to show health loss")
	_assert(_label(popup, "Panel/Margin/Stack/Totals/ResultDetail").get_theme_font_size("font_size") >= 21, "Expected defeat health loss text to be prominent")
	_assert(int(popup.get_node("Panel/Margin/Stack/Calculation/Fighters/Player/DiceRow/Dice").get("value")) == 1, "Expected player die to show rolled pips")
	_assert(_label(popup, "Panel/Margin/Stack/Totals/PlayerSum").text == "2", "Expected total without equals sign")
	_assert(player.is_in_combat() and popup.visible, "Expected defeat to keep combat open")
	_assert(_button(popup, "Panel/Margin/Stack/Buttons/FightButton").visible, "Expected Fight to remain after defeat")
	_assert(_button(popup, "Panel/Margin/Stack/Buttons/RetreatButton").visible, "Expected Retreat to remain after defeat")

	_button(popup, "Panel/Margin/Stack/Buttons/FightButton").pressed.emit()
	await _wait_until(func() -> bool: return _label(popup, "Panel/Margin/Stack/Totals/Result").text == "Tie")
	_assert(player.health == 2, "Expected tie not to deal damage")
	_assert(player.food == 3, "Expected repeated fights not to cost food")

	_button(popup, "Panel/Margin/Stack/Buttons/FightButton").pressed.emit()
	await _wait_until(func() -> bool: return _label(popup, "Panel/Margin/Stack/Totals/Result").text == "Victory")
	await _wait_until(func() -> bool: return not _button(popup, "Panel/Margin/Stack/OKButton").disabled)
	_assert(map.get_encounter(Vector2i(4, 7)).is_empty(), "Expected victory to remove enemy before OK")
	_assert(_button(popup, "Panel/Margin/Stack/OKButton").visible, "Expected victory to replace combat buttons with OK")
	_assert(not popup.get_node("Panel/Margin/Stack/Buttons").visible, "Expected Fight and Retreat hidden after victory")
	_button(popup, "Panel/Margin/Stack/OKButton").pressed.emit()
	await _wait_until(func() -> bool: return not player.is_in_combat())
	_assert(player.grid_position == Vector2i(4, 7) and player.food == 3, "Expected victory to leave player on enemy tile without another food cost")

	_assert(roads.place_tile(Vector2i(4, 6), STRAIGHT, 0, {"type": GameMap.ENCOUNTER_ENEMY, "power": 2}), "Expected second enemy placement")
	player.queue_combat_rolls(1, 6)
	_assert(player.move_to(Vector2i(4, 6)), "Expected second combat to start")
	await process_frame
	_assert(player.food == 2 and player.grid_position == Vector2i(4, 6), "Expected second combat movement to cost food and enter tile")
	_button(popup, "Panel/Margin/Stack/Buttons/RetreatButton").pressed.emit()
	await _wait_until(func() -> bool: return not player.is_in_combat())
	_assert(player.grid_position == Vector2i(4, 7), "Expected retreat to return to previous tile")
	_assert(player.food == 2, "Expected retreat not to cost additional food")
	_assert(not map.get_encounter(Vector2i(4, 6)).is_empty(), "Expected retreat to leave enemy unchanged")

	player.set_health(1)
	var died := {"value": false}
	player.game_over.connect(func(reason: String) -> void: died["value"] = reason == "health")
	player.queue_combat_rolls(1, 6)
	_assert(player.move_to(Vector2i(4, 6)), "Expected lethal combat to start")
	await process_frame
	_button(popup, "Panel/Margin/Stack/Buttons/FightButton").pressed.emit()
	await _wait_until(func() -> bool: return bool(died["value"]))
	_assert(not popup.visible, "Expected lethal defeat to close combat popup immediately")
	_assert(not map.get_encounter(Vector2i(4, 6)).is_empty(), "Expected lethal defeat to leave enemy unchanged")

	quit()


func _label(root: Node, path: String) -> Label:
	return root.get_node(path) as Label


func _button(root: Node, path: String) -> Button:
	return root.get_node(path) as Button


func _wait_until(predicate: Callable) -> void:
	while not predicate.call():
		await process_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
