extends CharacterBody2D

signal died

const IceBlockScript = preload("res://combat/projectiles/ice_block.gd")
const ICE_CREEPER_SCENE = preload("res://actors/enemies/ice_creeper_enemy.tscn")
const HEALTH_BAR_SCENE = preload("res://actors/enemies/health_bar.tscn")

const MAX_HEALTH := 650
const MOVE_SPEED := 95.0
const SLOWED_SPEED := 35.0
const TORNADO_SPEED := 520.0
const TORNADO_DISTANCE := 560.0
const TORNADO_DAMAGE := 38
const STOMP_RANGE := 92.0
const STOMP_DAMAGE := 32
const STOMP_KNOCKBACK := 1300.0
const STOMP_COOLDOWN := 3.0
const ICE_BLOCK_COOLDOWN := 4.0
const CREEPER_CYCLE := 3.0
const CREEPER_SLOW_TIME := 2.0
const TORNADO_COOLDOWN := 8.0
const TORNADO_WINDUP := 2.0
const TORNADO_RECOVER := 2.0

enum BossState { ACTIVE, SUMMONING, TORNADO_WINDUP, TORNADO_CHARGE, TORNADO_RECOVER }

var health := MAX_HEALTH
var target: Node2D = null
var push_velocity := Vector2.ZERO

var _state := BossState.ACTIVE
var _stomp_timer := 0.0
var _ice_block_timer := 1.0
var _creeper_timer := CREEPER_CYCLE
var _tornado_timer := TORNADO_COOLDOWN
var _state_timer := 0.0
var _tornado_dir := Vector2.RIGHT
var _tornado_start := Vector2.ZERO
var _tornado_hits: Array[Node] = []
var _tornado_particles: CPUParticles2D = null
var _hit_flash_tween: Tween = null
var _dead := false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _stomp_sprite: Sprite2D = $StompSprite

var _health_bar: ProgressBar

func _ready() -> void:
	add_to_group("Enemy")
	add_to_group("EnemyUnit")
	add_to_group("CaveGuard")
	_acquire_target()
	_health_bar = HEALTH_BAR_SCENE.instantiate()
	add_child(_health_bar)
	_health_bar.max_value = MAX_HEALTH
	_health_bar.value = health
	VisualEffectsService.boss_intro(global_position)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		_acquire_target()
	if not is_instance_valid(target):
		return

	_stomp_timer = max(0.0, _stomp_timer - delta)
	_ice_block_timer = max(0.0, _ice_block_timer - delta)
	_creeper_timer = max(0.0, _creeper_timer - delta)
	_tornado_timer = max(0.0, _tornado_timer - delta)

	match _state:
		BossState.ACTIVE:
			_process_active(delta)
		BossState.SUMMONING:
			_process_summoning(delta)
		BossState.TORNADO_WINDUP:
			_process_tornado_windup(delta)
		BossState.TORNADO_CHARGE:
			_process_tornado_charge(delta)
		BossState.TORNADO_RECOVER:
			_process_tornado_recover(delta)

func _process_active(delta: float) -> void:
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var dir := to_target.normalized() if dist > 0.01 else Vector2.ZERO
	rotation = dir.angle() if dir != Vector2.ZERO else rotation

	if dist <= STOMP_RANGE and _stomp_timer <= 0.0:
		_stomp()
		_stomp_timer = STOMP_COOLDOWN

	if _ice_block_timer <= 0.0:
		_throw_ice_block(dir if dir != Vector2.ZERO else Vector2.RIGHT.rotated(randf() * TAU))
		_ice_block_timer = ICE_BLOCK_COOLDOWN

	if _creeper_timer <= 0.0:
		_enter_summoning()
		return

	if _tornado_timer <= 0.0 and dist > STOMP_RANGE * 1.5:
		_enter_tornado_windup()
		return

	velocity = dir * MOVE_SPEED + push_velocity
	move_and_slide()
	push_velocity = velocity - dir * MOVE_SPEED
	push_velocity = push_velocity.move_toward(Vector2.ZERO, 1800.0 * delta)

