class_name PlacementControlsUI
extends CanvasLayer

var prompt_label: Label
var buttons: HBoxContainer
var rotate_button: Button
var confirm_button: Button
var cancel_button: Button


func bind_actions(rotate_action: Callable, confirm_action: Callable, cancel_action: Callable) -> void:
	_resolve_nodes()
	if not rotate_button.pressed.is_connected(rotate_action):
		rotate_button.pressed.connect(rotate_action)
	if not confirm_button.pressed.is_connected(confirm_action):
		confirm_button.pressed.connect(confirm_action)
	if not cancel_button.pressed.is_connected(cancel_action):
		cancel_button.pressed.connect(cancel_action)


func show_prompt(text: String, hand: HandUI) -> void:
	_resolve_nodes()
	prompt_label.text = text
	prompt_label.visible = true
	position_prompt(hand)


func show_idle_placement(hand: HandUI) -> void:
	_resolve_nodes()
	rotate_button.visible = true
	rotate_button.disabled = true
	confirm_button.disabled = true
	buttons.visible = true
	position_buttons(Vector2i(-1, -1), null, hand)


func show_destroy_targeting(hand: HandUI) -> void:
	_resolve_nodes()
	rotate_button.visible = false
	confirm_button.disabled = true
	buttons.visible = true
	position_buttons(Vector2i(-1, -1), null, hand)


func show_preview_controls(preview_position: Vector2i, map: GameMap, hand: HandUI, valid: bool, rotate_visible := true) -> void:
	_resolve_nodes()
	prompt_label.visible = false
	rotate_button.visible = rotate_visible
	rotate_button.disabled = not rotate_visible
	confirm_button.disabled = not valid
	buttons.visible = true
	position_buttons(preview_position, map, hand)


func hide_all() -> void:
	_resolve_nodes()
	buttons.visible = false
	rotate_button.visible = true
	rotate_button.disabled = false
	prompt_label.visible = false
	confirm_button.disabled = true


func position_buttons(preview_position: Vector2i, map: GameMap, hand: HandUI) -> void:
	_resolve_nodes()
	position_prompt(hand)
	if not buttons.visible:
		return

	var controls_size := buttons.size
	var minimum_size := buttons.get_combined_minimum_size()
	if controls_size.x < minimum_size.x or controls_size.y < minimum_size.y:
		buttons.size = minimum_size
		controls_size = minimum_size

	var viewport_size := Vector2(_get_viewport_size().x, _get_map_screen_height(hand))
	var preferred_position := Vector2.ZERO
	if preview_position.x >= 0 and map != null:
		var preview_world := map.grid_to_world(preview_position)
		var canvas_position: Vector2 = map.get_global_transform_with_canvas() * preview_world
		preferred_position = canvas_position + Vector2(-controls_size.x * 0.5, map.tile_size * 0.56)
	else:
		preferred_position = Vector2((viewport_size.x - controls_size.x) * 0.5, viewport_size.y - controls_size.y - 8.0)

	preferred_position.x = clampf(preferred_position.x, 8.0, maxf(8.0, viewport_size.x - controls_size.x - 8.0))
	preferred_position.y = clampf(preferred_position.y, 8.0, maxf(8.0, viewport_size.y - controls_size.y - 8.0))
	buttons.position = preferred_position


func position_prompt(hand: HandUI) -> void:
	_resolve_nodes()
	if not prompt_label.visible:
		return

	var prompt_size := prompt_label.custom_minimum_size
	var viewport_width := _get_viewport_size().x
	var strip_top := _get_map_screen_height(hand)
	var strip_bottom := _get_hand_card_top_screen_y(hand)
	var strip_height := maxf(0.0, strip_bottom - strip_top)
	var prompt_y := strip_top + maxf(8.0, (strip_height - prompt_size.y) * 0.5)
	prompt_label.size = prompt_size
	prompt_label.position = Vector2((viewport_width - prompt_size.x) * 0.5, prompt_y)


func _get_map_screen_height(hand: HandUI) -> float:
	var viewport_height := _get_viewport_size().y
	if hand == null:
		return viewport_height
	return clampf(hand.get_global_rect().position.y, 1.0, viewport_height)


func _get_hand_card_top_screen_y(hand: HandUI) -> float:
	var viewport_height := _get_viewport_size().y
	if hand == null:
		return viewport_height

	var hand_rect := hand.get_global_rect()
	var card_top := hand_rect.position.y + maxf(0.0, hand.size.y - hand.card_size.y - hand.bottom_margin)
	return clampf(card_top, hand_rect.position.y, viewport_height)


func _resolve_nodes() -> void:
	if prompt_label != null:
		return
	prompt_label = get_node("PromptLabel") as Label
	buttons = get_node("Buttons") as HBoxContainer
	rotate_button = get_node("Buttons/RotateButton") as Button
	confirm_button = get_node("Buttons/ConfirmButton") as Button
	cancel_button = get_node("Buttons/CancelButton") as Button


func _get_viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(360.0, 640.0)
	return viewport.get_visible_rect().size
