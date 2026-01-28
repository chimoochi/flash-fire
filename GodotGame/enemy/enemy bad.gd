extends CharacterBody2D


@export var move_speed := 250.0
@export var turn_speed := 8.0

@export var vision_range := 400.0
@export var fov_angle := 70.0
@export var hearing_range := 90.0

@export var search_duration := 5.0 

enum State { IDLE, CHASING, SUSPICIOUS }

var EnemyState: Dictionary = {
	"health": 100,
	"is_alive": true,
	"behavior": State.IDLE
}
var target: Node2D = null

var patience_timer := 0.0
var scan_angle := 0.0

@onready var ray_cast: RayCast2D = $RayCast2D

func _ready() -> void:
	add_to_group("Enemy")
	_acquire_target()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		_acquire_target()
		return
	
	var can_see_player = _can_see_target()
	
	
	match EnemyState["behavior"]:
		State.IDLE:
			if can_see_player:
				_set_state(State.CHASING)
			elif _can_hear_target(): 
				if _has_clear_line_of_fire(): _set_state(State.CHASING)

		State.CHASING:
			if can_see_player:
				_chase_target(delta)
			else:
				_set_state(State.SUSPICIOUS)

		State.SUSPICIOUS:
			if can_see_player:
				_set_state(State.CHASING)
			else:
				_perform_search(delta)

	queue_redraw()

func _chase_target(delta: float) -> void:
	var dir_to_target = global_position.direction_to(target.global_position)
	_smooth_rotate(dir_to_target.angle(), delta)
	
	velocity = dir_to_target * move_speed
	move_and_slide()

func _perform_search(delta: float) -> void:
	patience_timer -= delta
	
	_smooth_rotate(scan_angle, delta)
	
	if abs(angle_difference(rotation, scan_angle)) < 0.1:
		scan_angle = rotation + randf_range(-PI/2, PI/2)
	if patience_timer <= 0:
		_set_state(State.IDLE)

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
	
func take_damage(amount: int) -> void:
	EnemyState["health"] -= amount
	if EnemyState["health"] <= 0:
		die()

func die() -> void:
	EnemyState["is_alive"] = false
	queue_free()
