extends Control

const PARALLAX_STRENGTH := 30.0
const PARALLAX_SMOOTH := 5.0

var _base_position: Vector2

func _ready() -> void:
	$StartGame.pressed.connect(_on_start_game_pressed)
	_base_position = $playerimage.position

func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var offset := (Vector2(0.5, 0.5) - (mouse / viewport_size)) * PARALLAX_STRENGTH
	$playerimage.position = $playerimage.position.lerp(_base_position + offset, PARALLAX_SMOOTH * delta)

func _on_start_game_pressed() -> void:
	MapService.advance_to("res://levels/level1.tscn")
