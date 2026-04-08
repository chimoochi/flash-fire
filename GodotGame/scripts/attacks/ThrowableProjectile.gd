extends CharacterBody2D
class_name ThrowableProjectile

signal landed(pos: Vector2)

var speed: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var air_duration: float = 1.0
var height_arc: float = 25.0
var rotation_speed: float = 15.0

const ROLL_FRICTION := 400.0
const MIN_SPEED := 10.0

var _current_time: float = 0.0
var _visual_child: Node2D = null
var _original_visual_pos: Vector2 = Vector2.ZERO
var _has_landed: bool = false
var _is_rolling: bool = false
var _roll_speed: float = 0.0

func _ready() -> void:
	add_to_group("Projectiles")
	for child in get_children():
		if child is Node2D and not (child is CollisionShape2D):
			_visual_child = child
			_original_visual_pos = child.position
			break

func _physics_process(delta: float) -> void:
	if _has_landed:
		return

	if _is_rolling:
		_roll_speed = move_toward(_roll_speed, 0.0, ROLL_FRICTION * delta)
		
		if _roll_speed <= MIN_SPEED:
			_explode()
			return
		
		var collision = move_and_collide(direction * _roll_speed * delta)
		if collision:
			var collider = collision.get_collider()
			if collider and (collider.is_in_group("Enemy") or collider.is_in_group("Player")):
				_explode()
				return
			direction = direction.bounce(collision.get_normal())
		
		if _visual_child:
			_visual_child.rotation += rotation_speed * delta * (_roll_speed / speed)
		return

	_current_time += delta
	var t = clamp(_current_time / air_duration, 0.0, 1.0)
	
	var current_speed = speed * (1.0 - t * 0.5)
	var collision = move_and_collide(direction * current_speed * delta)
	
	if collision:
		var collider = collision.get_collider()
		
		if collider and (collider.is_in_group("Enemy") or collider.is_in_group("Player")):
			_explode()
			return
		
		direction = direction.bounce(collision.get_normal())
		
	if _visual_child:
		_visual_child.rotation += rotation_speed * delta
		var height_offset = 4.0 * height_arc * t * (1.0 - t)
		_visual_child.position.y = _original_visual_pos.y - height_offset

	if _current_time >= air_duration:
		_start_rolling()

func _start_rolling() -> void:
	_is_rolling = true
	_roll_speed = speed * 0.5
	height_arc = 0.0
	if _visual_child:
		_visual_child.position.y = _original_visual_pos.y

func _explode() -> void:
	_has_landed = true
	landed.emit(global_position)
	queue_free()
