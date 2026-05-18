extends Node2D

const LEVEL_3_PATH := "res://levels/level3.tscn"

const PLAYER_X := 480.0
const TOP_BOUND := 96.0
const FLOOR_TOP := 780.0
const PLAYER_HALF_HEIGHT := 27.0
const BOTTOM_BOUND := FLOOR_TOP - PLAYER_HALF_HEIGHT
const GRAVITY := 1050.0
const THRUST := 3400.0
const MAX_FALL_SPEED := 520.0
const MAX_RISE_SPEED := -640.0
const HAZARD_DELETE_X := -220.0
const SURVIVE_TIME := 25.0
const WARNING_TIME := 1.15
const FLAME_BEAM_SIZE := Vector2(420.0, 52.0)

@onready var _player: CharacterBody2D = $JetpackPlayer
@onready var _hazards: Node2D = $Hazards
@onready var _warnings: Node2D = $Warnings
@onready var _timer_label: Label = $CanvasLayer/TimerLabel

var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _spawn_timer := 0.4
var _completed := false

func _ready() -> void:
	_rng.randomize()
	_player.add_to_group("Player")
	$Camera2D.make_current()
	TaskService.set_tasks([
		{"label": "Escape the cave tunnel", "type": "static"},
	])

func _physics_process(delta: float) -> void:
	if _completed:
		return

	var thrusting := _is_pressed("Sprint") or _is_pressed("MoveUp") or _is_pressed("ui_accept")
	var grounded := _player.global_position.y >= BOTTOM_BOUND - 1.0
	if grounded and not thrusting:
		_player.global_position.y = BOTTOM_BOUND
		_player.velocity.y = 0.0

	if thrusting:
		_player.velocity.y -= THRUST * delta
	_player.velocity.y += GRAVITY * delta
	_player.velocity.y = clampf(_player.velocity.y, MAX_RISE_SPEED, MAX_FALL_SPEED)
	_player.velocity.x = (PLAYER_X - _player.global_position.x) * 8.0
	_player.move_and_slide()

	if _player.global_position.y < TOP_BOUND:
		_player.global_position.y = TOP_BOUND
		_player.velocity.y = maxf(_player.velocity.y, 0.0)
	elif _player.global_position.y > BOTTOM_BOUND:
		_player.global_position.y = BOTTOM_BOUND
		_player.velocity.y = minf(_player.velocity.y, 0.0)

func _process(delta: float) -> void:
	if _completed:
		return

	_elapsed += delta
	_timer_label.text = "%02.1f" % max(0.0, SURVIVE_TIME - _elapsed)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_hazard()
		_spawn_timer = _rng.randf_range(1.15, 1.7)

	_move_hazards(delta)

	if _elapsed >= SURVIVE_TIME:
		_complete_minigame()

func _is_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)

func _spawn_hazard() -> void:
	if _rng.randf() < 0.55:
		_spawn_flame_beam_warning()
	else:
		_spawn_obstacle()

func _spawn_flame_beam_warning() -> void:
	var y_pos := _rng.randf_range(TOP_BOUND + 95.0, BOTTOM_BOUND - 95.0)
	var warning := Line2D.new()
	warning.name = "FlameBeamWarning"
	warning.width = 8.0
	warning.default_color = Color(1.0, 0.18, 0.05, 0.85)
	warning.points = PackedVector2Array([
		Vector2(0.0, y_pos),
		Vector2(1920.0, y_pos),
	])
	_warnings.add_child(warning)

	var blink := create_tween()
	blink.set_loops(3)
	blink.tween_property(warning, "modulate:a", 0.15, WARNING_TIME / 6.0)
	blink.tween_property(warning, "modulate:a", 1.0, WARNING_TIME / 6.0)
	await blink.finished

	if _completed or not is_instance_valid(warning):
		return
	warning.queue_free()
	_spawn_flame_beam(y_pos)

func _spawn_flame_beam(y_pos: float) -> void:
	var hazard := Area2D.new()
	hazard.name = "FlameBeamHazard"
	hazard.position = Vector2(2150.0, y_pos)
	hazard.collision_layer = 0
	hazard.collision_mask = 2
	hazard.set_meta("speed", _rng.randf_range(780.0, 960.0))
	_hazards.add_child(hazard)

	var visual := Polygon2D.new()
	visual.color = Color(1.0, 0.26, 0.05, 0.92)
	visual.polygon = PackedVector2Array([
		Vector2(-FLAME_BEAM_SIZE.x * 0.5, -FLAME_BEAM_SIZE.y * 0.5),
		Vector2(FLAME_BEAM_SIZE.x * 0.5, -FLAME_BEAM_SIZE.y * 0.5),
		Vector2(FLAME_BEAM_SIZE.x * 0.5, FLAME_BEAM_SIZE.y * 0.5),
		Vector2(-FLAME_BEAM_SIZE.x * 0.5, FLAME_BEAM_SIZE.y * 0.5),
	])
	hazard.add_child(visual)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = FLAME_BEAM_SIZE
	shape.shape = rect
	hazard.add_child(shape)

	hazard.body_entered.connect(_on_hazard_body_entered.bind(hazard))

func _spawn_obstacle() -> void:
	var hazard := Area2D.new()
	hazard.name = "ObstacleHazard"
	hazard.position = Vector2(2080.0, _rng.randf_range(TOP_BOUND + 160.0, BOTTOM_BOUND - 160.0))
	hazard.collision_layer = 0
	hazard.collision_mask = 2
	hazard.set_meta("speed", _rng.randf_range(420.0, 540.0))
	_hazards.add_child(hazard)

	var height := _rng.randf_range(130.0, 260.0)
	var width := _rng.randf_range(70.0, 130.0)
	var visual := Polygon2D.new()
	visual.color = Color(0.48, 0.62, 0.72, 0.9)
	visual.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.5),
		Vector2(width * 0.5, -height * 0.5),
		Vector2(width * 0.5, height * 0.5),
		Vector2(-width * 0.5, height * 0.5),
	])
	hazard.add_child(visual)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	hazard.add_child(shape)

	hazard.body_entered.connect(_on_hazard_body_entered.bind(hazard))

func _move_hazards(delta: float) -> void:
	for hazard in _hazards.get_children():
		if not hazard is Area2D:
			continue
		var speed: float = hazard.get_meta("speed", 650.0)
		hazard.position.x -= speed * delta
		if hazard.position.x < HAZARD_DELETE_X:
			hazard.queue_free()

func _on_hazard_body_entered(body: Node, _hazard: Area2D) -> void:
	if body.is_in_group("Player"):
		_restart_minigame()

func _restart_minigame() -> void:
	if _completed:
		return
	_completed = true
	TaskService.clear_tasks()
	get_tree().reload_current_scene()

func _complete_minigame() -> void:
	if _completed:
		return
	_completed = true
	TaskService.clear_tasks()
	MapService.advance_to(LEVEL_3_PATH)
