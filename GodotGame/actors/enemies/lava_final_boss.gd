extends CharacterBody2D

signal died

const HEALTH_BAR_SCENE = preload("res://actors/enemies/health_bar.tscn")
const BOULDER_SCENE = preload("res://combat/projectiles/lava_boulder.tscn")
const BULLET_SCENE = preload("res://combat/projectiles/bullet.tscn")

const MAX_HEALTH := 850
const MOVE_SPEED := 105.0
const BOULDER_COOLDOWN := 2.2
const TORNADO_COOLDOWN := 9.0
const TORNADO_WINDUP := 1.5
const TORNADO_SPEED := 560.0
const TORNADO_DISTANCE := 640.0
const TORNADO_DAMAGE := 34
const FIRE_BURST_COOLDOWN := 7.0
const FIRE_BURST_WINDUP := 2.0
const FIRE_BURST_COUNT := 18
const FIRE_BURST_DAMAGE := 16
const FIRE_BURST_SPEED := 430.0
const CONTACT_KNOCKBACK := 1200.0
const MAX_TARGET_DISTANCE := 560.0
const HARD_LEASH_DISTANCE := 760.0
const LEASH_PULL_SPEED := 340.0
const MAX_PUSH_SPEED := 300.0

enum BossState { ACTIVE, TORNADO_WINDUP, TORNADO_CHARGE, FIRE_BURST_WINDUP }

var health := MAX_HEALTH
var target: Node2D = null
var enemy_level := "fire_lava_boss"
var push_velocity := Vector2.ZERO

var _state := BossState.ACTIVE
var _state_timer := 0.0
var _boulder_timer := 0.9
var _tornado_timer := TORNADO_COOLDOWN
var _fire_burst_timer := FIRE_BURST_COOLDOWN * 0.6
var _tornado_start := Vector2.ZERO
var _tornado_dir := Vector2.RIGHT
var _tornado_hits: Array[Node] = []
var _tornado_particles: CPUParticles2D = null
var _hit_flash_tween: Tween = null
var _dead := false

@onready var _body_visual: Polygon2D = $BodyVisual
@onready var _windup_visual: Polygon2D = $WindupVisual

var _health_bar: ProgressBar

func _ready() -> void:
	add_to_group("Enemy")
	add_to_group("EnemyUnit")
	add_to_group("LavaFinalBoss")
	_acquire_target()
	_health_bar = HEALTH_BAR_SCENE.instantiate()
	add_child(_health_bar)
	_health_bar.max_value = MAX_HEALTH
	_health_bar.value = health
	VisualEffectsService.boss_intro(global_position)
	VisualEffectsService.set_mood("fire")
	ParticleService.fire_burst(global_position, 1.8)
	call_deferred("_play_spawn_sound")

func _play_spawn_sound() -> void:
	SoundService.play_sound_at("explode", global_position, -4.0)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(target):
		_acquire_target()
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match _state:
		BossState.ACTIVE:
			_process_active(delta)
		BossState.TORNADO_WINDUP:
			_process_tornado_windup(delta)
		BossState.TORNADO_CHARGE:
			_process_tornado_charge(delta)
		BossState.FIRE_BURST_WINDUP:
			_process_fire_burst_windup(delta)

	_apply_target_leash(delta)

func _process_active(delta: float) -> void:
	_boulder_timer = maxf(_boulder_timer - delta, 0.0)
	_tornado_timer = maxf(_tornado_timer - delta, 0.0)
	_fire_burst_timer = maxf(_fire_burst_timer - delta, 0.0)

	var dir := global_position.direction_to(target.global_position)
	rotation = dir.angle() if dir != Vector2.ZERO else rotation
	push_velocity = push_velocity.limit_length(MAX_PUSH_SPEED)
	velocity = dir * MOVE_SPEED + push_velocity
	move_and_slide()
	push_velocity = push_velocity.move_toward(Vector2.ZERO, 1800.0 * delta)

	if _boulder_timer <= 0.0:
		_throw_boulder(dir)
		_boulder_timer = BOULDER_COOLDOWN
	if _fire_burst_timer <= 0.0:
		_enter_fire_burst_windup()
	elif _tornado_timer <= 0.0 and global_position.distance_to(target.global_position) > 130.0:
		_enter_tornado_windup()

