extends CharacterBody2D

signal killed_by_player(power: Dictionary, passive_name: String)

@export var move_speed := 250.0
@export var turn_speed := 8.0

@export var vision_range := 400.0
@export var fov_angle := 70.0
@export var hearing_range := 90.0

@export var search_duration := 5.0

const PUSH_DECAY := 2000.0
const MAX_PUSH_VELOCITY := 800.0
const STOPPING_DISTANCE := 50.0
const ENEMY_PUSH_FORCE := 3000.0
const ENEMY_MELEE_DAMAGE := 10
const ENEMY_MELEE_KNOCKBACK := 500.0
const ENEMY_MELEE_DURATION := 0.5

enum State {IDLE, CHASING, SUSPICIOUS, FROZEN}

var EnemyState: Dictionary = {
	"health": 100,
	"max_health": 100,
	"is_alive": true,
	"behavior": State.IDLE,
	"Weapon_type": null
}
var is_execution_ready: bool = false
const LOW_HEALTH_THRESHOLD: int = 40
var target: Node2D = null
var last_known_position: Vector2 = Vector2.ZERO

var patience_timer := 0.0
var scan_angle := 0.0
var idle_look_angle := 0.0

@onready var ray_cast: RayCast2D = $RayCast2D
var health_bar_scene = preload("res://enemy/health_bar.tscn")
var health_bar: ProgressBar

var push_velocity: Vector2 = Vector2.ZERO

var swing_melee: SwingMelee
var melee_pivot: Node2D
var melee_visual: CollisionShape2D

var equipped_power: Dictionary
var equipped_passive: String = ""
var last_power_time: int = 0
var _frozen_until: int = 0
var _last_damage_source: Node2D = null

func _ready() -> void:
	add_to_group("Enemy")
	_acquire_target()
	_setup_health_bar()
	_setup_melee()
	
	idle_look_angle = rotation
	
	equipped_power = PowerModule.get_random_power()
	print(equipped_power)
	print(equipped_power.type)
	EnemyState["Weapon_type"] = equipped_power.type
	var random_passive = PassiveService.get_random_passive_name()
	if random_passive != "":
		PassiveService.add_passive(self, random_passive)
		equipped_passive = random_passive

func _setup_melee() -> void:
	melee_pivot = Node2D.new()
	melee_pivot.name = "MeleePivot"
	add_child(melee_pivot)
	
	melee_visual = CollisionShape2D.new()
	melee_visual.name = "MeleeHitBox"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 10)
	melee_visual.shape = shape
	
	var vis = ColorRect.new()
	vis.size = shape.size
	vis.position = - shape.size / 2
	vis.color = Color(1, 0, 0, 0.5)
	melee_visual.add_child(vis)
	
	melee_visual.position.x = 10.0
	
	melee_pivot.add_child(melee_visual)
	melee_pivot.position = Vector2(16, 16)
	melee_pivot.visible = false
	
	swing_melee = SwingMelee.new()
	add_child(swing_melee)

func _setup_health_bar() -> void:
	health_bar = health_bar_scene.instantiate()
	add_child(health_bar)
	health_bar.max_value = EnemyState["max_health"]
	health_bar.value = EnemyState["health"]

func push(force: Vector2) -> void:
	push_velocity += force
	if push_velocity.length() > MAX_PUSH_VELOCITY:
		push_velocity = push_velocity.limit_length(MAX_PUSH_VELOCITY)

func _handle_soft_collision(delta: float) -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = global_transform
	query.collision_mask = 4
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_shape(query)
	for data in result:
		var collider = data["collider"]
		
		if collider.is_in_group("Enemy") and collider.has_method("push"):
			var push_dir = (collider.global_position - global_position).normalized()
			collider.push(push_dir * ENEMY_PUSH_FORCE * delta)

