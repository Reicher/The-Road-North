class_name ShopUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")
const ItemIconLibrary = preload("res://scripts/item_icon_library.gd")
const CARD_SCENE := preload("res://ui/card.tscn")
const ITEM_SLOT_SCENE := preload("res://ui/item_slot.tscn")

signal play_next_requested(progression: Dictionary)

const FOOD_PRICE := 4
const FOOD_AMOUNT := 5
const HEAL_PRICE := 5
const HEAL_AMOUNT := 2
const POWER_POTION_PRICE := 8
const MAX_HEALTH_POTION_PRICE := 10
const REMOVAL_BASE_PRICE := 12
const REMOVAL_PRICE_STEP := 6
const SLOT_SIZE := Vector2(82.0, 82.0)
const CARD_OFFER_SIZE := Vector2(200.0, 290.0)
const OFFER_ICON_SIZE := 42
const STAT_ICON_PATHS := GameConstants.STAT_ICON_PATHS
const PROTECTED_ROAD_TYPES := ["Straight Road", "Corner", "T-Junction"]

const ITEM_OFFERS: Array[Dictionary] = [
	{"name": "Dagger", "effect": "+2 Power", "power_bonus": 2, "price": 7, "sell_price": 4},
	{"name": "Machete", "effect": "+3 Power", "power_bonus": 3, "price": 12, "sell_price": 6},
]
const SPECIAL_CARD_CATALOG: Array[Dictionary] = [
	{"title": "It was all a dream", "detail": "Restart the current level.", "category": "Event", "event_type": "restart_level", "price": 22},
]
const CARD_OFFER_COUNT := 3

var progression: Dictionary = {}
var next_map_name := ""
var next_map_size := 0
var base_cards: Array[Dictionary] = []
var card_offers: Array[Dictionary] = []

var _gold_chip: StatChip
var _food_chip: StatChip
var _health_chip: StatChip
var _power_chip: StatChip
var _sell_zone: Button
var _slot_row: HBoxContainer
var _item_row: HBoxContainer
var _card_row: HBoxContainer
var _remove_button: Button
var _deck_overlay: DeckOverlay
var _drag_ghost: TextureRect
var _shop_scroll: ScrollContainer
var _shop_margin: MarginContainer
var _shop_stack: VBoxContainer
var _summary_panel: PanelContainer
var _buy_food_button: Button
var _buy_heal_button: Button
var _buy_power_button: Button
var _buy_max_health_button: Button
var _view_deck_button: Button
var _play_next_button: Button
var _drag_kind := ""
var _drag_index := -1
var _drag_item: Dictionary = {}
var _purchased_item_offers: Array[int] = []
var _purchased_card_offers: Array[int] = []


func _ready() -> void:
	resized.connect(_layout_shop)
	_bind_scene_nodes()
	_apply_styles()
	_layout_shop()
	_refresh()
	set_process_input(true)


func setup(next_progression: Dictionary, map_name: String, map_size: int, available_base_cards: Array) -> void:
	progression = next_progression.duplicate(true)
	next_map_name = map_name
	next_map_size = map_size
	base_cards.clear()
	for card in available_base_cards:
		if card is Dictionary:
			base_cards.append((card as Dictionary).duplicate(true))
	_roll_card_offers()
	if is_node_ready():
		_refresh()


func debug_add_gold(amount: int) -> void:
	progression["gold"] = int(progression.get("gold", 0)) + amount
	_refresh()


func buy_food() -> bool:
	if not _spend_gold(FOOD_PRICE):
		return false
	progression["food"] = int(progression.get("food", 0)) + FOOD_AMOUNT
	_refresh()
	return true


func buy_heal() -> bool:
	var health := int(progression.get("health", 0))
	var max_health := int(progression.get("max_health", 1))
	if health >= max_health or not _spend_gold(HEAL_PRICE):
		return false
	progression["health"] = mini(max_health, health + HEAL_AMOUNT)
	_refresh()
	return true


