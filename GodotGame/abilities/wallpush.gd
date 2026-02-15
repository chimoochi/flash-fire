extends Area2D

const SPEED = 400.0
const PUSH_FORCE = 3000.0
const LIFETIME = 2.0

var direction = Vector2.RIGHT

func _ready():
	var timer = get_tree().create_timer(LIFETIME)
	timer.timeout.connect(queue_free)

func _physics_process(delta):
	var forward = Vector2.RIGHT.rotated(rotation)
	position += forward * SPEED * delta

	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue
			
		if body.is_in_group("Enemy"):
			if body.has_method("push"):
				body.push(forward * PUSH_FORCE)
		elif body.is_in_group("Player"):
			pass
		else:
			if body is TileMap or body is StaticBody2D:
				queue_free()
				break
