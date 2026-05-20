extends Node2D

const LEVEL_3_PATH := "res://levels/level3.tscn"

const PLAYER_X := 480.0
const TOP_BOUND := 96.0
const FLOOR_TOP := 780.0
const PLAYER_HALF_HEIGHT := 46.0
const BOTTOM_BOUND := FLOOR_TOP - PLAYER_HALF_HEIGHT
const GRAVITY := 1050.0
const THRUST := 3400.0
const MAX_FALL_SPEED := 520.0
const MAX_RISE_SPEED := -640.0
const HAZARD_DELETE_X := -220.0
const SURVIVE_TIME := 25.0
const WARNING_TIME := 1.15
const FLAME_BEAM_SIZE := Vector2(420.0, 52.0)
const FLOOR_SPARK_RANGE := 190.0
const STANDING_TEXTURE := preload("res://gameassets/runtime/sprites/standingsideways.png")
const FLYING_TEXTURE := preload("res://gameassets/runtime/sprites/flying2d.png")

@onready var _player: CharacterBody2D = $JetpackPlayer
@onready var _player_sprite: Sprite2D = $JetpackPlayer/PlayerSprite
@onready var _hazards: Node2D = $Hazards
@onready var _warnings: Node2D = $Warnings
@onready var _timer_label: Label = $CanvasLayer/TimerLabel

var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _spawn_timer := 0.4
var _completed := false
var _player_fire_particles: CPUParticles2D
var _floor_spark_particles: CPUParticles2D

func _ready() -> void:
	_rng.randomize()
	_player.add_to_group("Player")
	_player_fire_particles = _add_downward_fire_particles(_player, Vector2(1.0, 58.0), 28)
	_player_fire_particles.lifetime = 0.26
	_player_fire_particles.emitting = false
	_floor_spark_particles = _create_floor_spark_particles()
	VisualEffectsService.set_mood("minigame")
	$Camera2D.make_current()
	TaskService.set_tasks([
		{"label": "Escape the cave tunnel", "type": "static"},
	])

func _physics_process(delta: float) -> void:
	if _completed:
		return

	var thrusting := _is_pressed("Sprint") or _is_pressed("MoveUp") or _is_pressed("ui_accept")
	var grounded := _player.global_position.y >= BOTTOM_BOUND - 1.0
	_update_player_sprite(thrusting, grounded)

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

func _update_player_sprite(thrusting: bool, grounded: bool) -> void:
	var should_fly := thrusting or not grounded
	_player_sprite.texture = FLYING_TEXTURE if should_fly else STANDING_TEXTURE
	_player_sprite.rotation = lerpf(_player_sprite.rotation, -0.08 if should_fly else 0.0, 0.25)
	_player_fire_particles.emitting = thrusting
	_update_floor_sparks(thrusting)

func _update_floor_sparks(thrusting: bool) -> void:
	var flame_tip_y := _player.global_position.y + _player_fire_particles.position.y
	var floor_gap := FLOOR_TOP - flame_tip_y
	var should_spark := thrusting and floor_gap >= -48.0 and floor_gap <= FLOOR_SPARK_RANGE
	_floor_spark_particles.global_position = Vector2(_player.global_position.x + 1.0, FLOOR_TOP - 3.0)
	_floor_spark_particles.emitting = should_spark

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
	_add_downward_fire_particles(hazard, Vector2(0.0, FLAME_BEAM_SIZE.y * 0.5 + 5.0), 34)
	ParticleService.pulse_light(hazard.global_position, Color(1.0, 0.24, 0.03), 1.8, 0.28, 2.0)

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
	_add_downward_fire_particles(hazard, Vector2(0.0, height * 0.5 + 8.0), 22)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	hazard.add_child(shape)

	hazard.body_entered.connect(_on_hazard_body_entered.bind(hazard))

func _add_downward_fire_particles(parent: Node2D, offset: Vector2, amount: int) -> CPUParticles2D:
	return ParticleService.ember_trail(parent, offset, amount)

func _create_floor_spark_particles() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "JetpackFloorSparks"
	particles.amount = 18
	particles.lifetime = 0.24
	particles.explosiveness = 0.1
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 82.0
	particles.gravity = Vector2(0.0, 260.0)
	particles.initial_velocity_min = 55.0
	particles.initial_velocity_max = 155.0
	particles.scale_amount_min = 1.6
	particles.scale_amount_max = 4.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.local_coords = false
	particles.emitting = false
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.88, 0.32, 1.0))
	ramp.set_color(1, Color(0.95, 0.12, 0.02, 0.0))
	particles.color_ramp = ramp
	particles.color = Color(1.0, 0.5, 0.08, 0.86)
	add_child(particles)
	return particles

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
	VisualEffectsService.death_flash()
	TaskService.clear_tasks()
	get_tree().reload_current_scene()

func _complete_minigame() -> void:
	if _completed:
		return
	_completed = true
	VisualEffectsService.set_mood("normal")
	TaskService.clear_tasks()
	MapService.advance_to(LEVEL_3_PATH)