func buy_power_potion() -> bool:
	if not _spend_gold(POWER_POTION_PRICE):
		return false
	progression["pending_power_bonus"] = int(progression.get("pending_power_bonus", 0)) + 1
	_refresh()
	return true


func buy_max_health_potion() -> bool:
	if not _spend_gold(MAX_HEALTH_POTION_PRICE):
		return false
	progression["pending_max_health_bonus"] = int(progression.get("pending_max_health_bonus", 0)) + 1
	_refresh()
	return true


func buy_item_to_slot(offer_index: int, slot_index: int) -> bool:
	var inventory: Array = progression.get("inventory", [])
	if offer_index < 0 or offer_index >= ITEM_OFFERS.size() or slot_index < 0 or slot_index >= InventoryUI.SLOT_COUNT:
		return false
	if offer_index in _purchased_item_offers:
		return false
	if slot_index >= inventory.size() or not (inventory[slot_index] as Dictionary).is_empty():
		return false
	var offer := ITEM_OFFERS[offer_index]
	if not _spend_gold(int(offer["price"])):
		return false
	var item := offer.duplicate(true)
	item.erase("price")
	inventory[slot_index] = item
	progression["inventory"] = inventory
	_purchased_item_offers.append(offer_index)
	_refresh()
	return true


func sell_inventory_slot(slot_index: int) -> bool:
	var inventory: Array = progression.get("inventory", [])
	if slot_index < 0 or slot_index >= inventory.size():
		return false
	var item: Dictionary = inventory[slot_index]
	if item.is_empty():
		return false
	progression["gold"] = int(progression.get("gold", 0)) + int(item.get("sell_price", maxi(1, int(item.get("power_bonus", 1)) * 2)))
	inventory[slot_index] = {}
	progression["inventory"] = inventory
	_refresh()
	return true


