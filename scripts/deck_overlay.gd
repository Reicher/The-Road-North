class_name DeckOverlay
extends PanelContainer

const UIStyle = preload("res://scripts/ui_style.gd")
const CARD_SCENE := preload("res://ui/card.tscn")

const OVERVIEW_CARD_SIZE := CardView.DISPLAY_CARD_SIZE
const OVERVIEW_ENTRY_HEIGHT := 262.0

signal close_requested

var _title_label: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _scroll_hint: Label
var _close_button: Button
var _confirmation_shade: Control
var _confirmation_label: Label
var _confirm_button: Button
var _cancel_button: Button
var _confirmation_callback := Callable()


func _ready() -> void:
	_title_label = $Margin/Stack/Title as Label
	_scroll = $Margin/Stack/Scroll as ScrollContainer
	_grid = $Margin/Stack/Scroll/Grid as GridContainer
	_scroll_hint = $Margin/Stack/ScrollHint as Label
	_close_button = $Margin/Stack/CloseButton as Button
	_confirmation_shade = $ConfirmationShade as Control
	_confirmation_label = $ConfirmationShade/Center/Panel/Margin/Stack/Prompt as Label
	_confirm_button = $ConfirmationShade/Center/Panel/Margin/Stack/Buttons/ConfirmButton as Button
	_cancel_button = $ConfirmationShade/Center/Panel/Margin/Stack/Buttons/CancelButton as Button
	if not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(hide_confirmation)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _update_scroll_hint())
	_scroll.resized.connect(_update_scroll_hint)
	visible = false
	add_theme_stylebox_override("panel", UIStyle.elevated_box(self, UIStyle.panel_fill(self), UIStyle.panel_border(self)))


func show_overlay(title_text: String) -> void:
	_title_label.text = title_text
	visible = true
	_scroll.scroll_vertical = 0
	_update_scroll_hint.call_deferred()


func hide_overlay() -> void:
	hide_confirmation()
	visible = false


func clear_cards() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_update_scroll_hint.call_deferred()


func add_card(card_data: Dictionary, count: int, disabled_state: bool, callback: Callable = Callable()) -> CardView:
	var entry := VBoxContainer.new()
	entry.custom_minimum_size = Vector2(OVERVIEW_CARD_SIZE.x, OVERVIEW_ENTRY_HEIGHT)
	entry.alignment = BoxContainer.ALIGNMENT_CENTER
	entry.add_theme_constant_override("separation", 8)
	var count_label := Label.new()
	count_label.name = "Count"
	count_label.text = "×%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", UIStyle.text(self))
	count_label.add_theme_font_size_override("font_size", 24)
	var card := CARD_SCENE.instantiate() as CardView
	card.name = "Card"
	card.custom_minimum_size = OVERVIEW_CARD_SIZE
	card.size = OVERVIEW_CARD_SIZE
	card.pivot_offset = OVERVIEW_CARD_SIZE * 0.5
	card.configure(card_data)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var touch_button := card.get_node("TouchButton") as Button
	touch_button.disabled = disabled_state
	touch_button.set_meta("deck_overlay_disabled", disabled_state)
	if callback.is_valid():
		card.pointer_released.connect(func(_card: CardView, _position: Vector2) -> void:
			if not touch_button.disabled:
				callback.call()
		)
	if disabled_state and callback.is_valid():
		card.modulate = Color(0.62, 0.62, 0.62, 0.78)
	entry.add_child(count_label)
	entry.add_child(card)
	_grid.add_child(entry)
	_update_scroll_hint.call_deferred()
	return card


func show_removal_confirmation(card_name: String, price: int, callback: Callable) -> void:
	if _confirmation_shade.visible:
		return
	_confirmation_callback = callback
	_confirmation_label.text = "Remove %s from the deck for %dg?" % [card_name, price]
	_confirm_button.text = "Remove / %dg" % price
	_set_card_interactions_locked(true)
	_confirmation_shade.visible = true


func hide_confirmation() -> void:
	_confirmation_callback = Callable()
	_confirmation_shade.visible = false
	_set_card_interactions_locked(false)


func get_card_grid() -> GridContainer:
	return _grid


func _update_scroll_hint() -> void:
	if _scroll == null or _scroll_hint == null:
		return
	var scrollbar := _scroll.get_v_scroll_bar()
	var has_more_below := scrollbar.max_value > scrollbar.page + 1.0 \
		and scrollbar.value < scrollbar.max_value - scrollbar.page - 1.0
	_scroll_hint.visible = has_more_below


func _set_card_interactions_locked(locked: bool) -> void:
	for entry in _grid.get_children():
		var touch_button := entry.get_node("Card/TouchButton") as Button
		touch_button.disabled = locked or bool(touch_button.get_meta("deck_overlay_disabled", false))


func _on_confirm_pressed() -> void:
	var callback := _confirmation_callback
	hide_confirmation()
	if callback.is_valid():
		callback.call()


func _on_close_pressed() -> void:
	hide_overlay()
	close_requested.emit()
