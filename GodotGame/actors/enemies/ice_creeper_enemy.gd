extends EnemyBase

const WEAK_ICE_HEALTH := 45
const EXPLODE_RANGE := 48.0
const CONTACT_DAMAGE := 25
const EXPLOSION_RADIUS := 120.0
const EXPLOSION_DAMAGE := 0
const EXPLOSION_PUSH := 1400.0

var _exploded := false

func _init() -> void:
	enemy_level = "weak_ice"

func _ready() -> void:
	super._ready()
	collision_mask = 1
	if nav_agent:
		nav_agent.target_desired_distance = 0.0
	var detector := get_node_or_null("PlayerDetector")
	if detector and detector is Area2D:
		detector.body_entered.connect(_on_player_detector_body_entered)
	move_speed *= 1.25
	vision_range = 900.0
	fov_angle = 360.0
	hearing_range = 900.0
	EnemyState["health"] = WEAK_ICE_HEALTH
	EnemyState["max_health"] = WEAK_ICE_HEALTH
	if health_bar:
		health_bar.max_value = WEAK_ICE_HEALTH
		health_bar.value = WEAK_ICE_HEALTH

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_handle_soft_collision(delta)
	push_velocity = push_velocity.move_toward(Vector2.ZERO, PUSH_DECAY * delta)

	if not is_instance_valid(target):
		_acquire_target()
	if not is_instance_valid(target):
		_apply_movement(Vector2.ZERO)
		return
	if Time.get_ticks_msec() < _frozen_until:
		_apply_movement(Vector2.ZERO)
		return

	EnemyState["behavior"] = State.CHASING
	last_known_position = target.global_position
	var dist := global_position.distance_to(target.global_position)
	if dist <= EXPLODE_RANGE:
		_explode(target)
		return

	nav_agent.target_position = target.global_position
	var dir := global_position.direction_to(target.global_position)
	if not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var path_dir := global_position.direction_to(next_pos)
		if path_dir.length_squared() >= 0.01:
			dir = path_dir
	_smooth_rotate(dir.angle(), delta)
	_apply_movement(dir * move_speed)

func _explode(hit_body: Node = null) -> void:
	if _exploded:
		return
	_exploded = true
	if is_instance_valid(hit_body) and hit_body.has_method("take_damage"):
		hit_body.take_damage(CONTACT_DAMAGE, global_position, self)
	EnemyState["is_alive"] = false
	VisualEffectsService.enemy_killed(global_position, "ice")
	ParticleService.ice_shatter(global_position, 1.45)
	SoundService.play_sound_at("ice_crack", global_position, -2.0)
	died.emit()
	ThrowableService.explode(EXPLOSION_RADIUS, global_position, EXPLOSION_DAMAGE, EXPLOSION_PUSH, self)
	queue_free()

func _on_player_detector_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_explode(body)
