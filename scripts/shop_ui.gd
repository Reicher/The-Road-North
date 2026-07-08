class_name ShopUI
extends Control

const UIStyle = preload("res://scripts/ui_style.gd")
const ItemIconLibrary = preload("res://scripts/item_icon_library.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")
const CARD_SCENE := preload("res://ui/card.tscn")
const ITEM_SLOT_SCENE := preload("res://ui/item_slot.tscn")
const SPECIAL_ROAD_DEFINITIONS: Array[Resource] = [
	preload("res://data/road_straight.tres"),
	preload("res://data/road_corner.tres"),
	preload("res://data/road_t_junction.tres"),
	preload("res://data/road_four_way.tres"),
	preload("res://data/road_dead_end.tres"),
]

signal play_next_requested(progression: Dictionary)

const FOOD_PRICE := 3
const FOOD_AMOUNT := 5
const HEAL_PRICE := 3
const HEAL_AMOUNT := 5
const POWER_POTION_PRICE := 8
const MAX_HEALTH_POTION_PRICE := 10
const REMOVAL_BASE_PRICE := 12
const REMOVAL_PRICE_STEP := 6
const SLOT_SIZE := Vector2(82.0, 82.0)
const SHELF_TITLE := Color(0.96, 0.82, 0.53, 1.0)
const CARD_OFFER_SIZE := Vector2(174.0, 250.0)
const OFFER_ICON_SIZE := 42
const STAT_ICON_PATHS := GameConstants.STAT_ICON_PATHS
const PROTECTED_ROAD_TYPES := ["Straight Road", "Corner", "T-Junction"]
const BASE_CARD_SORT_ORDER := {
	"Straight Road": 0,
	"Corner": 1,
	"T-Junction": 2,
	"Four-Way Intersection": 3,
	"Dead End": 4,
}

const ITEM_OFFER_COUNT := InventoryUI.SLOT_COUNT
const ITEM_OFFER_CATALOG: Array[Dictionary] = [
	{"name": "Dagger", "price": 7, "sell_price": 4},
	{"name": "Hatchet", "price": 12, "sell_price": 6},
	{"name": "Guiding Charm", "price": 10, "sell_price": 5},
]
const FOOD_OFFERS: Array[Dictionary] = [
	{"name": "Bread", "amount": 1, "price": 1},
	{"name": "Kebab", "amount": 5, "price": 3},
	{"name": "Chicken", "amount": 10, "price": 6},
]
const HEAL_OFFERS: Array[Dictionary] = [
	{"name": "Bandage", "amount": 1, "price": 1},
	{"name": "Medic Kit", "amount": 5, "price": 3},
]
const CONSUMABLE_TEXTURE_PATHS := {
	"Bread": "res://assets/images/shop/food_bread.png",
	"Kebab": "res://assets/images/shop/food_kebab.png",
	"Chicken": "res://assets/images/shop/food_chicken.png",
	"Bandage": "res://assets/images/shop/life_bandage.png",
	"Medic Kit": "res://assets/images/shop/life_medikit.png",
}
const SPECIAL_CARD_CATALOG: Array[Dictionary] = [
	{"title": "Clear Path", "detail": "Remove an encounter from a road.", "category": GameConstants.EVENT_CATEGORY, "event_type": GameConstants.EVENT_CLEAR_PATH, "price": 8},
	{
		"title": "Wild Berries",
		"detail": "Add a berry bush to a road.",
		"category": GameConstants.EVENT_CATEGORY,
		"event_type": GameConstants.EVENT_WILD_BERRIES,
		"encounter": {"type": GameConstants.ENCOUNTER_BERRY_BUSH, "loot": [{"kind": "food", "amount": 3}]},
		"price": 10,
	},
	{
		"title": "Lost Belongings",
		"detail": "Add a cache to a road.",
		"category": GameConstants.EVENT_CATEGORY,
		"event_type": GameConstants.EVENT_LOST_BELONGINGS,
		"encounter": {
			"type": GameConstants.ENCOUNTER_CACHE,
			"loot": [{"kind": "item", "item": {"name": "Dagger", "effect": "+2 Power", "stats": {"power": 2}, "item_score": 2, "rarity": "Common", "size": "small"}}],
		},
		"price": 12,
	},
	{"title": "Sleep", "detail": "Discard hand and redraw.", "category": GameConstants.EVENT_CATEGORY, "event_type": GameConstants.EVENT_SLEEP, "price": 10},
	{"title": "It was all a dream", "detail": "Restart the current level.", "category": GameConstants.EVENT_CATEGORY, "event_type": GameConstants.EVENT_RESTART_LEVEL, "price": 16},
	{"title": "Campfire", "detail": "Trade food for health.", "category": GameConstants.ROAD_CATEGORY, "encounter": {"type": GameConstants.ENCOUNTER_CAMPFIRE}, "price": 10},
	{"title": "Tavern", "detail": "Trade gold for food.", "category": GameConstants.ROAD_CATEGORY, "encounter": {"type": GameConstants.ENCOUNTER_TAVERN}, "price": 10},
	{"title": "Witch's Hut", "detail": "Trade health for a special card.", "category": GameConstants.ROAD_CATEGORY, "encounter": {"type": GameConstants.ENCOUNTER_WITCH_HUT}, "price": 14},
	{"title": "Shrine", "detail": "Trade food to draw two cards.", "category": GameConstants.ROAD_CATEGORY, "encounter": {"type": GameConstants.ENCOUNTER_SHRINE}, "price": 10},
]
const CARD_OFFER_COUNT := 3

var progression: Dictionary = {}
var next_map_name := ""
var next_map_size := 0
var base_cards: Array[Dictionary] = []
var item_offers: Array[Dictionary] = []
var card_offers: Array[Dictionary] = []