func _process_summoning(delta: float) -> void:
	_state_timer -= delta
	rotation = global_position.direction_to(target.global_position).angle()
	velocity = global_position.direction_to(target.global_position) * SLOWED_SPEED + push_velocity
	move_and_slide()
	push_velocity = velocity - global_position.direction_to(target.global_position) * SLOWED_SPEED
	if _state_timer <= 0.0:
		_spawn_creeper()
		_state = BossState.ACTIVE
		_creeper_timer = CREEPER_CYCLE

func _enter_summoning() -> void:
	_state = BossState.SUMMONING
	_state_timer = CREEPER_SLOW_TIME
	VisualEffectsService.set_mood("boss")
	ParticleService.boss_shockwave(global_position, Color(0.55, 0.92, 1.0, 0.75), 130.0)
	ParticleService.ice_shatter(global_position, 0.9)
	_spawn_random_ice_blocks()

func _enter_tornado_windup() -> void:
	_state = BossState.TORNADO_WINDUP
	_state_timer = TORNADO_WINDUP
	_tornado_dir = _predict_tornado_direction()
	velocity = Vector2.ZERO
	VisualEffectsService.set_mood("boss")
	ParticleService.pulse_light(global_position, Color(0.45, 0.9, 1.0), 2.2, TORNADO_WINDUP, 1.9)
	_start_tornado_particles()

func _process_tornado_windup(delta: float) -> void:
	_state_timer -= delta
	rotation += TAU * 2.5 * delta
	if is_instance_valid(_tornado_particles):
		_tornado_particles.global_position = global_position
	if _state_timer <= 0.0:
		_state = BossState.TORNADO_CHARGE
		_tornado_start = global_position
		_tornado_hits.clear()
		ParticleService.boss_shockwave(global_position, Color(0.62, 0.95, 1.0, 0.86), 175.0)

func _process_tornado_charge(delta: float) -> void:
	rotation += TAU * 4.0 * delta
	if is_instance_valid(_tornado_particles):
		_tornado_particles.global_position = global_position
	velocity = _tornado_dir * TORNADO_SPEED
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		if not is_instance_valid(body):
			continue
		if body in _tornado_hits:
			continue
		_tornado_hits.append(body)
		if body.has_method("take_damage"):
			body.take_damage(TORNADO_DAMAGE, global_position, self)
		if body is Node2D and body.has_method("push"):
			var away := global_position.direction_to(body.global_position)
			if away == Vector2.ZERO:
				away = _tornado_dir
			body.push(away * STOMP_KNOCKBACK)
	if global_position.distance_to(_tornado_start) >= TORNADO_DISTANCE or get_slide_collision_count() > 0:
		_enter_tornado_recover()

func _enter_tornado_recover() -> void:
	_state = BossState.TORNADO_RECOVER
	_state_timer = TORNADO_RECOVER
	velocity = Vector2.ZERO
	_tornado_timer = TORNADO_COOLDOWN
	_stop_tornado_particles()
	ParticleService.dust_puff(global_position, 1.2)

func _process_tornado_recover(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if is_instance_valid(target):
		rotation = global_position.direction_to(target.global_position).angle()
	if _state_timer <= 0.0:
		_state = BossState.ACTIVE

func _predict_tornado_direction() -> Vector2:
	var predicted := target.global_position
	if target is CharacterBody2D:
		predicted += target.velocity * 0.8
	var dir := global_position.direction_to(predicted)
	return dir if dir.length_squared() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)

func _stomp() -> void:
	_stomp_sprite.visible = true
	_sprite.visible = false
	CameraService.shake(0.55)
	ParticleService.pulse_light(global_position, Color(0.65, 0.92, 1.0), 1.9, 0.34, 1.6)
	ParticleService.boss_shockwave(global_position, Color(0.48, 0.86, 1.0, 0.56), 100.0)
	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.tween_callback(_apply_stomp_hit)
	tween.tween_interval(0.2)
	tween.tween_callback(func():
		if is_instance_valid(_stomp_sprite):
			_stomp_sprite.visible = false
		if is_instance_valid(_sprite):
			_sprite.visible = true
	)