func _physics_process(delta: float) -> void:
	_handle_soft_collision(delta)
	push_velocity = push_velocity.move_toward(Vector2.ZERO, PUSH_DECAY * delta)
	
	if not is_instance_valid(target):
		_acquire_target()
		_apply_movement(Vector2.ZERO)
		return
	
	var can_see_player = _can_see_target()
	
	match EnemyState["behavior"]:
		State.IDLE:
			if can_see_player:
				_set_state(State.CHASING)
			elif _can_hear_target():
				if _has_clear_line_of_fire(): _set_state(State.CHASING)
			else:
				_smooth_rotate(idle_look_angle, delta)
			_apply_movement(Vector2.ZERO)

		State.CHASING:
			if can_see_player:
				_chase_target(delta)
			else:
				_set_state(State.SUSPICIOUS)
				_apply_movement(Vector2.ZERO)

		State.SUSPICIOUS:
			if can_see_player:
				_set_state(State.CHASING)
			else:
				var dist_to_last_known = global_position.distance_to(last_known_position)
				if dist_to_last_known > STOPPING_DISTANCE:
					var dir = global_position.direction_to(last_known_position)
					_smooth_rotate(dir.angle(), delta)
					_apply_movement(dir * move_speed)
				else:
					_perform_search(delta)
					_apply_movement(Vector2.ZERO)
		
		State.FROZEN:
			_apply_movement(Vector2.ZERO)

	queue_redraw()

func _apply_movement(drive_velocity: Vector2) -> void:
	velocity = drive_velocity + push_velocity
	move_and_slide()
	push_velocity = velocity - drive_velocity

func _chase_target(delta: float) -> void:
	var dir_to_target = global_position.direction_to(target.global_position)
	var dist_to_target = global_position.distance_to(target.global_position)
	
	
	last_known_position = target.global_position
	
	_smooth_rotate(dir_to_target.angle(), delta)
	
	var drive = Vector2.ZERO
	var attack_range = equipped_power.settings.get("range", 100.0)
	
	if dist_to_target > attack_range * 0.8: # Close enough to use power
		drive = dir_to_target * move_speed
	
	var now = Time.get_ticks_msec()
	var cooldown_ms = equipped_power.settings.get("cooldown", 1.0) * 1000
	
	if dist_to_target <= attack_range and Time.get_ticks_msec() >= _frozen_until:
		if now - last_power_time >= cooldown_ms:
			last_power_time = now
			PowerModule.execute_power(equipped_power, self, target.global_position)
	
	_apply_movement(drive)

func _perform_search(delta: float) -> void:
	patience_timer -= delta
	
	_smooth_rotate(scan_angle, delta)
	
	if abs(angle_difference(rotation, scan_angle)) < 0.1:
		scan_angle = rotation + randf_range(-PI / 2, PI / 2)
	if patience_timer <= 0:
		_set_state(State.IDLE)
	
	_apply_movement(Vector2.ZERO)

func _smooth_rotate(target_angle: float, delta: float) -> void:
	rotation = lerp_angle(rotation, target_angle, delta * turn_speed)


func _set_state(new_state: State) -> void:
	EnemyState["behavior"] = new_state
	
	if new_state == State.SUSPICIOUS:
		patience_timer = search_duration
		scan_angle = rotation + randf_range(-1.5, 1.5)

func _acquire_target() -> void:
	target = get_tree().get_first_node_in_group("Player")
	if not target:
		target = get_tree().root.find_child("Player", true, false)

func _can_see_target() -> bool:
	var dist = global_position.distance_to(target.global_position)
	
	if dist > vision_range: return false
	if EnemyState["behavior"] == State.IDLE:
		var dir_to_target = (target.global_position - global_position).normalized()
		if abs(angle_difference(rotation, dir_to_target.angle())) > deg_to_rad(fov_angle / 2.0):
			return false

	return _has_clear_line_of_fire()

func _can_hear_target() -> bool:
	return global_position.distance_to(target.global_position) < hearing_range

func _has_clear_line_of_fire() -> bool:
	if not target: return false
	
	ray_cast.target_position = ray_cast.to_local(target.global_position)
	ray_cast.force_raycast_update()
	
	return ray_cast.get_collider() == target