var _gold_chip: StatChip
var _food_chip: StatChip
var _health_chip: StatChip
var _power_chip: StatChip
var _sell_zone: Button
var _slot_row: HBoxContainer
var _item_row: HBoxContainer
var _survival_row: HBoxContainer
var _food_offer_row: HBoxContainer
var _life_offer_row: HBoxContainer
var _card_row: HBoxContainer
var _remove_button: Button
var _deck_overlay: DeckOverlay
var _drag_ghost: TextureRect
var _shop_scroll: ScrollContainer
var _shop_margin: MarginContainer
var _shop_stack: VBoxContainer
var _background: Control
var _summary_panel: PanelContainer
var _compact_rows_configured := false
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
var _confirmation_shade: Control
var _confirmation_panel: PanelContainer
var _confirmation_prompt: Label
var _confirmation_confirm_button: Button
var _confirmation_cancel_button: Button
var _confirmation_callback: Callable
var _item_details_popup
var _card_offer_popup: Control
var _card_offer_title: Label
var _card_offer_type: Label
var _card_offer_detail: Label
var _card_offer_cost: Label
var _card_offer_buy_button: Button
var _selected_card_offer_index := -1


func _ready() -> void:
	resized.connect(_layout_shop)
	_bind_scene_nodes()
	_configure_compact_section_layout()
	_apply_styles()
	_layout_shop()
	_refresh()
	set_process_input(true)


func setup(next_progression: Dictionary, map_name: String, map_size: int, available_base_cards: Array) -> void:
	progression = next_progression.duplicate(true)
	var inventory: Array = progression.get("inventory", [])
	for index in inventory.size():
		if inventory[index] is Dictionary:
			inventory[index] = ItemCatalog.normalize_item(inventory[index])
	progression["inventory"] = inventory
	next_map_name = map_name
	next_map_size = map_size
	base_cards.clear()
	for card in available_base_cards:
		if card is Dictionary:
			base_cards.append((card as Dictionary).duplicate(true))
	_roll_item_offers()
	_roll_card_offers()
	if is_node_ready():
		_refresh()


func debug_add_gold(amount: int) -> void:
	progression["gold"] = int(progression.get("gold", 0)) + amount
	_refresh()


func buy_food() -> bool:
	return buy_food_bundle(FOOD_AMOUNT, FOOD_PRICE)


func buy_heal() -> bool:
	return buy_heal_bundle(HEAL_AMOUNT, HEAL_PRICE)


func buy_food_bundle(amount: int, price: int) -> bool:
	if amount <= 0 or price < 0 or not _spend_gold(price):
		return false
	progression["food"] = int(progression.get("food", 0)) + amount
	_refresh()
	return true


func buy_heal_bundle(amount: int, price: int) -> bool:
	var health := int(progression.get("health", 0))
	var max_health := int(progression.get("max_health", 1))
	if health >= max_health or amount <= 0 or price < 0 or not _spend_gold(price):
		return false
	progression["health"] = mini(max_health, health + amount)
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
	if offer_index < 0 or offer_index >= item_offers.size() or slot_index < 0 or slot_index >= InventoryUI.SLOT_COUNT:
		return false
	if offer_index in _purchased_item_offers:
		return false
	if slot_index >= inventory.size() or not (inventory[slot_index] as Dictionary).is_empty():
		return false
	var offer := item_offers[offer_index]
	if not _can_carry_item(offer, slot_index):
		return false
	if not _spend_gold(int(offer["price"])):
		return false
	var item := ItemCatalog.get_item(str(offer.get("name", "")))
	if item.is_empty():
		item = ItemCatalog.normalize_item(offer)
	else:
		item.merge(offer, true)
	item.erase("price")
	inventory[slot_index] = item
	progression["inventory"] = inventory
	_purchased_item_offers.append(offer_index)
	_refresh()
	return true


func buy_item(offer_index: int) -> bool:
	var inventory: Array = progression.get("inventory", [])
	while inventory.size() < InventoryUI.SLOT_COUNT:
		inventory.append({})
	progression["inventory"] = inventory
	for slot_index in InventoryUI.SLOT_COUNT:
		if (inventory[slot_index] as Dictionary).is_empty():
			return buy_item_to_slot(offer_index, slot_index)
	return false


func sell_inventory_slot(slot_index: int) -> bool:
	var inventory: Array = progression.get("inventory", [])
	if slot_index < 0 or slot_index >= inventory.size():
		return false
	var item: Dictionary = inventory[slot_index]
	if item.is_empty():
		return false
	var sale_price := int(item.get("sell_price", maxi(1, int(item.get("item_score", 1)) * 2)))
	progression["gold"] = int(progression.get("gold", 0)) + sale_price * _inventory_gold_multiplier()
	var max_health_bonus := ItemCatalog.get_stat(item, ItemCatalog.STAT_MAX_HEALTH)
	if max_health_bonus > 0:
		progression["max_health"] = maxi(1, int(progression.get("max_health", 1)) - max_health_bonus)
		progression["health"] = mini(int(progression.get("health", 0)), int(progression["max_health"]))
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
	base_cards.remove_at(card_index)
	_finish_card_removal()
	return true


func remove_special_card(card_index: int) -> bool:
	if bool(progression.get("removed_base_card_this_shop", false)):
		return false
	var cards: Array = progression.get("player_special_cards", [])
	if card_index < 0 or card_index >= cards.size():
		return false
	if not _spend_gold(_removal_price()):
		return false
	cards.remove_at(card_index)
	progression["player_special_cards"] = cards
	progression["player_removed_card_count"] = int(progression.get("player_removed_card_count", progression.get("player_removed_base_cards", []).size())) + 1
	_finish_card_removal()
	return true


