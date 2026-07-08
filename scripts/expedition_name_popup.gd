class_name ExpeditionNamePopup
extends CanvasLayer

signal expedition_named(expedition_name: String)

const DEFAULT_EXPEDITION_NAME := "Räsers"

var _line_edit: LineEdit
var _begin_button: Button


func _ready() -> void:
	_line_edit = $Dimmer/Panel/Margin/Stack/NameEdit as LineEdit
	_begin_button = $Dimmer/Panel/Margin/Stack/ButtonRow/BeginButton as Button
	_line_edit.text = DEFAULT_EXPEDITION_NAME
	_line_edit.select_all()
	_begin_button.pressed.connect(_begin)
	_line_edit.text_submitted.connect(func(_text: String) -> void: _begin())
	_line_edit.grab_focus.call_deferred()


func _begin() -> void:
	var name := _line_edit.text.strip_edges()
	if name.is_empty():
		name = DEFAULT_EXPEDITION_NAME
	expedition_named.emit(name)
	queue_free()
