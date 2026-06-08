class_name ShopUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")
const ItemIconLibrary = preload("res://scripts/item_icon_library.gd")
const CARD_SCENE := preload("res://ui/card.tscn")

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
const CARD_OFFER_SIZE := Vector2(174.0, 250.0)
const STAT_ICON_SIZE := Vector2(38.0, 38.0)
const OFFER_ICON_SIZE := 42
const STAT_ICON_PATHS := {
	"food": "res://assets/images/stat_food.png",
	"gold": "res://assets/images/stat_gold.png",
	"health": "res://assets/images/stat_health.png",
	"power": "res://assets/images/stat_power.png",
	"deck": "res://assets/images/stat_deck.png",
}
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

var _gold_label: Label
var _next_label: Label
var _food_label: Label
var _health_label: Label
var _power_label: Label
var _sell_zone: Button
var _slot_row: HBoxContainer
var _item_row: HBoxContainer
var _card_row: HBoxContainer
var _remove_button: Button
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_list: VBoxContainer
var _drag_ghost: TextureRect
var _shop_scroll: ScrollContainer
var _shop_margin: MarginContainer
var _shop_stack: VBoxContainer
var _drag_kind := ""
var _drag_index := -1
var _drag_item: Dictionary = {}
var _purchased_item_offers: Array[int] = []
var _purchased_card_offers: Array[int] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_shop)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
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
	removals.append(card_signature(base_cards[card_index]))
	progression["player_removed_base_cards"] = removals
	progression["removed_base_card_this_shop"] = true
	base_cards.remove_at(card_index)
	_refresh()
	_show_deck_overlay(true)
	return true


