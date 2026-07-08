class_name ShopBackground
extends Control

const BACKDROP_FILL := Color(0.185, 0.105, 0.048, 1.0)
const PLANK_A := Color(0.285, 0.165, 0.070, 1.0)
const PLANK_B := Color(0.225, 0.125, 0.052, 1.0)
const PLANK_SEAM := Color(0.080, 0.042, 0.018, 0.64)
const SHELF_BACK := Color(0.300, 0.170, 0.070, 0.96)
const SHELF_BACK_ALT := Color(0.245, 0.140, 0.060, 0.98)
const SHELF_EDGE := Color(0.420, 0.235, 0.085, 1.0)
const SHELF_DARK_EDGE := Color(0.150, 0.078, 0.030, 0.95)
const SHELF_HIGHLIGHT := Color(0.680, 0.425, 0.165, 0.66)
const BRASS := Color(0.900, 0.640, 0.255, 0.86)
const SHELF_BOARD_HEIGHT := 22.0

var _shelf_nodes: Array[Control] = []
var _last_shelf_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(true)


func set_shelf_nodes(shelf_nodes: Array[Control]) -> void:
	_shelf_nodes = shelf_nodes
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_FILL)
	_draw_back_wall()
	for shelf in _shelf_nodes:
		if shelf == null or not is_instance_valid(shelf) or not shelf.is_visible_in_tree():
			continue
		var rect := _local_rect_for(shelf).grow_individual(8.0, 4.0, 8.0, 4.0)
		if rect.size.x <= 4.0 or rect.size.y <= 4.0:
			continue
		_draw_shelf(rect, shelf)


func _process(_delta: float) -> void:
	var signature := _shelf_signature()
	if signature == _last_shelf_signature:
		return
	_last_shelf_signature = signature
	queue_redraw()


func _draw_back_wall() -> void:
	var plank_width := 72.0
	var index := 0
	var x := 0.0
	while x < size.x:
		var width := minf(plank_width, size.x - x)
		var color := PLANK_A if index % 2 == 0 else PLANK_B
		draw_rect(Rect2(x, 0.0, width, size.y), color)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), PLANK_SEAM, 2.0)
		_draw_grain_lines(Rect2(x, 0.0, width, size.y), index)
		x += plank_width
		index += 1
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.018, 0.006, 0.16), false, 4.0)


func _draw_shelf(rect: Rect2, shelf: Control) -> void:
	var back := rect.grow_individual(-2.0, -4.0, -2.0, -SHELF_BOARD_HEIGHT)
	if back.size.y > 12.0:
		draw_rect(back, Color(0.155, 0.078, 0.030, 0.46))
		_draw_horizontal_segments(back)
	_draw_item_bays(shelf)

	var board := Rect2(
		Vector2(rect.position.x, rect.end.y - SHELF_BOARD_HEIGHT),
		Vector2(rect.size.x, SHELF_BOARD_HEIGHT)
	)
	var board_shadow := board
	board_shadow.position += Vector2(0.0, 5.0)
	board_shadow.size.y += 3.0
	draw_rect(board_shadow, Color(0.035, 0.018, 0.006, 0.24))
	_draw_board(board)

	var left_post := Rect2(Vector2(rect.position.x, rect.position.y), Vector2(12.0, rect.size.y))
	var right_post := Rect2(Vector2(rect.end.x - 12.0, rect.position.y), Vector2(12.0, rect.size.y))
	_draw_post(left_post)
	_draw_post(right_post)

	_draw_nails(rect)


func _draw_board(board: Rect2) -> void:
	draw_rect(board, SHELF_EDGE)
	draw_rect(Rect2(board.position, Vector2(board.size.x, 5.0)), SHELF_HIGHLIGHT)
	draw_rect(Rect2(board.position + Vector2(0.0, board.size.y - 5.0), Vector2(board.size.x, 5.0)), SHELF_DARK_EDGE)
	draw_rect(board, SHELF_DARK_EDGE, false, 2.0)
	var x := board.position.x + 92.0
	while x < board.end.x - 8.0:
		draw_line(Vector2(x, board.position.y + 3.0), Vector2(x, board.end.y - 3.0), Color(0.120, 0.060, 0.022, 0.42), 1.0)
		x += 92.0