func buy_special_card(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= card_offers.size():
		return false
	if offer_index in _purchased_card_offers:
		return false
	var offer := card_offers[offer_index]
	if not _spend_gold(int(offer["price"])):
		return false
	var card := offer.duplicate(true)
	card.erase("price")
	var cards: Array = progression.get("player_special_cards", [])
	cards.append(card)
	progression["player_special_cards"] = cards
	_purchased_card_offers.append(offer_index)
	_refresh()
	return true


func remove_base_card(card_index: int) -> bool:
	if bool(progression.get("removed_base_card_this_shop", false)):
		return false
	if card_index < 0 or card_index >= base_cards.size() or not _can_remove_card(base_cards[card_index]):
		return false
	if not _spend_gold(_removal_price()):
		return false
	var removals: Array = progression.get("player_removed_base_cards", [])
	removals.append(GameConstants.card_signature(base_cards[card_index]))
	progression["player_removed_base_cards"] = removals
	progression["removed_base_card_this_shop"] = true
	base_cards.remove_at(card_index)
	_refresh()
	_show_deck_overlay(true)
	return true


func _bind_scene_nodes() -> void:
	_shop_scroll = $ShopScroll as ScrollContainer
	_shop_margin = $ShopScroll/ShopMargin as MarginContainer
	_shop_stack = $ShopScroll/ShopMargin/ShopStack as VBoxContainer
	_summary_panel = $ShopScroll/ShopMargin/ShopStack/SummaryPanel as PanelContainer
	_gold_chip = $ShopScroll/ShopMargin/ShopStack/SummaryPanel/SummaryMargin/SummaryStack/ResourceRow/GoldChip as StatChip
	_food_chip = $ShopScroll/ShopMargin/ShopStack/SummaryPanel/SummaryMargin/SummaryStack/ResourceRow/FoodChip as StatChip
	_health_chip = $ShopScroll/ShopMargin/ShopStack/SummaryPanel/SummaryMargin/SummaryStack/ResourceRow/HealthChip as StatChip
	_power_chip = $ShopScroll/ShopMargin/ShopStack/SummaryPanel/SummaryMargin/SummaryStack/ResourceRow/PowerChip as StatChip
	_sell_zone = $ShopScroll/ShopMargin/ShopStack/InventoryLine/SellZone as Button
	_slot_row = $ShopScroll/ShopMargin/ShopStack/InventoryLine/InventoryStack/InventorySlots as HBoxContainer
	_item_row = $ShopScroll/ShopMargin/ShopStack/ItemRow as HBoxContainer
	_buy_food_button = $ShopScroll/ShopMargin/ShopStack/SurvivalRow/BuyFoodButton as Button
	_buy_heal_button = $ShopScroll/ShopMargin/ShopStack/SurvivalRow/BuyHealButton as Button
	_buy_power_button = $ShopScroll/ShopMargin/ShopStack/PotionsRow/BuyPowerButton as Button
	_buy_max_health_button = $ShopScroll/ShopMargin/ShopStack/PotionsRow/BuyMaxHealthButton as Button
	_card_row = $ShopScroll/ShopMargin/ShopStack/CardOffers as HBoxContainer
	_remove_button = $ShopScroll/ShopMargin/ShopStack/DeckRow/RemoveButton as Button
	_view_deck_button = $ShopScroll/ShopMargin/ShopStack/DeckRow/ViewDeckButton as Button
	_play_next_button = $ShopScroll/ShopMargin/ShopStack/PlayNextButton as Button
	_deck_overlay = $DeckOverlay as DeckOverlay
	_drag_ghost = $DragGhost as TextureRect

	_buy_food_button.pressed.connect(buy_food)
	_buy_heal_button.pressed.connect(buy_heal)
	_buy_power_button.pressed.connect(buy_power_potion)
	_buy_max_health_button.pressed.connect(buy_max_health_potion)
	_remove_button.pressed.connect(func() -> void: _show_deck_overlay(true))
	_view_deck_button.pressed.connect(func() -> void: _show_deck_overlay(false))
	_play_next_button.pressed.connect(func() -> void:
		progression.erase("removed_base_card_this_shop")
		play_next_requested.emit(progression.duplicate(true))
	)


func _apply_styles() -> void:
	_summary_panel.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self)))
	_sell_zone.add_theme_stylebox_override("normal", UIStyle.elevated_box(self, Color(0.56, 0.22, 0.16), Color(0.94, 0.62, 0.30), 12, 3))
	_apply_button_icon(_buy_food_button, "food")
	_apply_button_icon(_buy_heal_button, "health")
	_apply_button_icon(_buy_power_button, "power")
	_apply_button_icon(_buy_max_health_button, "health")
	_apply_button_icon(_remove_button, "deck")
	_apply_button_icon(_view_deck_button, "deck")


func _layout_shop() -> void:
	if _shop_scroll == null or _shop_margin == null:
		return
	var available_size := _shop_scroll.size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		available_size = size - Vector2(36.0, 36.0)
	_shop_margin.custom_minimum_size = Vector2(
		maxf(1.0, available_size.x),
		maxf(_shop_margin.get_combined_minimum_size().y, available_size.y)
	)


func _refresh() -> void:
	if _gold_chip == null:
		return
	_gold_chip.set_value("%d" % int(progression.get("gold", 0)))
	_play_next_button.text = "Play next map: \"%s\" (%dx%d)" % [next_map_name, next_map_size, next_map_size]
	_food_chip.set_value("%d" % int(progression.get("food", 0)))
	var pending_max_hp := int(progression.get("pending_max_health_bonus", 0))
	var max_hp := int(progression.get("max_health", 1)) + pending_max_hp
	var hp := int(progression.get("health", 0))
	_health_chip.set_value("%d/%d" % [hp, max_hp])
	var pending_power := int(progression.get("pending_power_bonus", 0))
	var total_power := int(progression.get("base_power", 0)) + _inventory_power() + pending_power
	_power_chip.set_value("%d" % total_power)
	_refresh_inventory_slots()
	_refresh_offers()
	_remove_button.text = "Remove base card / %dg" % _removal_price()
	_remove_button.disabled = bool(progression.get("removed_base_card_this_shop", false))