static func card_signature(card: Dictionary) -> String:
	var definition: Resource = card.get("tile_definition")
	if definition != null:
		return "road:%s" % str(definition.get("display_name"))
	return "event:%s" % str(card.get("event_type", card.get("title", "")))


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.08, 0.07, 0.05, 0.96)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_shop_scroll = ScrollContainer.new()
	_shop_scroll.name = "ShopScroll"
	_shop_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_scroll.offset_left = 18.0
	_shop_scroll.offset_top = 18.0
	_shop_scroll.offset_right = -18.0
	_shop_scroll.offset_bottom = -18.0
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_shop_scroll)
	_shop_margin = MarginContainer.new()
	_shop_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_margin.add_theme_constant_override("margin_left", 18)
	_shop_margin.add_theme_constant_override("margin_right", 18)
	_shop_margin.add_theme_constant_override("margin_top", 16)
	_shop_margin.add_theme_constant_override("margin_bottom", 16)
	_shop_scroll.add_child(_shop_margin)
	_shop_stack = VBoxContainer.new()
	_shop_stack.name = "ShopStack"
	_shop_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_stack.add_theme_constant_override("separation", 12)
	_shop_margin.add_child(_shop_stack)

	var summary_panel := PanelContainer.new()
	summary_panel.name = "SummaryPanel"
	summary_panel.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self)))
	_shop_stack.add_child(summary_panel)
	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 16)
	summary_margin.add_theme_constant_override("margin_right", 16)
	summary_margin.add_theme_constant_override("margin_top", 12)
	summary_margin.add_theme_constant_override("margin_bottom", 12)
	summary_panel.add_child(summary_margin)
	var summary_stack := VBoxContainer.new()
	summary_stack.add_theme_constant_override("separation", 8)
	summary_margin.add_child(summary_stack)
	var heading := HBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _label("SHOP", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", UIStyle.text(self))
	heading.add_child(title)
	var gold_chip := _stat_chip("gold")
	_gold_label = gold_chip.get_node("Value") as Label
	heading.add_child(gold_chip)
	summary_stack.add_child(heading)
	_next_label = _label("", 20)
	_next_label.add_theme_color_override("font_color", UIStyle.muted_text(self))
	summary_stack.add_child(_next_label)
	var stat_row := HBoxContainer.new()
	stat_row.name = "ResourceSummary"
	stat_row.add_theme_constant_override("separation", 8)
	for stat_name in ["food", "health", "power"]:
		var chip := _stat_chip(stat_name)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_row.add_child(chip)
		var value_label := chip.get_node("Value") as Label
		if stat_name == "food":
			_food_label = value_label
		elif stat_name == "health":
			_health_label = value_label
		else:
			_power_label = value_label
	summary_stack.add_child(stat_row)

	var inventory_line := HBoxContainer.new()
	inventory_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_line.add_theme_constant_override("separation", 8)
	_sell_zone = Button.new()
	_sell_zone.name = "SellZone"
	_sell_zone.custom_minimum_size = Vector2(130, SLOT_SIZE.y)
	_sell_zone.text = "SELL"
	_sell_zone.add_theme_font_size_override("font_size", 20)
	_sell_zone.add_theme_stylebox_override("normal", UIStyle.elevated_box(self, Color(0.56, 0.22, 0.16), Color(0.94, 0.62, 0.30), 12, 3))
	_sell_zone.add_theme_color_override("font_color", Color(1.0, 0.93, 0.76))
	inventory_line.add_child(_sell_zone)
	var inventory_stack := VBoxContainer.new()
	inventory_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inventory_title := _label("Inventory", 18)
	inventory_title.name = "InventoryTitle"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_stack.add_child(inventory_title)
	_slot_row = HBoxContainer.new()
	_slot_row.name = "InventorySlots"
	_slot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_row.alignment = BoxContainer.ALIGNMENT_END
	_slot_row.add_theme_constant_override("separation", 6)
	inventory_stack.add_child(_slot_row)
	inventory_line.add_child(inventory_stack)
	_shop_stack.add_child(inventory_line)

	_add_section_title(_shop_stack, "Items - drag to empty slot")
	_item_row = HBoxContainer.new()
	_item_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_row.add_theme_constant_override("separation", 10)
	_shop_stack.add_child(_item_row)

	_add_section_title(_shop_stack, "Survival")
	var survival := HBoxContainer.new()
	survival.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	survival.add_theme_constant_override("separation", 10)
	survival.add_child(_resource_button("+5\n4g", "food", buy_food))
	survival.add_child(_resource_button("+2\n5g", "health", buy_heal))
	_shop_stack.add_child(survival)

	_add_section_title(_shop_stack, "Potions - next map only")
	var potions := HBoxContainer.new()
	potions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potions.add_theme_constant_override("separation", 10)
	potions.add_child(_resource_button("+1 next map\n8g", "power", buy_power_potion))
	potions.add_child(_resource_button("+1 next map\n10g", "health", buy_max_health_potion))
	_shop_stack.add_child(potions)

	_add_section_title(_shop_stack, "Cards")
	_card_row = HBoxContainer.new()
	_card_row.name = "CardOffers"
	_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_row.add_theme_constant_override("separation", 10)
	_shop_stack.add_child(_card_row)
	_add_section_title(_shop_stack, "Deck")
	var deck_row := HBoxContainer.new()
	deck_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_row.add_theme_constant_override("separation", 10)
	_remove_button = _button("", func() -> void: _show_deck_overlay(true))
	_apply_button_icon(_remove_button, "deck")
	deck_row.add_child(_remove_button)
	var view_deck_button := _button("View deck", func() -> void: _show_deck_overlay(false))
	_apply_button_icon(view_deck_button, "deck")
	deck_row.add_child(view_deck_button)
	_shop_stack.add_child(deck_row)
	var bottom_spacer := Control.new()
	bottom_spacer.name = "BottomSpacer"
	bottom_spacer.custom_minimum_size.y = 8.0
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_stack.add_child(bottom_spacer)
	var play_button := _button("Play next map", func() -> void:
		progression.erase("removed_base_card_this_shop")
		play_next_requested.emit(progression.duplicate(true))
	)
	play_button.name = "PlayNextButton"
	play_button.custom_minimum_size.y = 58
	_shop_stack.add_child(play_button)

	_build_overlay()
	_drag_ghost = TextureRect.new()
	_drag_ghost.visible = false
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_ghost.size = SLOT_SIZE
	_drag_ghost.z_index = 100
	add_child(_drag_ghost)


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


func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.name = "DeckOverlay"
	_overlay.visible = false
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	_overlay.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self)))
	add_child(_overlay)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	_overlay.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_overlay_title = _label("Deck", 24)
	stack.add_child(_overlay_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	_overlay_list = VBoxContainer.new()
	_overlay_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_overlay_list)
	stack.add_child(_button("Close", func() -> void: _overlay.visible = false))


