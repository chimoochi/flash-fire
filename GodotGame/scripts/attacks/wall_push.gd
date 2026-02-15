extends Area2D
class_name WallPush

@export var SPEED := 400.0
@export var PUSH_FORCE := 3000.0
@export var LIFETIME := 2.0

var direction = Vector2.RIGHT

func _ready():
	var timer = get_tree().create_timer(LIFETIME)
	timer.timeout.connect(queue_free)
	
	var tween = create_tween()
	tween.tween_property(self, "scale:y", 0.0, LIFETIME)

func _physics_process(delta):
	var forward = Vector2.RIGHT.rotated(rotation)
	var bodies = get_overlapping_bodies()
	var blocked = false
	
	for body in bodies:
		if body is TileMap or body is StaticBody2D:
			blocked = true
			break
	
	if not blocked:
		position += forward * SPEED * delta

	for body in bodies:
		if body == self:
			continue
			
		if body.is_in_group("Enemy"):
			if body.has_method("push"):
				body.push(forward * PUSH_FORCE)
