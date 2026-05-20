extends EnemyBase

const OIL_BARREL_SCENE = preload("res://combat/projectiles/oil_barrel.tscn")

const BARREL_COOLDOWN := 3.0
const BARREL_RANGE := 430.0
const PREFERRED_RANGE := 190.0
const FIRE_HEAVY_HEALTH := 90

var _barrel_timer := 0.0

func _init() -> void:
	enemy_level = "fire_heavy"

func _ready() -> void:
	super._ready()
	vision_range = 900.0
	fov_angle = 360.0
	hearing_range = 900.0
	EnemyState["health"] = FIRE_HEAVY_HEALTH
	EnemyState["max_health"] = FIRE_HEAVY_HEALTH
	if health_bar:
		health_bar.max_value = FIRE_HEAVY_HEALTH
		health_bar.value = FIRE_HEAVY_HEALTH

func _physics_process(delta: float) -> void:
	_barrel_timer = max(0.0, _barrel_timer - delta)
	super._physics_process(delta)

func _chase_target(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var dist := global_position.distance_to(target.global_position)
	last_known_position = target.global_position

	if dist > PREFERRED_RANGE:
		nav_agent.target_position = target.global_position
		var move_dir := global_position.direction_to(target.global_position)
		if not nav_agent.is_navigation_finished():
			var next_pos := nav_agent.get_next_path_position()
			var path_dir := global_position.direction_to(next_pos)
			if path_dir.length_squared() >= 0.01:
				move_dir = path_dir
		_smooth_rotate(move_dir.angle(), delta)
		_apply_movement(move_dir * move_speed)
	else:
		_smooth_rotate(global_position.direction_to(target.global_position).angle(), delta)
		_apply_movement(Vector2.ZERO)

	if Time.get_ticks_msec() < _frozen_until:
		return

	if _barrel_timer <= 0.0 and dist <= BARREL_RANGE:
		_throw_barrel(global_position.direction_to(target.global_position))
		_barrel_timer = BARREL_COOLDOWN

func _throw_barrel(dir: Vector2) -> void:
	var barrel := OIL_BARREL_SCENE.instantiate()
	barrel.global_position = global_position + dir * 36.0
	barrel.direction = dir
	barrel.owner_node = self
	get_tree().root.add_child(barrel)
	barrel.add_collision_exception_with(self)
	SoundService.play_sound_at("throw", global_position, -5.0)
	NoiseService.emit_noise(get_tree(), global_position, 400.0)