func _enter_tornado_windup() -> void:
	_state = BossState.TORNADO_WINDUP
	_state_timer = TORNADO_WINDUP
	_tornado_dir = _predict_tornado_direction()
	velocity = Vector2.ZERO
	_windup_visual.visible = true
	_start_tornado_particles()
	SoundService.play_sound_at("tornado", global_position, -3.0)
	ParticleService.pulse_light(global_position, Color(1.0, 0.24, 0.04), 2.0, TORNADO_WINDUP, 1.8)

func _process_tornado_windup(delta: float) -> void:
	_state_timer -= delta
	rotation += TAU * 2.8 * delta
	if is_instance_valid(_tornado_particles):
		_tornado_particles.global_position = global_position
	if _state_timer <= 0.0:
		_state = BossState.TORNADO_CHARGE
		_tornado_start = global_position
		_tornado_hits.clear()
		_windup_visual.visible = false
		ParticleService.boss_shockwave(global_position, Color(1.0, 0.28, 0.04, 0.82), 175.0)

func _process_tornado_charge(delta: float) -> void:
	rotation += TAU * 4.0 * delta
	if is_instance_valid(_tornado_particles):
		_tornado_particles.global_position = global_position
	velocity = _tornado_dir * TORNADO_SPEED
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		if not is_instance_valid(body) or body in _tornado_hits:
			continue
		_tornado_hits.append(body)
		if body.has_method("take_damage"):
			body.take_damage(TORNADO_DAMAGE, global_position, self)
		if body is Node2D and body.has_method("push"):
			var away := global_position.direction_to(body.global_position)
			body.push((away if away != Vector2.ZERO else _tornado_dir) * CONTACT_KNOCKBACK)
	var target_dist := global_position.distance_to(target.global_position) if is_instance_valid(target) else 0.0
	if global_position.distance_to(_tornado_start) >= TORNADO_DISTANCE or get_slide_collision_count() > 0 or target_dist >= MAX_TARGET_DISTANCE:
		_enter_active_after_tornado()

func _enter_active_after_tornado() -> void:
	_state = BossState.ACTIVE
	_tornado_timer = TORNADO_COOLDOWN
	velocity = Vector2.ZERO
	_stop_tornado_particles()
	ParticleService.dust_puff(global_position, 1.3)

func _enter_fire_burst_windup() -> void:
	_state = BossState.FIRE_BURST_WINDUP
	_state_timer = FIRE_BURST_WINDUP
	velocity = Vector2.ZERO
	_windup_visual.visible = true
	ParticleService.pulse_light(global_position, Color(1.0, 0.18, 0.03), 2.6, FIRE_BURST_WINDUP, 2.0)
	SoundService.play_sound_at("fire_beam", global_position, -8.0, 1.0)

