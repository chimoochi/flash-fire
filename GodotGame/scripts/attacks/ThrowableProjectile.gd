extends CharacterBody2D
class_name ThrowableProjectile

signal landed(pos: Vector2)

var speed: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var air_duration: float = 1.0
var height_arc: float = 50.0
var rotation_speed: float = 15.0

var _current_time: float = 0.0
var _visual_child: Node2D = null
var _original_visual_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Find the visual child (the payload scene)
	# We expect the structure: ThrowableProjectile -> [CollisionShape2D, VisualScene]
	for child in get_children():
		if child is Node2D and not (child is CollisionShape2D):
			_visual_child = child
			_original_visual_pos = child.position
			break
	
	if not _visual_child:
		print("ThrowableProjectile: No visual child found!")
	else:
		print("ThrowableProjectile: Ready. Visual child: ", _visual_child.name)

func _physics_process(delta: float) -> void:
	# 1. Movement with Ricochet
	# move_and_collide returns a KinematicCollision2D if a collision occurs
	var collision = move_and_collide(direction * speed * delta)
	if collision:
		direction = direction.bounce(collision.get_normal())
		print("ThrowableProjectile: Bounced off ", collision.get_collider().name)
		
	# 2. Timer & Duration
	_current_time += delta
	var t = clamp(_current_time / air_duration, 0.0, 1.0)
	
	# 3. Visuals (Arc & Rotation)
	if _visual_child:
		# Spin
		_visual_child.rotation += rotation_speed * delta
		
		# Arc (Parabola: 0 at start, 1 at mid, 0 at end)
		# Formula: 4 * h * t * (1 - t)
		var height_offset = 4.0 * height_arc * t * (1.0 - t)
		_visual_child.position.y = _original_visual_pos.y - height_offset

	# 4. Finish
	if _current_time >= air_duration:
		landed.emit(global_position)
		queue_free()