func _draw() -> void:
	#red chasing, sus/idle orange / yellow
	var cone_color = Color(1, 0.2, 0.2, 0.3) if EnemyState["behavior"] == State.CHASING else Color(1, 0.7, 0.1, 0.15)
	
	#Cone
	var points = PackedVector2Array([Vector2.ZERO])
	var half_fov = deg_to_rad(fov_angle / 2.0)
	var segments = 20
	
	for i in range(segments + 1):
		var angle = lerp(-half_fov, half_fov, float(i) / segments)
		points.append(Vector2.RIGHT.rotated(angle) * vision_range)
	
	draw_polygon(points, [cone_color])
	draw_polyline(points, cone_color.darkened(0.2), 1.5)
	
	#circle
	draw_arc(Vector2.ZERO, hearing_range, 0, TAU, 32, Color(1, 1, 1, 0.1), 1.0)
	
	if EnemyState["behavior"] == State.SUSPICIOUS:
		var local_last_known = to_local(last_known_position)
		draw_line(local_last_known - Vector2(10, 10), local_last_known + Vector2(10, 10), Color(1, 1, 0, 0.5), 2)
		draw_line(local_last_known - Vector2(10, -10), local_last_known + Vector2(10, -10), Color(1, 1, 0, 0.5), 2)
	
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, source: Node2D = null) -> void:
	if source:
		_last_damage_source = source
	EnemyState["health"] -= amount
	if health_bar:
		health_bar.value = EnemyState["health"]
	
	if source_pos != Vector2.ZERO:
		var dir_to_source = global_position.direction_to(source_pos)
		var angle_to_source = dir_to_source.angle()
		rotation = angle_to_source
		idle_look_angle = angle_to_source
		last_known_position = source_pos
		
		if EnemyState["behavior"] == State.IDLE or EnemyState["behavior"] == State.SUSPICIOUS:
			EnemyState["behavior"] = State.SUSPICIOUS
			patience_timer = search_duration
			scan_angle = rotation
			
	if EnemyState["health"] <= LOW_HEALTH_THRESHOLD and not is_execution_ready:
		start_low_health_pulse()
			
	if EnemyState["health"] <= 0:
		die()

func start_low_health_pulse() -> void:
	is_execution_ready = true
	var tween = create_tween().set_loops()
	tween.tween_property(self, "modulate", Color.CYAN, 0.5)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)

func stun(duration: float) -> void:
	_frozen_until = Time.get_ticks_msec() + int(duration * 1000)
	var prev_state = EnemyState["behavior"]
	EnemyState["behavior"] = State.FROZEN
	
	await get_tree().create_timer(duration).timeout
	
	if is_instance_valid(self) and EnemyState["behavior"] == State.FROZEN:
		EnemyState["behavior"] = prev_state

func die() -> void:
	EnemyState["is_alive"] = false
	if is_instance_valid(_last_damage_source) and _last_damage_source.is_in_group("Player"):
		killed_by_player.emit(equipped_power, equipped_passive)
	queue_free()

func hear_noise(source_pos: Vector2, range_dist: float) -> void:
	if EnemyState["behavior"] != State.IDLE:
		return
		
	var dist = global_position.distance_to(source_pos)
	if dist <= range_dist:
		# print("Heard noise at ", source_pos)
		var dir = global_position.direction_to(source_pos)
		idle_look_angle = dir.angle()

func freeze(duration: float) -> void:
	if EnemyState["behavior"] == State.FROZEN:
		return
		
	var prev_state = EnemyState["behavior"]
	EnemyState["behavior"] = State.FROZEN
	
	modulate = Color(0.5, 0.5, 1.0)
	
	await get_tree().create_timer(duration).timeout
	
	if EnemyState["is_alive"]:
		if prev_state != State.FROZEN:
			EnemyState["behavior"] = prev_state
		else:
			EnemyState["behavior"] = State.CHASING # Default fallback
		modulate = Color.WHITE