func _refresh_inventory_slots() -> void:
	_clear_children(_slot_row)
	var inventory: Array = progression.get("inventory", [])
	while inventory.size() < InventoryUI.SLOT_COUNT:
		inventory.append({})
	progression["inventory"] = inventory
	for index in InventoryUI.SLOT_COUNT:
		var slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		slot.slot_size = SLOT_SIZE
		var item: Dictionary = inventory[index]
		slot.configure(item, index)
		slot.slot_gui_input.connect(_on_slot_gui_input)
		_slot_row.add_child(slot)


func _refresh_offers() -> void:
	_clear_children(_item_row)
	for index in ITEM_OFFERS.size():
		var offer := ITEM_OFFERS[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 24)
		button.text = "%s\n%s / %dg" % [offer["name"], offer["effect"], offer["price"]]
		button.icon = ItemIconLibrary.get_icon(offer)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", OFFER_ICON_SIZE)
		button.disabled = index in _purchased_item_offers
		button.gui_input.connect(_on_item_offer_input.bind(index, button))
		_item_row.add_child(button)
	_clear_children(_card_row)
	for index in card_offers.size():
		var offer := card_offers[index]
		var offer_stack := VBoxContainer.new()
		offer_stack.name = "CardOffer%d" % (index + 1)
		offer_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		offer_stack.add_theme_constant_override("separation", 4)
		var card := CARD_SCENE.instantiate() as CardView
		card.name = "Card"
		card.custom_minimum_size = CARD_OFFER_SIZE
		card.size = CARD_OFFER_SIZE
		card.pivot_offset = CARD_OFFER_SIZE * 0.5
		card.configure(offer)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.pointer_released.connect(func(_card: CardView, _position: Vector2) -> void:
			buy_special_card(index)
		)
		var buy_button := _button("Buy / %dg" % int(offer["price"]), buy_special_card.bind(index))
		buy_button.name = "BuyButton"
		buy_button.add_theme_font_size_override("font_size", 24)
		_apply_button_icon(buy_button, "gold")
		buy_button.disabled = index in _purchased_card_offers
		if buy_button.disabled:
			card.modulate = Color(0.55, 0.55, 0.55, 0.72)
			(card.get_node("TouchButton") as Button).disabled = true
		offer_stack.add_child(card)
		offer_stack.add_child(buy_button)
		_card_row.add_child(offer_stack)


func _roll_card_offers() -> void:
	card_offers.clear()
	if SPECIAL_CARD_CATALOG.is_empty():
		return
	# Use gold as a lightweight seed so the same state produces the same offers
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(int(progression.get("gold", 0)) * 31 + int(progression.get("food", 0)) * 7)
	for _index in CARD_OFFER_COUNT:
		var offer_index := rng.randi_range(0, SPECIAL_CARD_CATALOG.size() - 1)
		card_offers.append(SPECIAL_CARD_CATALOG[offer_index].duplicate(true))


func _show_deck_overlay(removal_mode: bool) -> void:
	_deck_overlay.clear_list()
	var title_text := "Remove BaseDeck card" if removal_mode else "View deck"
	for index in base_cards.size():
		var card := base_cards[index]
		var text := GameConstants.card_signature(card).trim_prefix("road:").trim_prefix("event:")
		var disabled_state := not removal_mode or not _can_remove_card(card) or bool(progression.get("removed_base_card_this_shop", false))
		var callback := remove_base_card.bind(index) if removal_mode else Callable()
		_deck_overlay.add_list_button(text, disabled_state, callback)
	if not removal_mode:
		for card in progression.get("player_special_cards", []):
			_deck_overlay.add_list_label("Special: %s" % GameConstants.card_signature(card as Dictionary).trim_prefix("road:").trim_prefix("event:"), 18)
		_deck_overlay.add_list_label("Level cards added next map.", 18)
	_deck_overlay.show_overlay(title_text)