func _finish_card_removal() -> void:
	progression["removed_base_card_this_shop"] = true
	if not progression.has("player_removed_card_count"):
		progression["player_removed_card_count"] = progression.get("player_removed_base_cards", []).size()
	_refresh()
	_show_deck_overlay(true)


func _bind_scene_nodes() -> void:
	_background = $Background as Control
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
	_survival_row = $ShopScroll/ShopMargin/ShopStack/SurvivalRow as HBoxContainer
	_buy_power_button = $ShopScroll/ShopMargin/ShopStack/PotionsRow/BuyPowerButton as Button
	_buy_max_health_button = $ShopScroll/ShopMargin/ShopStack/PotionsRow/BuyMaxHealthButton as Button
	_card_row = $ShopScroll/ShopMargin/ShopStack/CardOffers as HBoxContainer
	_remove_button = $ShopScroll/ShopMargin/ShopStack/DeckRow/RemoveButton as Button
	_view_deck_button = $ShopScroll/ShopMargin/ShopStack/DeckRow/ViewDeckButton as Button
	_play_next_button = $ShopScroll/ShopMargin/ShopStack/PlayNextButton as Button
	_deck_overlay = $DeckOverlay as DeckOverlay
	_drag_ghost = $DragGhost as TextureRect
	_item_details_popup = $ItemDetailsPopup

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


func _configure_compact_section_layout() -> void:
	if _compact_rows_configured:
		return
	_compact_rows_configured = true
	_summary_panel.custom_minimum_size.y = 135.0
	_summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_play_next_button.custom_minimum_size.y = 90.0
	_play_next_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var insert_index := _summary_panel.get_index() + 1
	_food_offer_row = HBoxContainer.new()
	_life_offer_row = HBoxContainer.new()
	_add_compact_section_row(insert_index, "Sellable equipment", _slot_row)
	insert_index += 1
	_add_compact_section_row(insert_index, "Item shop", _item_row)
	insert_index += 1
	_add_compact_section_row(insert_index, "Food", _food_offer_row)
	insert_index += 1
	_add_compact_section_row(insert_index, "Life", _life_offer_row)
	_hide_original_shop_sections()
	var bottom_spacer := get_node_or_null("ShopScroll/ShopMargin/ShopStack/BottomSpacer") as Control
	if bottom_spacer != null:
		bottom_spacer.visible = false
	_group_title_with_content("CardsSection", "CardsTitle", _card_row, 3)
	_group_title_with_content("DeckSection", "DeckTitle", _remove_button.get_parent() as Control, 3)
	_card_row.add_theme_constant_override("separation", 18)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cards_title := get_node_or_null("ShopScroll/ShopMargin/ShopStack/CardsSectionShelf/CardsSection/CardsTitle") as Label
	if cards_title != null:
		cards_title.visible = false
	var deck_title := get_node_or_null("ShopScroll/ShopMargin/ShopStack/DeckSectionShelf/DeckSection/DeckTitle") as Label
	if deck_title != null:
		deck_title.visible = false
	var deck_row := _remove_button.get_parent() as HBoxContainer
	deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_row.add_theme_constant_override("separation", 32)
	_update_dynamic_background()


