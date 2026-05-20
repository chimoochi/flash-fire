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
const SURVIVE_TIME := 10.0
const WARNING_TIME := 1.15
const FLOOR_SPARK_RANGE := 190.0
const BACKGROUND_TEXTURE := preload("res://gameplay/minigame/jetpackjoyridebackground.png")
const BACKGROUND_SCROLL_SPEED := 180.0
const STANDING_TEXTURE := preload("res://gameassets/runtime/sprites/standingsideways.png")
const FLYING_TEXTURE := preload("res://gameassets/runtime/sprites/flying2d.png")

@onready var _player: CharacterBody2D = $JetpackPlayer
@onready var _player_sprite: Sprite2D = $JetpackPlayer/PlayerSprite
@onready var _hazards: Node2D = $Hazards
@onready var _warnings: Node2D = $Warnings
@onready var _timer_label: Label = $CanvasLayer/TimerLabel
@onready var _fireball_template: Area2D = $HazardTemplates/FireballHazardTemplate
@onready var _obstacle_template: Area2D = $HazardTemplates/ObstacleHazardTemplate

var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _spawn_timer := 0.4
var _completed := false
var _player_fire_particles: CPUParticles2D
var _floor_spark_particles: CPUParticles2D
var _background_sprites: Array[Sprite2D] = []
var _background_tile_width := 0.0

func _ready() -> void:
	_rng.randomize()
	_setup_scrolling_background()
	_fireball_template.visible = false
	_obstacle_template.visible = false
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

	_scroll_background(delta)
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

func _setup_scrolling_background() -> void:
	var scale_to_view := 1080.0 / float(BACKGROUND_TEXTURE.get_height())
	_background_tile_width = float(BACKGROUND_TEXTURE.get_width()) * scale_to_view
	for i in range(2):
		var sprite := Sprite2D.new()
		sprite.name = "JetpackJoyrideBackground%d" % [i + 1]
		sprite.texture = BACKGROUND_TEXTURE
		sprite.centered = false
		sprite.scale = Vector2(scale_to_view, scale_to_view)
		sprite.position = Vector2(float(i) * _background_tile_width, 0.0)
		sprite.z_index = -100
		add_child(sprite)
		move_child(sprite, 0)
		_background_sprites.append(sprite)

func _scroll_background(delta: float) -> void:
	if _background_tile_width <= 0.0:
		return
	for sprite in _background_sprites:
		sprite.position.x -= BACKGROUND_SCROLL_SPEED * delta
		if sprite.position.x <= -_background_tile_width:
			sprite.position.x += _background_tile_width * float(_background_sprites.size())

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
	var hazard: Area2D = _fireball_template.duplicate() as Area2D
	hazard.name = "FireballHazard"
	hazard.position = Vector2(2150.0, y_pos)
	hazard.collision_layer = 0
	hazard.collision_mask = 2
	hazard.visible = true
	hazard.set_meta("speed", _rng.randf_range(780.0, 960.0))
	_hazards.add_child(hazard)

	var visual := hazard.get_node_or_null("FireballVisual") as AnimatedSprite2D
	if visual:
		visual.play("default")
	SoundService.play_sound_at("fireball", hazard.global_position, -8.0, 0.5)
	ParticleService.pulse_light(hazard.global_position, Color(1.0, 0.24, 0.03), 1.8, 0.28, 2.0)

	hazard.body_entered.connect(_on_hazard_body_entered.bind(hazard))

func _spawn_obstacle() -> void:
	var hazard: Area2D = _obstacle_template.duplicate() as Area2D
	hazard.name = "ObstacleHazard"
	hazard.collision_layer = 0
	hazard.collision_mask = 2
	hazard.set_meta("speed", _rng.randf_range(420.0, 540.0))

	var height := _rng.randf_range(210.0, 360.0)
	var local_height := _get_obstacle_template_height()
	var template_scale := hazard.scale
	var base_height := local_height * absf(template_scale.y)
	var scale_to_height := height / base_height
	var anchored_to_top := _rng.randf() < 0.5
	hazard.position = Vector2(2080.0, TOP_BOUND if anchored_to_top else FLOOR_TOP)
	var y_sign := -1.0 if anchored_to_top else 1.0
	hazard.scale = Vector2(template_scale.x * scale_to_height, absf(template_scale.y) * scale_to_height * y_sign)
	_align_obstacle_anchor(hazard, local_height)
	hazard.visible = true
	_hazards.add_child(hazard)

	hazard.body_entered.connect(_on_hazard_body_entered.bind(hazard))

func _align_obstacle_anchor(hazard: Area2D, local_height: float) -> void:
	for child in hazard.get_children():
		if child is Node2D:
			var child_2d := child as Node2D
			child_2d.position.y -= local_height

func _get_obstacle_template_height() -> float:
	var shape := _obstacle_template.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is RectangleShape2D:
		var rect := shape.shape as RectangleShape2D
		return maxf(rect.size.y, 1.0)
	return 910.0

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
		SoundService.play_sound_at("fire_hurt", body.global_position, -2.0)
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
