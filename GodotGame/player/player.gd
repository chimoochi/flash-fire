extends CharacterBody2D

const SPEED = 600.0
const BULLET_SPEED = 1500.0
const BULLET_SCENE = preload("res://player/bullet.tscn")

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("MoveRight"):
		direction.x += 1
	if Input.is_action_pressed("MoveLeft"):
		direction.x -= 1
	if Input.is_action_pressed("MoveDown"):
		direction.y += 1
	if Input.is_action_pressed("MoveUp"):
		direction.y -= 1
	
	if direction.length() > 0:
		direction = direction.normalized()
	
	velocity = direction * SPEED
	move_and_slide()
	
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot"): 
		attack()

func attack() -> void:
	var shoot_dir = Vector2.RIGHT.rotated(rotation)
	spawn_bullet(shoot_dir)

func spawn_bullet(direction: Vector2) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = direction
	bullet.speed = BULLET_SPEED
	bullet.owner_node = self  # Bullet will ignore collisions with us
	get_tree().root.add_child(bullet)
	bullet.global_position = global_position
	bullet.rotation = rotation