func _add_compact_section_row(index: int, title: String, content_row: HBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "%sRow" % title.split(" ")[0].replace("(", "")
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.custom_minimum_size = Vector2(170.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", SHELF_TITLE)
	label.text = title
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_row.add_theme_constant_override("separation", 18)
	var old_parent := content_row.get_parent()
	if old_parent != null:
		old_parent.remove_child(content_row)
	row.add_child(label)
	row.add_child(content_row)
	var shelf_content: Control = row
	if title in ["Food", "Life"]:
		var lift_margin := MarginContainer.new()
		lift_margin.name = "%sLift" % title
		lift_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lift_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lift_margin.add_theme_constant_override("margin_bottom", 26 if title == "Life" else 16)
		lift_margin.add_child(row)
		shelf_content = lift_margin
	var shelf := _shelf_panel("%sShelf" % row.name, shelf_content)
	shelf.custom_minimum_size.y = 120.0
	_shop_stack.add_child(shelf)
	_shop_stack.move_child(shelf, index)


func _group_title_with_content(section_name: String, title_node_name: String, content: Control, separation: int) -> void:
	if content == null or get_node_or_null("ShopScroll/ShopMargin/ShopStack/%s" % section_name) != null:
		return
	var title := get_node_or_null("ShopScroll/ShopMargin/ShopStack/%s" % title_node_name) as Label
	if title == null:
		return
	var original_index := title.get_index()
	var section := VBoxContainer.new()
	section.name = section_name
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_theme_constant_override("separation", separation)
	title.get_parent().remove_child(title)
	content.get_parent().remove_child(content)
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_color_override("font_color", SHELF_TITLE)
	title.add_theme_font_size_override("font_size", 26)
	section.add_child(title)
	section.add_child(content)
	var shelf := _shelf_panel("%sShelf" % section_name, section)
	shelf.custom_minimum_size.y = 285.0 if section_name == "CardsSection" else 110.0
	_shop_stack.add_child(shelf)
	_shop_stack.move_child(shelf, original_index)


func _shelf_panel(panel_name: String, content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


func _hide_original_shop_sections() -> void:
	var inventory_line := get_node_or_null("ShopScroll/ShopMargin/ShopStack/InventoryLine") as Control
	if inventory_line != null:
		inventory_line.visible = false
	var legacy_survival_row := get_node_or_null("ShopScroll/ShopMargin/ShopStack/SurvivalRow") as Control
	if legacy_survival_row != null:
		legacy_survival_row.visible = false
	var legacy_potion_row := get_node_or_null("ShopScroll/ShopMargin/ShopStack/PotionsRow") as Control
	if legacy_potion_row != null:
		legacy_potion_row.visible = false
	for node_name in ["ItemsTitle", "SurvivalTitle", "PotionsTitle"]:
		var title := get_node_or_null("ShopScroll/ShopMargin/ShopStack/%s" % node_name) as Control
		if title != null:
			title.visible = false


func _apply_styles() -> void:
	var transparent_panel := StyleBoxFlat.new()
	transparent_panel.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_summary_panel.add_theme_stylebox_override("panel", transparent_panel)
	_sell_zone.add_theme_stylebox_override("normal", UIStyle.elevated_box(self, Color(0.56, 0.22, 0.16), Color(0.94, 0.62, 0.30), 12, 3))
	_sell_zone.visible = false
	_configure_fixed_deck_button(_remove_button)
	_configure_fixed_deck_button(_view_deck_button)
	_apply_button_icon(_buy_food_button, "food")
	_apply_button_icon(_buy_heal_button, "health")
	_apply_button_icon(_buy_power_button, "power")
	_apply_button_icon(_buy_max_health_button, "health")
	_apply_button_icon(_remove_button, "deck")
	_apply_button_icon(_view_deck_button, "deck")
	_configure_play_next_button()
	_configure_header_text()


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
	_update_dynamic_background()


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
	_refresh_survival_offers()
	_refresh_offers()
	_remove_button.text = "Remove card / %dg" % _removal_price()
	_remove_button.disabled = bool(progression.get("removed_base_card_this_shop", false)) or int(progression.get("gold", 0)) < _removal_price()
	_update_dynamic_background()


func _update_dynamic_background() -> void:
	if _background == null:
		return
	var shelves: Array[Control] = []
	for node in _shop_stack.find_children("*Shelf", "PanelContainer", true, false):
		var shelf := node as Control
		if shelf != null:
			shelves.append(shelf)
	_background.call("set_shelf_nodes", shelves)
	_background.call_deferred("set_shelf_nodes", shelves)


func _refresh_inventory_slots() -> void:
	_clear_children(_slot_row)
	var inventory: Array = progression.get("inventory", [])
	while inventory.size() < InventoryUI.SLOT_COUNT:
		inventory.append({})
	progression["inventory"] = inventory
	for index in InventoryUI.SLOT_COUNT:
		var item: Dictionary = inventory[index]
		if item.is_empty():
			continue
		var slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		slot.slot_size = SLOT_SIZE
		slot.configure(item, index)
		_apply_slot_style(slot)
		slot.pressed.connect(_show_sell_item_popup.bind(index))
		_slot_row.add_child(_priced_slot(slot, "+%d" % (_sell_price(item) * _inventory_gold_multiplier()), index))


func _refresh_survival_offers() -> void:
	if _food_offer_row == null or _life_offer_row == null:
		return
	_clear_children(_food_offer_row)
	_clear_children(_life_offer_row)
	for index in FOOD_OFFERS.size():
		var offer := FOOD_OFFERS[index]
		var food_offer := offer.duplicate(true)
		var food_button := _floating_consumable_offer(
			food_offer,
			int(food_offer["price"]),
			_confirm_buy_food.bind(food_offer),
			index
		)
		_food_offer_row.add_child(food_button)
	for index in HEAL_OFFERS.size():
		var offer := HEAL_OFFERS[index]
		var heal_offer := offer.duplicate(true)
		var slot_button := _floating_consumable_offer(
			heal_offer,
			int(heal_offer["price"]),
			_confirm_buy_heal.bind(heal_offer),
			index + FOOD_OFFERS.size()
		)
		slot_button.disabled = slot_button.disabled or int(progression.get("health", 0)) >= int(progression.get("max_health", 1))
		_life_offer_row.add_child(slot_button)


func _refresh_offers() -> void:
	_clear_children(_item_row)
	for index in item_offers.size():
		if index in _purchased_item_offers:
			continue
		var offer := item_offers[index]
		var button := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		button.name = "ItemOffer%d" % (index + 1)
		button.slot_size = SLOT_SIZE
		button.configure(offer, index)
		_apply_slot_style(button)
		ItemIconLibrary.update_size_badge(button, offer)
		button.pressed.connect(_show_buy_item_popup.bind(index))
		_item_row.add_child(_priced_slot(button, "%d" % int(offer["price"]), index + InventoryUI.SLOT_COUNT))
	_clear_children(_card_row)
	for index in card_offers.size():
		var offer := card_offers[index]
		var offer_stack := Control.new()
		offer_stack.name = "CardOffer%d" % (index + 1)
		offer_stack.custom_minimum_size = Vector2(CARD_OFFER_SIZE.x + 18.0, CARD_OFFER_SIZE.y + 20.0)
		offer_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var card := CARD_SCENE.instantiate() as CardView
		card.name = "Card"
		card.custom_minimum_size = CARD_OFFER_SIZE
		card.size = CARD_OFFER_SIZE
		var card_offset := Vector2(float(index - 1) * 7.0, 4.0 if index == 0 else 0.0)
		card.position = Vector2(9.0, -3.0) + card_offset
		card.z_index = 1
		card.pivot_offset = CARD_OFFER_SIZE * 0.5
		card.hand_presentation = true
		card.configure(offer)
		(card.get_node("TouchButton") as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var buy_button := Button.new()
		buy_button.name = "BuyButton"
		buy_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		buy_button.z_index = 2
		buy_button.tooltip_text = "View %s" % str(offer.get("title", "card"))
		buy_button.pressed.connect(_show_card_offer_popup.bind(index))
		_apply_floating_button_style(buy_button)
		buy_button.disabled = index in _purchased_card_offers
		if buy_button.disabled:
			card.modulate = Color(0.55, 0.55, 0.55, 0.72)
		offer_stack.add_child(card)
		offer_stack.add_child(buy_button)
		_card_row.add_child(offer_stack)
		_start_offer_bob.call_deferred(card, index + InventoryUI.SLOT_COUNT * 2)


func _roll_card_offers() -> void:
	card_offers.clear()
	if SPECIAL_CARD_CATALOG.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	card_offers = make_unique_catalog_offers(rng, CARD_OFFER_COUNT)


static func make_unique_catalog_offers(rng: RandomNumberGenerator, count: int) -> Array[Dictionary]:
	var available_indices: Array[int] = []
	for index in SPECIAL_CARD_CATALOG.size():
		available_indices.append(index)
	var offers: Array[Dictionary] = []
	for _index in mini(count, available_indices.size()):
		var pool_index := rng.randi_range(0, available_indices.size() - 1)
		var catalog_index := available_indices[pool_index]
		available_indices.remove_at(pool_index)
		offers.append(make_catalog_offer(SPECIAL_CARD_CATALOG[catalog_index], rng))
	return offers


static func make_catalog_offer(catalog_card: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var offer := catalog_card.duplicate(true)
	var encounter: Dictionary = offer.get("encounter", {})
	if str(encounter.get("type", "")) in GameConstants.PERMANENT_ENCOUNTER_TYPES:
		offer["tile_definition"] = SPECIAL_ROAD_DEFINITIONS[rng.randi_range(0, SPECIAL_ROAD_DEFINITIONS.size() - 1)]
		offer["rotation_steps"] = rng.randi_range(0, 3)
	return offer


func _show_deck_overlay(removal_mode: bool) -> void:
	_deck_overlay.clear_cards()
	var title_text := "REMOVE CARD" if removal_mode else "DECK OVERVIEW"
	var entries := _removable_card_entries() if removal_mode else _overview_card_entries()
	for entry in entries:
		var card: Dictionary = entry["card"]
		var index := int(entry["index"])
		var text := _card_display_name(card)
		var source := str(entry["source"])
		var disabled_state := not removal_mode or bool(progression.get("removed_base_card_this_shop", false))
		if source == "base":
			disabled_state = disabled_state or not _can_remove_card(card)
		var callback := _confirm_card_removal.bind(source, index, text) if removal_mode else Callable()
		_deck_overlay.add_card(card, 1, disabled_state, callback)
	_deck_overlay.show_overlay(title_text)


func _confirm_card_removal(source: String, card_index: int, card_name: String) -> void:
	var callback := remove_base_card.bind(card_index) if source == "base" else remove_special_card.bind(card_index)
	_deck_overlay.show_removal_confirmation(card_name, _removal_price(), callback)


func _base_card_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in _sorted_base_card_indices():
		var card := base_cards[index]
		entries.append({"card": card, "index": index, "source": "base"})
	return entries


func _removable_card_entries() -> Array[Dictionary]:
	var entries := _base_card_entries()
	var special_cards: Array = progression.get("player_special_cards", [])
	for card_index in special_cards.size():
		var raw_card = special_cards[card_index]
		var card := raw_card as Dictionary
		entries.append({"card": card, "index": card_index, "source": "special"})
	return entries


func _overview_card_entries() -> Array[Dictionary]:
	return _removable_card_entries()


func _card_display_name(card: Dictionary) -> String:
	var encounter: Dictionary = card.get("encounter", {})
	if str(encounter.get("type", "")) in GameConstants.PERMANENT_ENCOUNTER_TYPES:
		var special_definition: Resource = card.get("tile_definition")
		var road_name := str(special_definition.get("display_name")) if special_definition != null else "Road"
		return "%s (%s)" % [str(card.get("title", "Special Road")), road_name]
	var definition: Resource = card.get("tile_definition")
	if definition != null:
		return str(definition.get("display_name"))
	return str(card.get("title", card.get("event_type", "")))


func _sorted_base_card_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in base_cards.size():
		indices.append(index)
	indices.sort_custom(func(left: int, right: int) -> bool:
		var left_card := base_cards[left]
		var right_card := base_cards[right]
		var left_name := _card_display_name(left_card)
		var right_name := _card_display_name(right_card)
		var left_order := int(BASE_CARD_SORT_ORDER.get(left_name, BASE_CARD_SORT_ORDER.size()))
		var right_order := int(BASE_CARD_SORT_ORDER.get(right_name, BASE_CARD_SORT_ORDER.size()))
		if left_order != right_order:
			return left_order < right_order
		if left_name != right_name:
			return left_name.naturalnocasecmp_to(right_name) < 0
		return left < right
	)
	return indices


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
	if slot.item_data.is_empty():
		return
	if event is InputEventScreenTouch and not event.pressed:
		_show_sell_item_popup(slot.slot_index)


func _on_item_offer_input(event: InputEvent, index: int, button: Button) -> void:
	if index in _purchased_item_offers:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_confirm_buy_item_offer(index)
	elif event is InputEventScreenTouch and event.pressed:
		_confirm_buy_item_offer(index)


func _confirm_sell_inventory_slot(slot_index: int) -> void:
	var inventory: Array = progression.get("inventory", [])
	if slot_index < 0 or slot_index >= inventory.size():
		return
	var item: Dictionary = inventory[slot_index]
	if item.is_empty():
		return
	var item_name := str(item.get("name", "item"))
	var sale_price := _sell_price(item) * _inventory_gold_multiplier()
	_show_confirmation("Sell %s for %dg?" % [item_name, sale_price], sell_inventory_slot.bind(slot_index))


func _confirm_buy_item_offer(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= item_offers.size():
		return
	var offer := item_offers[offer_index]
	_show_confirmation("Buy %s for %dg?" % [str(offer.get("name", "item")), int(offer.get("price", 0))], buy_item.bind(offer_index))


func _show_sell_item_popup(slot_index: int) -> void:
	var inventory: Array = progression.get("inventory", [])
	if slot_index < 0 or slot_index >= inventory.size():
		return
	var item: Dictionary = inventory[slot_index]
	if item.is_empty():
		return
	var sale_price := _sell_price(item) * _inventory_gold_multiplier()
	_item_details_popup.show_item(item, "Sell  +%dg" % sale_price, sell_inventory_slot.bind(slot_index))


func _show_buy_item_popup(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= item_offers.size():
		return
	var offer := item_offers[offer_index]
	var can_buy := (
		offer_index not in _purchased_item_offers
		and _has_empty_inventory_slot()
		and int(progression.get("gold", 0)) >= int(offer.get("price", 0))
		and _can_carry_item(offer, -1)
	)
	_item_details_popup.show_item(offer, "Buy  %dg" % int(offer.get("price", 0)), buy_item.bind(offer_index), can_buy)


func _show_card_offer_popup(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= card_offers.size():
		return
	_ensure_card_offer_popup()
	_selected_card_offer_index = offer_index
	var offer := card_offers[offer_index]
	_card_offer_title.text = str(offer.get("title", "Special card"))
	_card_offer_type.text = _card_offer_type_text(offer)
	_card_offer_detail.text = str(offer.get("detail", "Add this special card to your deck."))
	var price := int(offer.get("price", 0))
	_card_offer_cost.text = "Cost: %dg" % price
	_card_offer_buy_button.disabled = offer_index in _purchased_card_offers or int(progression.get("gold", 0)) < price
	_card_offer_buy_button.text = "Purchased" if offer_index in _purchased_card_offers else "Buy"
	_card_offer_popup.visible = true


func _card_offer_type_text(offer: Dictionary) -> String:
	if str(offer.get("category", "")) == GameConstants.ROAD_CATEGORY:
		var encounter: Dictionary = offer.get("encounter", {})
		if str(encounter.get("type", "")) in GameConstants.REUSABLE_ENCOUNTER_TYPES:
			return "ROAD SPECIAL"
		return "SPECIAL ROAD"
	return "SPECIAL EVENT"


func _buy_selected_card_offer() -> void:
	if _selected_card_offer_index >= 0 and buy_special_card(_selected_card_offer_index):
		_hide_card_offer_popup()


func _hide_card_offer_popup() -> void:
	_selected_card_offer_index = -1
	if _card_offer_popup != null:
		_card_offer_popup.visible = false


func _ensure_card_offer_popup() -> void:
	if _card_offer_popup != null:
		return
	_card_offer_popup = Control.new()
	_card_offer_popup.name = "CardOfferPopup"
	_card_offer_popup.visible = false
	_card_offer_popup.z_index = 210
	_card_offer_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_offer_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_card_offer_popup)

	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.05, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_offer_popup.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_offer_popup.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470.0, 0.0)
	panel.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self), 12, 3))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	_card_offer_title = Label.new()
	_card_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_offer_title.add_theme_font_size_override("font_size", 32)
	_card_offer_title.add_theme_color_override("font_color", UIStyle.text(self))
	stack.add_child(_card_offer_title)

	_card_offer_type = Label.new()
	_card_offer_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_offer_type.add_theme_font_size_override("font_size", 18)
	_card_offer_type.add_theme_color_override("font_color", UIStyle.muted_text(self))
	stack.add_child(_card_offer_type)

	_card_offer_detail = Label.new()
	_card_offer_detail.custom_minimum_size.y = 64.0
	_card_offer_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_offer_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_offer_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_offer_detail.add_theme_font_size_override("font_size", 23)
	_card_offer_detail.add_theme_color_override("font_color", UIStyle.text(self))
	stack.add_child(_card_offer_detail)

	_card_offer_cost = Label.new()
	_card_offer_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_offer_cost.add_theme_font_size_override("font_size", 25)
	_card_offer_cost.add_theme_color_override("font_color", Color(0.73, 0.42, 0.10))
	stack.add_child(_card_offer_cost)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	stack.add_child(buttons)
	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(0.0, 58.0)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.text = "Close"
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(_hide_card_offer_popup)
	buttons.add_child(close_button)
	_card_offer_buy_button = Button.new()
	_card_offer_buy_button.custom_minimum_size = Vector2(0.0, 58.0)
	_card_offer_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_offer_buy_button.text = "Buy"
	_card_offer_buy_button.add_theme_font_size_override("font_size", 24)
	_card_offer_buy_button.pressed.connect(_buy_selected_card_offer)
	buttons.add_child(_card_offer_buy_button)


func _confirm_buy_food(offer: Dictionary) -> void:
	_show_confirmation("Buy %s: +%d food for %dg?" % [str(offer["name"]), int(offer["amount"]), int(offer["price"])], buy_food_bundle.bind(int(offer["amount"]), int(offer["price"])))


func _confirm_buy_heal(offer: Dictionary) -> void:
	_show_confirmation("Buy %s: +%d life for %dg?" % [str(offer["name"]), int(offer["amount"]), int(offer["price"])], buy_heal_bundle.bind(int(offer["amount"]), int(offer["price"])))


func _show_confirmation(prompt: String, callback: Callable) -> void:
	_ensure_shop_confirmation()
	_confirmation_prompt.text = prompt
	_confirmation_callback = callback
	_confirmation_shade.visible = true


func _on_confirmation_confirmed() -> void:
	if _confirmation_callback.is_valid():
		_confirmation_callback.call()
	_hide_shop_confirmation()


func _hide_shop_confirmation() -> void:
	_confirmation_callback = Callable()
	if _confirmation_shade != null:
		_confirmation_shade.visible = false


func _ensure_shop_confirmation() -> void:
	if _confirmation_shade != null:
		return
	_confirmation_shade = Control.new()
	_confirmation_shade.name = "ShopConfirmation"
	_confirmation_shade.visible = false
	_confirmation_shade.z_index = 200
	_confirmation_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirmation_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confirmation_shade)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.08, 0.07, 0.05, 0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirmation_shade.add_child(shade)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirmation_shade.add_child(center)

	_confirmation_panel = PanelContainer.new()
	_confirmation_panel.name = "Panel"
	_confirmation_panel.custom_minimum_size = Vector2(460.0, 0.0)
	_confirmation_panel.add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self), 12, 3))
	center.add_child(_confirmation_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	_confirmation_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 18)
	margin.add_child(stack)

	_confirmation_prompt = Label.new()
	_confirmation_prompt.name = "Prompt"
	_confirmation_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirmation_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmation_prompt.add_theme_color_override("font_color", UIStyle.text(self))
	_confirmation_prompt.add_theme_font_size_override("font_size", 27)
	stack.add_child(_confirmation_prompt)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 12)
	stack.add_child(buttons)

	_confirmation_cancel_button = Button.new()
	_confirmation_cancel_button.name = "CancelButton"
	_confirmation_cancel_button.custom_minimum_size = Vector2(0.0, 58.0)
	_confirmation_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirmation_cancel_button.text = "Cancel"
	_confirmation_cancel_button.add_theme_font_size_override("font_size", 24)
	_confirmation_cancel_button.pressed.connect(_hide_shop_confirmation)
	buttons.add_child(_confirmation_cancel_button)

	_confirmation_confirm_button = Button.new()
	_confirmation_confirm_button.name = "ConfirmButton"
	_confirmation_confirm_button.custom_minimum_size = Vector2(0.0, 58.0)
	_confirmation_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirmation_confirm_button.text = "Confirm"
	_confirmation_confirm_button.add_theme_font_size_override("font_size", 24)
	_confirmation_confirm_button.pressed.connect(_on_confirmation_confirmed)
	buttons.add_child(_confirmation_confirm_button)


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
		_sell_zone.text = "SELL\n+%dg" % int(_drag_item.get("sell_price", maxi(1, int(_drag_item.get("item_score", 1)) * 2)))
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
		var slot_stack := _slot_row.get_child(index) as Control
		if slot_stack.get_global_rect().has_point(position):
			for child in slot_stack.get_children():
				if child is ItemSlot:
					return (child as ItemSlot).slot_index
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
	var removal_count := int(progression.get("player_removed_card_count", progression.get("player_removed_base_cards", []).size()))
	return REMOVAL_BASE_PRICE + removal_count * REMOVAL_PRICE_STEP


