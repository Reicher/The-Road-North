class_name MovementSelectionUI
extends CanvasLayer

signal confirmed

const CONTROL_GAP := 8.0

var label: Label
var confirm_button: Button

var _map: GameMap
var _grid_position := Vector2i(-1, -1)


func _ready() -> void:
	_resolve_nodes()
	if not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	hide_selection()
	set_process(false)


func _process(_delta: float) -> void:
	refresh_position(_grid_position, _map)


func show_selection(text: String, grid_position: Vector2i, map: GameMap, can_confirm: bool) -> void:
	_resolve_nodes()
	if map == null:
		hide_selection()
		return
	_map = map
	_grid_position = grid_position
	label.text = text
	label.visible = true
	confirm_button.visible = can_confirm
	_position_controls(grid_position, map)
	set_process(true)


func hide_selection() -> void:
	_resolve_nodes()
	label.visible = false
	confirm_button.visible = false
	_map = null
	_grid_position = Vector2i(-1, -1)
	set_process(false)


func refresh_position(grid_position: Vector2i, map: GameMap) -> void:
	_resolve_nodes()
	if label.visible and map != null:
		_position_controls(grid_position, map)


func _position_controls(grid_position: Vector2i, map: GameMap) -> void:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size if viewport != null else Vector2(720.0, 1280.0)
	var center := map.grid_to_screen_position(grid_position)
	var top_edge := map.grid_edge_to_screen_position(grid_position, false)
	var bottom_edge := map.grid_edge_to_screen_position(grid_position, true)
	var label_size := label.custom_minimum_size
	label.size = label_size
	label.position = Vector2(
		clampf(center.x - label_size.x * 0.5, 8.0, maxf(8.0, viewport_size.x - label_size.x - 8.0)),
		clampf(top_edge.y - label_size.y - CONTROL_GAP, 8.0, maxf(8.0, viewport_size.y - label_size.y - 8.0))
	)
	if confirm_button.visible:
		confirm_button.position = Vector2(
			clampf(center.x - confirm_button.size.x * 0.5, 8.0, maxf(8.0, viewport_size.x - confirm_button.size.x - 8.0)),
			clampf(bottom_edge.y - confirm_button.size.y * 0.5, 8.0, maxf(8.0, viewport_size.y - confirm_button.size.y - 8.0))
		)


func _on_confirm_pressed() -> void:
	confirmed.emit()


func _resolve_nodes() -> void:
	if label != null:
		return
	label = get_node("Label") as Label
	confirm_button = get_node("ConfirmButton") as Button
