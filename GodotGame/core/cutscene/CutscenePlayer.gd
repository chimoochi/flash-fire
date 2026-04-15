class_name CutscenePlayer
extends CanvasLayer

@export var lines: Array[String] = ["..."]
@export var auto_advance: bool = false
@export var auto_advance_delay: float = 3.0

var _current_index: int = 0

var _bg: ColorRect
var _speaker_label: Label
var _body_label: Label
var _hint_label: Label
var _box: ColorRect

func _ready() -> void:
	layer = 10
	_build_ui()
	_show_line(0)

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.45)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_box = ColorRect.new()
	_box.color = Color(0.05, 0.05, 0.08, 0.92)
	_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_top = -180
	_box.offset_bottom = -20
	_box.offset_left = 60
	_box.offset_right = -60
	add_child(_box)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 16)
	_speaker_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.4))
	_speaker_label.position = Vector2(16, 10)
	_box.add_child(_speaker_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 20)
	_body_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_label.offset_left = 16
	_body_label.offset_right = -16
	_body_label.offset_top = 36
	_body_label.offset_bottom = -36
	_box.add_child(_body_label)

	_hint_label = Label.new()
	_hint_label.text = "[ Space / Click to continue ]"
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint_label.offset_left = -280
	_hint_label.offset_bottom = -10
	_hint_label.offset_top = -30
	_box.add_child(_hint_label)

func _show_line(index: int) -> void:
	if index >= lines.size():
		MapService.next_level()
		return

	var raw: String = lines[index]
	if ":" in raw:
		var colon := raw.find(":")
		_speaker_label.text = raw.substr(0, colon).strip_edges()
		_body_label.text = raw.substr(colon + 1).strip_edges()
	else:
		_speaker_label.text = ""
		_body_label.text = raw

	if auto_advance:
		_hint_label.text = ""
		await get_tree().create_timer(auto_advance_delay).timeout
		_advance()
	else:
		_hint_label.text = "[ Space / Click to continue ]"

func _advance() -> void:
	_current_index += 1
	_show_line(_current_index)

func _input(event: InputEvent) -> void:
	if auto_advance:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			get_viewport().set_input_as_handled()
			_advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_advance()