func _apply_stomp_hit() -> void:
	ParticleService.boss_shockwave(global_position, Color(0.74, 0.95, 1.0, 0.9), 210.0)
	ParticleService.dust_puff(global_position, 1.8)
	VisualEffectsService.boss_hit(global_position)
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = STOMP_RANGE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2 | 4
	query.exclude = [get_rid()]
	var results := space_state.intersect_shape(query, 24)
	for data in results:
		var body = data["collider"]
		if not is_instance_valid(body) or body == self:
			continue
		if body.has_method("take_damage"):
			body.take_damage(STOMP_DAMAGE, global_position, self)
		if body is Node2D:
			var away := global_position.direction_to(body.global_position)
			if away == Vector2.ZERO:
				away = Vector2.RIGHT.rotated(randf() * TAU)
			if body.has_method("push"):
				body.push(away * STOMP_KNOCKBACK)

func _spawn_random_ice_blocks() -> void:
	for i in range(3):
		_throw_ice_block(Vector2.RIGHT.rotated(randf() * TAU))

func _throw_ice_block(dir: Vector2) -> void:
	var block := IceBlockScript.new()
	block.global_position = global_position + dir * 58.0
	block.direction = dir.normalized()
	block.owner_node = self
	block.throw_damage = 18
	block.shatter_damage = 8
	get_tree().root.add_child(block)
	block.add_collision_exception_with(self)
	ParticleService.ice_shatter(block.global_position, 0.55)
	NoiseService.emit_noise(get_tree(), global_position, 450.0)

func _spawn_creeper() -> void:
	var creeper := ICE_CREEPER_SCENE.instantiate()
	get_tree().current_scene.add_child(creeper)
	creeper.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * 85.0
	ParticleService.ice_shatter(creeper.global_position, 0.75)

func _acquire_target() -> void:
	target = get_tree().get_first_node_in_group("Player")

func push(force: Vector2) -> void:
	push_velocity += force

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, source: Node2D = null) -> void:
	if _dead:
		return
	health -= amount
	if _health_bar:
		_health_bar.value = health
	DamageNumber.spawn(get_tree(), global_position + Vector2(randf_range(-14, 14), -48), amount, Color(0.5, 0.9, 1.0))
	VisualEffectsService.boss_hit(global_position)
	_flash_hit()
	if health <= 0:
		die()

func die() -> void:
	if _dead:
		return
	_dead = true
	_stop_tornado_particles()
	VisualEffectsService.enemy_killed(global_position, "ice")
	VisualEffectsService.boss_death(global_position)
	CameraService.kick(Vector2(0.1, 0.1), 0.22)
	died.emit()
	queue_free()

func _flash_hit() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		_hit_flash_tween.kill()
	modulate = Color(0.62, 0.95, 1.35, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.14)

func _start_tornado_particles() -> void:
	if is_instance_valid(_tornado_particles):
		_tornado_particles.emitting = true
		return
	_tornado_particles = null
	_tornado_particles = CPUParticles2D.new()
	_tornado_particles.name = "TornadoIceWake"
	_tornado_particles.amount = 54
	_tornado_particles.lifetime = 0.55
	_tornado_particles.explosiveness = 0.0
	_tornado_particles.direction = Vector2.UP
	_tornado_particles.spread = 180.0
	_tornado_particles.gravity = Vector2(0.0, 20.0)
	_tornado_particles.initial_velocity_min = 70.0
	_tornado_particles.initial_velocity_max = 240.0
	_tornado_particles.scale_amount_min = 2.0
	_tornado_particles.scale_amount_max = 7.5
	_tornado_particles.angular_velocity_min = -520.0
	_tornado_particles.angular_velocity_max = 520.0
	_tornado_particles.local_coords = false
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 1.0, 1.0, 0.95))
	ramp.set_color(1, Color(0.18, 0.58, 1.0, 0.0))
	_tornado_particles.color_ramp = ramp
	_tornado_particles.color = Color(0.55, 0.9, 1.0, 0.88)
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
	var particles_ref := weakref(_tornado_particles)
	_tornado_particles = null
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		var particles = particles_ref.get_ref()
		if is_instance_valid(particles):
			particles.queue_free()
	)
