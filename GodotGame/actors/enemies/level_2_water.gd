extends EnemyBase

const IceShardScript = preload("res://combat/projectiles/ice_shard.gd")
const IceBlockScript = preload("res://combat/projectiles/ice_block.gd")

const ICE_SHARD_COOLDOWN := 1.0
const ICE_BLOCK_COOLDOWN := 3.0
const ICE_SHARD_DAMAGE := 7
const ICE_BLOCK_THROW_DAMAGE := 10
const ICE_BLOCK_SHATTER_DAMAGE := 4
const ICE_SHARD_RANGE := 350.0
const ICE_BLOCK_RANGE := 420.0
const WATER_ENEMY_HEALTH := 80

var _shard_timer := 0.0
var _block_timer := 0.0

func _init() -> void:
	enemy_level = "level2water"

func _ready() -> void:
	super._ready()
	EnemyState["health"] = WATER_ENEMY_HEALTH
	EnemyState["max_health"] = WATER_ENEMY_HEALTH
	if health_bar:
		health_bar.max_value = WATER_ENEMY_HEALTH
		health_bar.value = WATER_ENEMY_HEALTH
	_add_placeholder_visual()

func _add_placeholder_visual() -> void:
	# Placeholder body: blue circle drawn with Polygon2D
	var poly := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 16
	var radius := 14.0
	for i in segments:
		var angle := (TAU / segments) * i
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = points
	poly.color = Color(0.3, 0.7, 1.0, 0.9)
	add_child(poly)

	# Direction nub so you can see which way the enemy faces
	var nub := ColorRect.new()
	nub.size = Vector2(8.0, 4.0)
	nub.position = Vector2(14.0, -2.0)
	nub.color = Color(0.1, 0.4, 0.9, 1.0)
	add_child(nub)

func _physics_process(delta: float) -> void:
	_shard_timer = max(0.0, _shard_timer - delta)
	_block_timer = max(0.0, _block_timer - delta)
	super._physics_process(delta)

# Overrides enemy_base._chase_target — called by super._physics_process when in CHASING state
func _chase_target(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var dist := global_position.distance_to(target.global_position)
	last_known_position = target.global_position

	# Kite at comfortable range — close enough to use shards, far enough to feel like a ranged enemy
	var preferred_range := ICE_SHARD_RANGE * 0.75
	if dist > preferred_range:
		nav_agent.target_position = target.global_position
		var move_dir: Vector2
		if not nav_agent.is_navigation_finished():
			var next_pos := nav_agent.get_next_path_position()
			move_dir = global_position.direction_to(next_pos)
			if move_dir.length_squared() < 0.01:
				move_dir = global_position.direction_to(target.global_position)
		else:
			move_dir = global_position.direction_to(target.global_position)
		_smooth_rotate(move_dir.angle(), delta)
		_apply_movement(move_dir * move_speed)
	else:
		_smooth_rotate(global_position.direction_to(target.global_position).angle(), delta)
		_apply_movement(Vector2.ZERO)

	if Time.get_ticks_msec() < _frozen_until:
		return

	var aim_dir := global_position.direction_to(target.global_position)

	# Prioritise ice block when off cooldown and player is in range
	if _block_timer <= 0.0 and dist <= ICE_BLOCK_RANGE:
		_throw_ice_block(aim_dir)
		_block_timer = ICE_BLOCK_COOLDOWN
	elif _shard_timer <= 0.0 and dist <= ICE_SHARD_RANGE:
		_fire_ice_shard(aim_dir)
		_shard_timer = ICE_SHARD_COOLDOWN

func _fire_ice_shard(dir: Vector2) -> void:
	var shard := IceShardScript.new()
	shard.global_position = global_position + dir * 30.0
	shard.direction = dir
	shard.damage = ICE_SHARD_DAMAGE
	shard.owner_node = self
	get_tree().root.add_child(shard)
	NoiseService.emit_noise(get_tree(), global_position, 300.0)

func _throw_ice_block(dir: Vector2) -> void:
	var block := IceBlockScript.new()
	block.global_position = global_position + dir * 36.0
	block.direction = dir
	block.owner_node = self
	block.throw_damage = ICE_BLOCK_THROW_DAMAGE
	block.shatter_damage = ICE_BLOCK_SHATTER_DAMAGE
	get_tree().root.add_child(block)
	block.add_collision_exception_with(self)
	NoiseService.emit_noise(get_tree(), global_position, 400.0)