func _inventory_power() -> int:
	var total := 0
	for item in progression.get("inventory", []):
		total += ItemCatalog.get_stat(item as Dictionary, ItemCatalog.STAT_POWER)
	return total


func _inventory_gold_multiplier() -> int:
	var multiplier := 1
	for item in progression.get("inventory", []):
		multiplier = maxi(multiplier, ItemCatalog.get_special_effect(item as Dictionary, "gold_multiplier", 1))
	return multiplier


func _sell_price(item: Dictionary) -> int:
	return int(item.get("sell_price", maxi(1, int(item.get("item_score", 1)) * 2)))


func _has_empty_inventory_slot() -> bool:
	var inventory: Array = progression.get("inventory", [])
	for index in InventoryUI.SLOT_COUNT:
		if index >= inventory.size() or (inventory[index] as Dictionary).is_empty():
			return true
	return false


func _roll_item_offers() -> void:
	var candidates := ITEM_OFFER_CATALOG.duplicate(true)
	candidates.shuffle()
	item_offers.clear()
	for index in mini(ITEM_OFFER_COUNT, candidates.size()):
		var offer := ItemCatalog.get_item(str(candidates[index]["name"]))
		offer.merge(candidates[index], true)
		item_offers.append(offer)


func _can_carry_item(item: Dictionary, replacing_slot: int) -> bool:
	var item_size := str(item.get("size", ItemCatalog.get_item(str(item.get("name", ""))).get("size", ItemCatalog.SIZE_SMALL)))
	if item_size != ItemCatalog.SIZE_LARGE:
		return true
	var inventory: Array = progression.get("inventory", [])
	for index in inventory.size():
		if index == replacing_slot or not (inventory[index] is Dictionary):
			continue
		if str((inventory[index] as Dictionary).get("size", ItemCatalog.SIZE_SMALL)) == ItemCatalog.SIZE_LARGE:
			return false
	return true