func _draw_post(post: Rect2) -> void:
	draw_rect(post, SHELF_DARK_EDGE)
	draw_rect(post.grow_individual(-3.0, 0.0, -3.0, 0.0), Color(0.330, 0.175, 0.065, 0.86))
	draw_line(post.position + Vector2(3.0, 2.0), Vector2(post.position.x + 3.0, post.end.y - 2.0), SHELF_HIGHLIGHT, 1.0)


func _draw_item_bays(shelf: Control) -> void:
	for node in shelf.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree() or not _is_shop_bay_control(control):
			continue
		var bay := _local_rect_for(control).grow_individual(8.0, 8.0, 8.0, 8.0)
		if bay.size.x <= 16.0 or bay.size.y <= 16.0:
			continue
		draw_rect(bay, SHELF_BACK_ALT)
		draw_rect(bay, Color(0.090, 0.045, 0.018, 0.40), false, 1.0)


func _is_shop_bay_control(control: Control) -> bool:
	var node_name := str(control.name)
	return (
		node_name == "FloatingPriceGroup"
		or node_name.begins_with("CardOffer")
		or node_name.ends_with("Offer")
		or node_name in ["RemoveButton", "ViewDeckButton"]
	)


func _draw_horizontal_segments(rect: Rect2) -> void:
	var x := rect.position.x + 96.0
	var index := 0
	while x < rect.end.x - 8.0:
		var seam_color := Color(0.110, 0.055, 0.020, 0.44 if index % 2 == 0 else 0.28)
		draw_line(Vector2(x, rect.position.y + 4.0), Vector2(x, rect.end.y - 4.0), seam_color, 1.0)
		x += 96.0
		index += 1


func _draw_nails(rect: Rect2) -> void:
	var positions := [
		rect.position + Vector2(11.0, 11.0),
		Vector2(rect.end.x - 11.0, rect.position.y + 11.0),
		Vector2(rect.position.x + 11.0, rect.end.y - 12.0),
		rect.end - Vector2(11.0, 12.0),
	]
	for point in positions:
		draw_circle(point + Vector2(1.0, 1.0), 4.0, Color(0.035, 0.018, 0.006, 0.26))
		draw_circle(point, 3.6, BRASS)
		draw_circle(point - Vector2(1.0, 1.0), 1.3, Color(1.0, 0.82, 0.42, 0.68))


func _draw_grain_lines(rect: Rect2, offset: int) -> void:
	var y := rect.position.y + 18.0 + float(offset % 3) * 7.0
	while y < rect.end.y:
		var left := rect.position.x + 8.0
		var right := rect.end.x - 8.0
		draw_line(Vector2(left, y), Vector2(right, y + sin(y * 0.05) * 2.0), Color(0.520, 0.310, 0.120, 0.24), 1.0)
		y += 42.0


func _local_rect_for(control: Control) -> Rect2:
	var global_rect := control.get_global_rect()
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var position := inverse * global_rect.position
	var end := inverse * global_rect.end
	return Rect2(position, end - position)


func _shelf_signature() -> String:
	var parts: Array[String] = []
	for shelf in _shelf_nodes:
		if shelf == null or not is_instance_valid(shelf) or not shelf.is_visible_in_tree():
			continue
		var rect := _local_rect_for(shelf)
		parts.append("%s:%d,%d,%d,%d" % [
			shelf.name,
			roundi(rect.position.x),
			roundi(rect.position.y),
			roundi(rect.size.x),
			roundi(rect.size.y),
		])
	return "|".join(parts)
