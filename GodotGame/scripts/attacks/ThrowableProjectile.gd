extends CharacterBody2D
class_name ThrowableProjectile

signal landed(pos: Vector2)

var speed: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var air_duration: float = 1.0
var height_arc: float = 25.0
var rotation_speed: float = 15.0

var _current_time: float = 0.0
var _visual_child: Node2D = null
var _original_visual_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("Projectiles")
	for child in get_children(): # Todo: Make better, maybe even instanate from files isntead of this weird stuff
		if child is Node2D and not (child is CollisionShape2D):
			_visual_child = child
			_original_visual_pos = child.position
			break
	
	if not _visual_child:
		print("ThrowableProjectile: No visual child found!")
	else:
		print("ThrowableProjectile: Ready. Visual child: ", _visual_child.name)

func _physics_process(delta: float) -> void:
	_current_time += delta
	var t = clamp(_current_time / air_duration, 0.0, 1.0)
	
	var current_speed = speed * (1.0 - t)
	var collision = move_and_collide(direction * current_speed * delta)
	if collision:
		direction = direction.bounce(collision.get_normal())
		print("ThrowableProjectile: Bounced off ", collision.get_collider().name)
		
	if _visual_child:
		_visual_child.rotation += rotation_speed * delta
		# Formula: 4 * h * t * (1 - t)
		var height_offset = 4.0 * height_arc * t * (1.0 - t)
		_visual_child.position.y = _original_visual_pos.y - height_offset

	if _current_time >= air_duration:
		landed.emit(global_position)
		queue_free()