func _shop_action_slot(title: String, price: int, icon_name: String, amount: int, tooltip: String, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.size = SLOT_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.text = ""
	button.disabled = int(progression.get("gold", 0)) < price
	button.pressed.connect(callback)
	button.tooltip_text = tooltip
	_apply_slot_style(button)
	_add_slot_content(button, title, icon_name, amount)
	return button


func _floating_consumable_offer(offer: Dictionary, price: int, callback: Callable, animation_index: int) -> Button:
	var button := Button.new()
	button.name = "%sOffer" % str(offer["name"]).replace(" ", "")
	button.custom_minimum_size = Vector2(132.0, 108.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "%s: +%d" % [str(offer["name"]), int(offer["amount"])]
	button.disabled = int(progression.get("gold", 0)) < price
	button.pressed.connect(callback)
	_apply_floating_button_style(button)

	var art := TextureRect.new()
	art.name = "FloatingArt"
	art.texture = load(str(CONSUMABLE_TEXTURE_PATHS.get(str(offer["name"]), ""))) as Texture2D
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.z_index = 1
	art.offset_left = -7.0
	art.offset_top = 12.0
	art.offset_right = SLOT_SIZE.x + 7.0
	art.offset_bottom = 98.0
	button.add_child(art)

	var price_chip := _price_chip(str(price))
	price_chip.name = "TopPrice"
	price_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_chip.position = Vector2(50.0, 68.0)
	price_chip.z_index = 2
	button.add_child(price_chip)
	_start_offer_bob.call_deferred(art, animation_index)
	_start_offer_bob.call_deferred(price_chip, animation_index)
	return button


func _apply_floating_button_style(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.84, 0.36, 0.12) if state in ["hover", "focus"] else Color(0.0, 0.0, 0.0, 0.0)
		style.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, style)


func _start_offer_bob(art: Control, animation_index: int) -> void:
	if not is_instance_valid(art) or not art.is_inside_tree():
		return
	var base_y := art.position.y
	var tween := art.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if animation_index > 0:
		tween.tween_interval(float(animation_index) * 0.11)
	tween.tween_property(art, "position:y", base_y - 4.0, 0.72)
	tween.tween_property(art, "position:y", base_y + 2.0, 0.72)


func _priced_slot(slot_button: Button, price_text: String, animation_index := 0) -> Control:
	var group := Control.new()
	group.name = "FloatingPriceGroup"
	group.custom_minimum_size = Vector2(132.0, SLOT_SIZE.y + 26.0)
	group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var price_chip := _price_chip(price_text)
	price_chip.name = "OverlapPrice"
	price_chip.position = Vector2(50.0, 70.0)
	price_chip.z_index = 2
	group.add_child(price_chip)
	slot_button.position = Vector2(0.0, 18.0)
	slot_button.z_index = 1
	group.add_child(slot_button)
	var hit_area := Button.new()
	hit_area.name = "GroupHitArea"
	hit_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_area.z_index = 3
	hit_area.disabled = slot_button.disabled
	hit_area.tooltip_text = slot_button.tooltip_text
	hit_area.pressed.connect(func() -> void: slot_button.pressed.emit())
	_apply_floating_button_style(hit_area)
	group.add_child(hit_area)
	if not price_text.is_empty():
		_start_offer_bob.call_deferred(slot_button, animation_index)
		_start_offer_bob.call_deferred(price_chip, animation_index)
	return group


func _price_chip(price_text: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.name = "PriceChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(SLOT_SIZE.x, 30.0)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_theme_constant_override("separation", 4)
	if price_text.is_empty():
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(SLOT_SIZE.x, 30.0)
		chip.add_child(spacer)
		return chip
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28.0, 28.0)
	icon.texture = _load_stat_icon("gold")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = "PriceLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0))
	label.text = price_text
	chip.add_child(icon)
	chip.add_child(label)
	return chip


func _add_slot_content(slot_button: Button, title: String, icon_name: String, amount: int) -> void:
	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.offset_left = 5.0
	title_label.offset_right = -5.0
	title_label.offset_top = 8.0
	title_label.offset_bottom = 32.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.20, 0.14, 0.09, 1.0))
	title_label.text = title
	slot_button.add_child(title_label)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _load_stat_icon(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_left = 0.0
	icon.anchor_right = 0.5
	icon.anchor_top = 0.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 9.0
	icon.offset_right = -8.0
	icon.offset_top = 34.0
	icon.offset_bottom = -24.0
	slot_button.add_child(icon)

	var amount_label := Label.new()
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.anchor_left = 0.48
	amount_label.anchor_right = 1.0
	amount_label.anchor_top = 0.0
	amount_label.anchor_bottom = 1.0
	amount_label.offset_left = 0.0
	amount_label.offset_right = -8.0
	amount_label.offset_top = 35.0
	amount_label.offset_bottom = -25.0
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 21)
	amount_label.add_theme_color_override("font_color", Color(0.20, 0.14, 0.09, 1.0))
	amount_label.text = "+%d" % amount
	slot_button.add_child(amount_label)


