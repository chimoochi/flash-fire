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
	$StartGame.disabled = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property($Title, "modulate:a", 0.0, 0.4)
	tween.tween_property($StartGame, "modulate:a", 0.0, 0.4)
	await tween.finished
	_play_cutscene()

func _play_cutscene() -> void:
	var stream = load("res://gameassets/textures/MAIN_MENU/start game cutscene no music.ogv")
	if stream == null:
		MapService.advance_to("res://levels/level1.tscn")
		return
	var video := VideoStreamPlayer.new()
	video.stream = stream
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.expand = true
	video.z_index = 100
	add_child(video)
	video.play()
	video.finished.connect(func(): MapService.advance_to("res://levels/level1.tscn"))
