class_name PlacementControlsUI
extends CanvasLayer

const PREVIEW_BUTTON_SIZE := Vector2(56.0, 56.0)
const PREVIEW_CONTROL_GAP := 6.0

var prompt_label: Label
var buttons: Control
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


func show_tile_targeting(hand: HandUI) -> void:
	_resolve_nodes()
	rotate_button.visible = false
	confirm_button.disabled = true
	buttons.visible = true
	position_buttons(Vector2i(-1, -1), null, hand)


func show_preview_controls(
	preview_position: Vector2i,
	map: GameMap,
	hand: HandUI,
	valid: bool,
	rotate_visible := true,
	hint: String = ""
) -> void:
	_resolve_nodes()
	rotate_button.visible = rotate_visible
	rotate_button.disabled = not rotate_visible
	confirm_button.disabled = not valid
	buttons.visible = true
	position_buttons(preview_position, map, hand)
	show_hint(hint, hand, preview_position, map, rotate_visible)


func show_hint(
	text: String,
	hand: HandUI,
	preview_position := Vector2i(-1, -1),
	map: GameMap = null,
	above_rotate_button := false
) -> void:
	_resolve_nodes()
	prompt_label.text = text
	prompt_label.visible = not text.is_empty()
	if preview_position.x >= 0 and map != null:
		position_prompt_above_preview(preview_position, map, hand, above_rotate_button)
	else:
		position_prompt(hand)


func hide_all() -> void:
	_resolve_nodes()
	buttons.visible = false
	rotate_button.visible = true
	rotate_button.disabled = false
	prompt_label.visible = false
	confirm_button.disabled = true


func position_buttons(preview_position: Vector2i, map: GameMap, hand: HandUI) -> void:
	_resolve_nodes()
	var viewport_size := Vector2(_get_viewport_size().x, _get_map_screen_height(hand))
	var has_preview := preview_position.x >= 0 and map != null
	if buttons.visible and has_preview:
		var canvas_position: Vector2 = map.grid_to_screen_position(preview_position)
		var top_edge_position := map.grid_edge_to_screen_position(preview_position, false)
		var bottom_edge_position := map.grid_edge_to_screen_position(preview_position, true)
		_position_around_preview(canvas_position, viewport_size, top_edge_position.y, bottom_edge_position.y)
	elif buttons.visible:
		_position_at_bottom(viewport_size)

	if has_preview:
		position_prompt_above_preview(
			preview_position,
			map,
			hand,
			buttons.visible and rotate_button.visible
		)
	else:
		position_prompt(hand)


func position_prompt(hand: HandUI) -> void:
	_resolve_nodes()
	if not prompt_label.visible:
		return

	var prompt_size := prompt_label.custom_minimum_size
	var viewport_width := _get_viewport_size().x
	var card_top := _get_hand_card_top_screen_y(hand)
	var prompt_y := maxf(8.0, card_top - prompt_size.y - 6.0)
	prompt_label.size = prompt_size
	prompt_label.position = Vector2((viewport_width - prompt_size.x) * 0.5, prompt_y)


func position_prompt_above_preview(
	preview_position: Vector2i,
	map: GameMap,
	hand: HandUI,
	above_rotate_button := false
) -> void:
	_resolve_nodes()
	if not prompt_label.visible or map == null:
		return

	var prompt_size := prompt_label.custom_minimum_size
	var viewport_size := Vector2(_get_viewport_size().x, _get_map_screen_height(hand))
	var canvas_position := map.grid_to_screen_position(preview_position)
	var top_edge_position := map.grid_edge_to_screen_position(preview_position, false)
	var prompt_y := top_edge_position.y - prompt_size.y - PREVIEW_CONTROL_GAP
	if above_rotate_button:
		var minimum_rotate_y := prompt_size.y + PREVIEW_CONTROL_GAP + 8.0
		var viewport_height := _get_viewport_size().y
		rotate_button.position.y = clampf(
			maxf(rotate_button.position.y, minimum_rotate_y),
			8.0,
			maxf(8.0, viewport_height - rotate_button.size.y - 8.0)
		)
		prompt_y = rotate_button.position.y - prompt_size.y - PREVIEW_CONTROL_GAP
	prompt_label.size = prompt_size
	prompt_label.position = Vector2(
		clampf(
			canvas_position.x - prompt_size.x * 0.5,
			8.0,
			maxf(8.0, viewport_size.x - prompt_size.x - 8.0)
		),
		clampf(
			prompt_y,
			8.0,
			maxf(8.0, viewport_size.y - prompt_size.y - 8.0)
		)
	)


func _get_map_screen_height(hand: HandUI) -> float:
	var viewport_height := _get_viewport_size().y
	if hand == null:
		return viewport_height
	return clampf(hand.get_global_rect().position.y, 1.0, viewport_height)


func _get_hand_card_top_screen_y(hand: HandUI) -> float:
	var viewport_height := _get_viewport_size().y
	if hand == null:
		return viewport_height
	return clampf(hand.get_card_top_screen_y(), 1.0, viewport_height)


func _resolve_nodes() -> void:
	if prompt_label != null:
		return
	prompt_label = get_node("PromptLabel") as Label
	buttons = get_node("Buttons") as Control
	rotate_button = get_node("Buttons/RotateButton") as Button
	confirm_button = get_node("Buttons/ConfirmButton") as Button
	cancel_button = get_node("Buttons/CancelButton") as Button


func _position_around_preview(
	canvas_position: Vector2,
	viewport_size: Vector2,
	top_edge_y := NAN,
	bottom_edge_y := NAN
) -> void:
	var button_size := PREVIEW_BUTTON_SIZE
	var side_offset := 52.0
	if is_nan(top_edge_y):
		top_edge_y = canvas_position.y - 48.0
	if is_nan(bottom_edge_y):
		bottom_edge_y = canvas_position.y + 48.0
	var bottom_y := bottom_edge_y - button_size.y * 0.5
	var top_y := top_edge_y - button_size.y * 0.5
	var center_x := canvas_position.x - button_size.x * 0.5

	rotate_button.position = _clamp_button_position(Vector2(center_x, top_y), button_size, viewport_size)
	confirm_button.position = _clamp_button_position(
		Vector2(canvas_position.x - side_offset - button_size.x * 0.5, bottom_y),
		button_size,
		viewport_size
	)
	cancel_button.position = _clamp_button_position(
		Vector2(canvas_position.x + side_offset - button_size.x * 0.5, bottom_y),
		button_size,
		viewport_size
	)
	buttons.position = Vector2.ZERO
	buttons.size = viewport_size


func _position_at_bottom(viewport_size: Vector2) -> void:
	var button_size := Vector2(56.0, 56.0)
	var side_gap := 5.0
	var bottom_y := viewport_size.y - button_size.y - 8.0
	var center_x := viewport_size.x * 0.5
	rotate_button.position = Vector2(center_x - button_size.x * 0.5, bottom_y)
	confirm_button.position = Vector2(center_x - button_size.x - side_gap, bottom_y)
	cancel_button.position = Vector2(center_x + side_gap, bottom_y)
	buttons.position = Vector2.ZERO
	buttons.size = viewport_size


func _clamp_button_position(position: Vector2, button_size: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, 8.0, maxf(8.0, viewport_size.x - button_size.x - 8.0)),
		clampf(position.y, 8.0, maxf(8.0, viewport_size.y - button_size.y - 8.0))
	)


func _get_viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(360.0, 640.0)
	return viewport.get_visible_rect().size