func _configure_fixed_deck_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(240.0, 56.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _configure_play_next_button() -> void:
	if _play_next_button == null:
		return
	_play_next_button.custom_minimum_size = Vector2(560.0, 76.0)
	_play_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_play_next_button.add_theme_font_size_override("font_size", 28)
	UIStyle.apply_menu_button_style(_play_next_button)


func _configure_header_text() -> void:
	var title := get_node_or_null("ShopScroll/ShopMargin/ShopStack/SummaryPanel/SummaryMargin/SummaryStack/Title") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", 44)
		title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.42, 1.0))
		title.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.005, 0.92))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 3)
		title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.005, 0.95))
		title.add_theme_constant_override("outline_size", 4)
	for chip in [_gold_chip, _food_chip, _health_chip, _power_chip]:
		_configure_header_stat_chip(chip)


func _configure_header_stat_chip(chip: StatChip) -> void:
	if chip == null:
		return
	chip.custom_minimum_size = Vector2(120.0, 48.0)
	chip.icon_size = Vector2(46.0, 46.0)
	var value := chip.get_node_or_null("Value") as Label
	if value == null:
		return
	value.add_theme_font_size_override("font_size", 31)
	value.add_theme_color_override("font_color", Color(1.0, 0.91, 0.66, 1.0))
	value.add_theme_color_override("font_outline_color", Color(0.025, 0.012, 0.006, 0.96))
	value.add_theme_constant_override("outline_size", 4)
	value.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	value.add_theme_constant_override("shadow_offset_x", 0)
	value.add_theme_constant_override("shadow_offset_y", 2)


func _apply_slot_style(slot_button: Button) -> void:
	_apply_floating_button_style(slot_button)
	slot_button.add_theme_constant_override("icon_max_width", int(SLOT_SIZE.x))
	slot_button.expand_icon = true


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
