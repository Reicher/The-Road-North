class_name EncounterUI
extends Control

const ShopScript = preload("res://scripts/shop_ui.gd")
const CARD_SCENE := preload("res://ui/card.tscn")

signal closed

@export var player_path: NodePath
@export var deck_controller_path: NodePath

var _player: GamePlayer
var _deck_controller: DeckController
var _encounter: Dictionary = {}
var _witch_offer: Dictionary = {}
var _witch_offer_bought := false
var _rng := RandomNumberGenerator.new()
var _title: Label
var _description: Label
var _panel: PanelContainer
var _offer_card_container: CenterContainer
var _offer_card: CardView
var _trade_button: Button


func _ready() -> void:
	_player = get_node_or_null(player_path) as GamePlayer
	_deck_controller = get_node_or_null(deck_controller_path) as DeckController
	_panel = $Panel as PanelContainer
	_title = $Panel/Margin/Stack/Title as Label
	_description = $Panel/Margin/Stack/Description as Label
	_offer_card_container = $Panel/Margin/Stack/OfferCard as CenterContainer
	_trade_button = $Panel/Margin/Stack/TradeButton as Button
	_offer_card = CARD_SCENE.instantiate() as CardView
	_offer_card.name = "Card"
	_offer_card.custom_minimum_size = Vector2(150.0, 216.0)
	_offer_card.size = _offer_card.custom_minimum_size
	_offer_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_card_container.add_child(_offer_card)
	(_offer_card.get_node("TouchButton") as Button).disabled = true
	_rng.randomize()
	$Panel/Margin/Stack/CloseButton.pressed.connect(close)
	_trade_button.pressed.connect(_trade)


func open(encounter: Dictionary) -> void:
	_encounter = encounter.duplicate(true)
	_witch_offer_bought = false
	if _type() == GameConstants.ENCOUNTER_GRAVEYARD:
		_encounter["locked_card"] = _deck_controller != null and _deck_controller.lock_random_unlocked_base_road_card()
	if _type() == GameConstants.ENCOUNTER_WITCH_HUT:
		_roll_witch_offer()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _trade() -> void:
	if _player == null:
		return
	match _type():
		GameConstants.ENCOUNTER_CAMPFIRE:
			_player.food -= 1
			_player.food_changed.emit(_player.food)
			_player.set_health(_player.health + 1)
		GameConstants.ENCOUNTER_TAVERN:
			_player.gold -= 1
			_player.gold_changed.emit(_player.gold)
			_player.add_food(1)
		GameConstants.ENCOUNTER_SHRINE:
			_player.food -= 1
			_player.food_changed.emit(_player.food)
			if _deck_controller != null:
				_deck_controller.draw_extra_cards(2)
		GameConstants.ENCOUNTER_WITCH_HUT:
			_player.set_health(_player.health - 2)
			if _deck_controller != null:
				_deck_controller.acquire_special_card(_witch_offer)
			_witch_offer_bought = true
	_refresh()


func _refresh() -> void:
	if _player == null:
		return
	var witch_hut := _type() == GameConstants.ENCOUNTER_WITCH_HUT
	_offer_card_container.visible = witch_hut
	_panel.offset_top = -245.0 if witch_hut else -140.0
	_panel.offset_bottom = 245.0 if witch_hut else 140.0
	match _type():
		GameConstants.ENCOUNTER_CAMPFIRE:
			_title.text = "Campfire"
			_description.text = "Rest by the fire."
			_trade_button.text = "1 Food  ->  1 Health"
			_trade_button.disabled = _player.food <= 1 or _player.health >= _player.max_health
		GameConstants.ENCOUNTER_TAVERN:
			_title.text = "Tavern"
			_description.text = "Buy provisions for the road."
			_trade_button.text = "1 Gold  ->  1 Food"
			_trade_button.disabled = _player.gold < 1
		GameConstants.ENCOUNTER_SHRINE:
			_title.text = "Shrine"
			_description.text = "Leave an offering for inspiration."
			_trade_button.text = "1 Food  ->  Draw 2 Cards"
			_trade_button.disabled = _player.food <= 1 or _deck_controller == null or _deck_controller.cards_remaining() <= 0
		GameConstants.ENCOUNTER_WITCH_HUT:
			_title.text = "Witch's Hut"
			_description.text = "The witch offers you this special card:"
			_offer_card.configure(_witch_offer)
			_trade_button.text = "2 Health  ->  Take Card"
			_trade_button.disabled = _player.health <= 2 or _witch_offer_bought or _witch_offer.is_empty()
		GameConstants.ENCOUNTER_GRAVEYARD:
			_title.text = "Graveyard"
			_description.text = "A base road card was locked in its current orientation." if bool(_encounter.get("locked_card", false)) else "All base road cards are already locked."
			_trade_button.visible = false
			return
	_trade_button.visible = true


func _roll_witch_offer() -> void:
	var catalog: Array[Dictionary] = ShopScript.SPECIAL_CARD_CATALOG
	if catalog.is_empty():
		_witch_offer = {}
		return
	_witch_offer = ShopScript.make_catalog_offer(catalog[_rng.randi_range(0, catalog.size() - 1)], _rng)
	_witch_offer.erase("price")


func _type() -> String:
	return str(_encounter.get("type", ""))
