extends EnemyBase

const SPLIT_COUNT = 3
const LEVEL1_SCENE = preload("res://enemy/level1.tscn")

const SLAM_RANGE := 48.0
const SLAM_DAMAGE := 18
const SLAM_KNOCKBACK := 520.0
const SLAM_COOLDOWN := 1.2
const SLAM_SHRINK_SCALE := 0.72
const SLAM_EXPAND_SCALE := 1.38

var _slam_cooldown_until: int = 0
var _is_slamming: bool = false

func _init() -> void:
	enemy_level = "level1"

func _ready() -> void:
	super._ready()
	equipped_power = {"name": "Slam", "settings": {"range": SLAM_RANGE, "cooldown": SLAM_COOLDOWN}, "type": PowerModule.PowerType.MELEE}
	EnemyState["Weapon_type"] = PowerModule.PowerType.MELEE
	EnemyState["health"] = 180
	EnemyState["max_health"] = 180
	if health_bar:
		health_bar.max_value = 180
		health_bar.value = 180
	modulate = Color(0.3, 1.0, 0.4)
	if melee_pivot:
		melee_pivot.visible = false

func _chase_target(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var dir_to_target = global_position.direction_to(target.global_position)
	var dist_to_target = global_position.distance_to(target.global_position)

	last_known_position = target.global_position
	_smooth_rotate(dir_to_target.angle(), delta)

	var drive := Vector2.ZERO
	if dist_to_target > SLAM_RANGE * 0.8:
		drive = dir_to_target * move_speed

	if not _is_slamming and dist_to_target <= SLAM_RANGE:
		var now = Time.get_ticks_msec()
		if now >= _slam_cooldown_until and now >= _frozen_until:
			_slam_cooldown_until = now + int(SLAM_COOLDOWN * 1000)
			_do_slam()

	_apply_movement(drive)

func _do_slam() -> void:
	_is_slamming = true

	var tween = create_tween()
	tween.tween_property(self , "scale", Vector2.ONE * SLAM_SHRINK_SCALE, 0.12)
	tween.tween_property(self , "scale", Vector2.ONE * SLAM_EXPAND_SCALE, 0.18)
	tween.tween_callback(_apply_slam_hit)
	tween.tween_property(self , "scale", Vector2.ONE, 0.14)
	tween.tween_callback(func(): _is_slamming = false)

func _apply_slam_hit() -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var hit_shape = CircleShape2D.new()
	hit_shape.radius = SLAM_RANGE * SLAM_EXPAND_SCALE
	query.shape = hit_shape
	query.transform = global_transform
	query.collision_mask = 2 | 4 # players layer 2 + enemies layer 4
	query.exclude = [ self.get_rid()]

	var results = space_state.intersect_shape(query, 16)
	for data in results:
		var body = data["collider"]
		var away = global_position.direction_to(body.global_position)

		if body.is_in_group("Player"):
			if body.has_method("take_damage"):
				body.take_damage(SLAM_DAMAGE, global_position, self )
			if body.has_method("push"):
				body.push(away * SLAM_KNOCKBACK)

		elif body.is_in_group("Enemy") and body != self:
			if body.has_method("push"):
				body.push(away * SLAM_KNOCKBACK * 0.5)

func die() -> void:
	EnemyState["is_alive"] = false
	died.emit()

	for i in range(SPLIT_COUNT):
		var child = LEVEL1_SCENE.instantiate()
		get_tree().root.add_child(child)
		var angle = (TAU / SPLIT_COUNT) * i
		child.global_position = global_position + Vector2.RIGHT.rotated(angle) * 30.0

	queue_free()