func _can_remove_card(card: Dictionary) -> bool:
	var definition: Resource = card.get("tile_definition")
	if definition == null:
		return true
	var road_name := str(definition.get("display_name"))
	if road_name not in PROTECTED_ROAD_TYPES:
		return true
	var count := 0
	for candidate in base_cards:
		if GameConstants.card_signature(candidate) == GameConstants.card_signature(card):
			count += 1
	return count > 1


func _input(event: InputEvent) -> void:
	if _drag_kind.is_empty():
		return
	if event is InputEventMouseMotion:
		_move_drag(event.position)
	elif event is InputEventScreenDrag:
		_move_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_drag(event.position)


func _on_slot_gui_input(event: InputEvent, slot: ItemSlot) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_drag("inventory", slot.slot_index, progression["inventory"][slot.slot_index], slot.get_global_rect().get_center())
	elif event is InputEventScreenTouch and event.pressed:
		_start_drag("inventory", slot.slot_index, progression["inventory"][slot.slot_index], event.position)


func _on_item_offer_input(event: InputEvent, index: int, button: Button) -> void:
	if index in _purchased_item_offers:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_drag("offer", index, ITEM_OFFERS[index], button.get_global_rect().get_center())
	elif event is InputEventScreenTouch and event.pressed:
		_start_drag("offer", index, ITEM_OFFERS[index], event.position)


func _start_drag(kind: String, index: int, item: Dictionary, position: Vector2) -> void:
	if item.is_empty():
		return
	_drag_kind = kind
	_drag_index = index
	_drag_item = item
	_drag_ghost.texture = ItemIconLibrary.get_icon(item)
	_drag_ghost.visible = true
	_move_drag(position)


func _move_drag(position: Vector2) -> void:
	_drag_ghost.position = position - _drag_ghost.size * 0.5
	if _drag_kind == "inventory" and _sell_zone.get_global_rect().has_point(position):
		_sell_zone.text = "SELL\n+%dg" % int(_drag_item.get("sell_price", maxi(1, int(_drag_item.get("power_bonus", 1)) * 2)))
	else:
		_sell_zone.text = "SELL"


func _finish_drag(position: Vector2) -> void:
	if _drag_kind == "inventory" and _sell_zone.get_global_rect().has_point(position):
		sell_inventory_slot(_drag_index)
	elif _drag_kind == "offer":
		var target := _slot_at(position)
		if target >= 0:
			buy_item_to_slot(_drag_index, target)
	_drag_kind = ""
	_drag_index = -1
	_drag_item = {}
	_drag_ghost.visible = false
	_sell_zone.text = "SELL"


func _slot_at(position: Vector2) -> int:
	for index in _slot_row.get_child_count():
		var slot := _slot_row.get_child(index) as Control
		if slot.get_global_rect().has_point(position):
			return index
	return -1


func _spend_gold(price: int) -> bool:
	var gold := int(progression.get("gold", 0))
	if gold < price:
		_flash_cannot_afford()
		return false
	progression["gold"] = gold - price
	return true


func _flash_cannot_afford() -> void:
	if _gold_chip == null:
		return
	var tween := create_tween()
	tween.tween_property(_gold_chip, "modulate", Color(1.0, 0.3, 0.3), 0.1)
	tween.tween_property(_gold_chip, "modulate", Color.WHITE, 0.3)


func _removal_price() -> int:
	return REMOVAL_BASE_PRICE + int(progression.get("player_removed_base_cards", []).size()) * REMOVAL_PRICE_STEP


func _inventory_power() -> int:
	var highest := 0
	for item in progression.get("inventory", []):
		highest = maxi(highest, int((item as Dictionary).get("power_bonus", 0)))
	return highest


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text
	button.pressed.connect(callback)
	return button


func _apply_button_icon(button: Button, stat_name: String) -> void:
	button.icon = _load_stat_icon(stat_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", OFFER_ICON_SIZE)


func _load_stat_icon(stat_name: String) -> Texture2D:
	return load(str(STAT_ICON_PATHS.get(stat_name, ""))) as Texture2D


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