func _process_fire_burst_windup(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	rotation += TAU * 0.9 * delta
	move_and_slide()
	if _state_timer <= 0.0:
		_fire_radial_burst()
		_windup_visual.visible = false
		_fire_burst_timer = FIRE_BURST_COOLDOWN
		_state = BossState.ACTIVE

func _throw_boulder(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var boulder := BOULDER_SCENE.instantiate()
	boulder.global_position = global_position + dir * 52.0
	boulder.direction = dir.normalized()
	boulder.owner_node = self
	boulder.target = target
	boulder.turn_rate = 1.105
	boulder.health = 45
	get_tree().root.add_child(boulder)
	ParticleService.fire_burst(boulder.global_position, 0.55)
	SoundService.play_sound_at("throw", global_position, -5.0)

func _fire_radial_burst() -> void:
	ParticleService.fire_burst(global_position, 2.0)
	ParticleService.boss_shockwave(global_position, Color(1.0, 0.22, 0.03, 0.85), 210.0)
	SoundService.play_sound_at("explode", global_position, -2.0)
	for i in FIRE_BURST_COUNT:
		var angle := (TAU / FIRE_BURST_COUNT) * float(i)
		_spawn_fireball(Vector2.RIGHT.rotated(angle))

func _spawn_fireball(dir: Vector2) -> void:
	var fireball = BULLET_SCENE.instantiate()
	fireball.global_position = global_position + dir * 46.0
	fireball.direction = dir.normalized()
	fireball.rotation = dir.angle()
	fireball.speed = FIRE_BURST_SPEED
	fireball.damage = FIRE_BURST_DAMAGE
	fireball.owner_node = self
	fireball.hitbox_size = Vector2(22.0, 14.0)
	fireball.is_player_bullet = true
	get_tree().root.add_child(fireball)

func _predict_tornado_direction() -> Vector2:
	var predicted := target.global_position
	if target is CharacterBody2D:
		predicted += target.velocity * 0.75
	var dir := global_position.direction_to(predicted)
	return dir if dir.length_squared() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)

func _acquire_target() -> void:
	target = get_tree().get_first_node_in_group("Player")

func push(force: Vector2) -> void:
	push_velocity += force
	push_velocity = push_velocity.limit_length(MAX_PUSH_SPEED)

func _apply_target_leash(delta: float) -> void:
	if not is_instance_valid(target) or _state == BossState.TORNADO_CHARGE:
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist <= MAX_TARGET_DISTANCE:
		return
	var dir := to_target.normalized()
	push_velocity = Vector2.ZERO
	if dist >= HARD_LEASH_DISTANCE:
		global_position = target.global_position - dir * MAX_TARGET_DISTANCE
	else:
		global_position += dir * LEASH_PULL_SPEED * delta

func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO, _source: Node2D = null) -> void:
	if _dead:
		return
	health -= amount
	if _health_bar:
		_health_bar.value = health
	DamageNumber.spawn(get_tree(), global_position + Vector2(randf_range(-18, 18), -48), amount, Color(1.0, 0.35, 0.08))
	VisualEffectsService.boss_hit(global_position)
	_flash_hit()
	if health <= 0:
		die()

func die() -> void:
	if _dead:
		return
	_dead = true
	_stop_tornado_particles()
	VisualEffectsService.enemy_killed(global_position, "fire")
	VisualEffectsService.boss_death(global_position)
	ParticleService.fire_burst(global_position, 2.8)
	SoundService.play_sound_at("kill", global_position, -2.0)
	died.emit()
	queue_free()

func _flash_hit() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		_hit_flash_tween.kill()
	modulate = Color(1.45, 0.72, 0.32, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.14)

func _start_tornado_particles() -> void:
	if is_instance_valid(_tornado_particles):
		_tornado_particles.emitting = true
		return
	_tornado_particles = CPUParticles2D.new()
	_tornado_particles.name = "LavaTornadoWake"
	_tornado_particles.amount = 62
	_tornado_particles.lifetime = 0.55
	_tornado_particles.direction = Vector2.UP
	_tornado_particles.spread = 180.0
	_tornado_particles.gravity = Vector2(0.0, 45.0)
	_tornado_particles.initial_velocity_min = 80.0
	_tornado_particles.initial_velocity_max = 260.0
	_tornado_particles.scale_amount_min = 2.5
	_tornado_particles.scale_amount_max = 8.5
	_tornado_particles.angular_velocity_min = -560.0
	_tornado_particles.angular_velocity_max = 560.0
	_tornado_particles.local_coords = false
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.86, 0.24, 0.95))
	ramp.set_color(1, Color(0.9, 0.06, 0.0, 0.0))
	_tornado_particles.color_ramp = ramp
	_tornado_particles.color = Color(1.0, 0.25, 0.02, 0.9)
	if get_tree().current_scene:
		get_tree().current_scene.add_child(_tornado_particles)
	else:
		get_tree().root.add_child(_tornado_particles)
	_tornado_particles.global_position = global_position

func _stop_tornado_particles() -> void:
	if not is_instance_valid(_tornado_particles):
		_tornado_particles = null
		return
	_tornado_particles.emitting = false
	var particles_ref: WeakRef = weakref(_tornado_particles)
	_tornado_particles = null
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		var particles: Object = particles_ref.get_ref()
		if is_instance_valid(particles):
			particles.queue_free()
	)