func _refresh() -> void:
	if _gold_label == null:
		return
	_gold_label.text = "%d" % int(progression.get("gold", 0))
	_next_label.text = "Next: %s %dx%d" % [next_map_name, next_map_size, next_map_size]
	_food_label.text = "%d" % int(progression.get("food", 0))
	_health_label.text = "%d/%d" % [int(progression.get("health", 0)), int(progression.get("max_health", 1))]
	_power_label.text = "%d" % (int(progression.get("base_power", 0)) + _inventory_power())
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
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		var item: Dictionary = inventory[index]
		slot.disabled = item.is_empty()
		slot.icon = ItemIconLibrary.get_icon(item) if not item.is_empty() else null
		slot.expand_icon = true
		slot.tooltip_text = "%s\n%s" % [item.get("name", "Empty"), item.get("effect", "")]
		slot.gui_input.connect(_on_inventory_slot_input.bind(index, slot))
		_slot_row.add_child(slot)


func _refresh_offers() -> void:
	_clear_children(_item_row)
	for index in ITEM_OFFERS.size():
		var offer := ITEM_OFFERS[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		offer_stack.add_theme_constant_override("separation", 6)
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
	for _index in CARD_OFFER_COUNT:
		card_offers.append(SPECIAL_CARD_CATALOG.pick_random().duplicate(true))


func _show_deck_overlay(removal_mode: bool) -> void:
	_clear_children(_overlay_list)
	_overlay_title.text = "Remove BaseDeck card" if removal_mode else "View deck"
	for index in base_cards.size():
		var card := base_cards[index]
		var button := Button.new()
		button.text = card_signature(card).trim_prefix("road:").trim_prefix("event:")
		button.disabled = not removal_mode or not _can_remove_card(card) or bool(progression.get("removed_base_card_this_shop", false))
		if removal_mode:
			button.pressed.connect(remove_base_card.bind(index))
		_overlay_list.add_child(button)
	if not removal_mode:
		for card in progression.get("player_special_cards", []):
			var label := _label("Special: %s" % card_signature(card as Dictionary).trim_prefix("road:").trim_prefix("event:"), 16)
			_overlay_list.add_child(label)
		_overlay_list.add_child(_label("LevelDeck cards are added by the next map.", 15))
	_overlay.visible = true


func _can_remove_card(card: Dictionary) -> bool:
	var definition: Resource = card.get("tile_definition")
	if definition == null:
		return true
	var road_name := str(definition.get("display_name"))
	if road_name not in PROTECTED_ROAD_TYPES:
		return true
	var count := 0
	for candidate in base_cards:
		if card_signature(candidate) == card_signature(card):
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


func _on_inventory_slot_input(event: InputEvent, index: int, button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_drag("inventory", index, progression["inventory"][index], button.get_global_rect().get_center())
	elif event is InputEventScreenTouch and event.pressed:
		_start_drag("inventory", index, progression["inventory"][index], event.position)


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
		return false
	progression["gold"] = gold - price
	return true


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


func _resource_button(text: String, stat_name: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.custom_minimum_size.y = 64.0
	_apply_button_icon(button, stat_name)
	return button


func _apply_button_icon(button: Button, stat_name: String) -> void:
	button.icon = _load_stat_icon(stat_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", OFFER_ICON_SIZE)


func _stat_chip(stat_name: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.name = "%sChip" % stat_name.capitalize()
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = STAT_ICON_SIZE
	icon.texture = _load_stat_icon(stat_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	var value := _label("", 22)
	value.name = "Value"
	value.add_theme_color_override("font_color", UIStyle.text(self))
	chip.add_child(value)
	return chip


func _load_stat_icon(stat_name: String) -> Texture2D:
	return load(str(STAT_ICON_PATHS.get(stat_name, ""))) as Texture2D


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	return label


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var label := _label(text.to_upper(), 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.79, 0.31))
	parent.add_child(label)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
