extends CharacterBody2D

const MAX_SPEED = 600.0
const ACCELERATION = 3000.0
const FRICTION = 2000.0

const DASH_SPEED = 1000.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 0.8

const BULLET_SPEED = 1500.0
const BULLET_SCENE = preload("res://player/bullet.tscn")
@onready var melee_pivot: Node2D = $MeleePivot

var PlayerState: Dictionary = {
	"health": 100,
	"abilities": [],
	"passives": [],
	"is_alive": true,
	"is_swinging": false,
	"can_shoot": false,
	"is_dashing": false,
	"can_dash": true
}
func _ready() -> void:
	add_to_group("Player")

func _physics_process(delta):
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
	
	if PlayerState["is_dashing"]:
		_handle_dash_physics(delta)
		var collision = move_and_collide(velocity * delta)
		if collision:
			_handle_ricochet(collision)
	else:
		_handle_movement_physics(direction, delta)
		move_and_slide()
	
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot"):
		attack()
	
	if Input.is_action_just_pressed("Dash") and PlayerState["can_dash"]:
		start_dash(direction)

func _handle_movement_physics(direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

func _handle_dash_physics(_delta: float) -> void:
	pass

func start_dash(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(rotation)
	
	PlayerState["is_dashing"] = true
	PlayerState["can_dash"] = false
	velocity = direction * DASH_SPEED
	
	await get_tree().create_timer(DASH_DURATION).timeout
	PlayerState["is_dashing"] = false
	
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	PlayerState["can_dash"] = true

func _handle_ricochet(collision: KinematicCollision2D) -> void:
	var normal = collision.get_normal()
	velocity = velocity.bounce(normal)
	rotation = velocity.angle()

func spawn_bullet(direction: Vector2) -> void:
	if not PlayerState["can_shoot"]:
		return
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = direction
	bullet.speed = BULLET_SPEED
	bullet.owner_node = self
	get_tree().root.add_child(bullet)
	bullet.global_position = global_position
	bullet.rotation = rotation


func attack() -> void:
	var shoot_dir = Vector2.RIGHT.rotated(rotation)
	spawn_bullet(shoot_dir)
	
	CameraService.shake(0.3)
	CameraService.kick(Vector2(0.05, 0.05))
	
	swing()

func swing() -> void:
	if PlayerState["is_swinging"]: # no spam
		return
		
	PlayerState["is_swinging"] = true
	var tween = create_tween()
	var start_rot = melee_pivot.rotation
	
	tween.tween_property(melee_pivot, "rotation", start_rot - PI / 2, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(check_melee_hit)
	tween.tween_property(melee_pivot, "rotation", start_rot, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween.finished
	PlayerState["is_swinging"] = false

func check_melee_hit() -> void:
	var space_state = get_world_2d().direct_space_state
	var shape_node = $MeleePivot/MeleeHitBox
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collide_with_areas = true # Just in case?
	query.collide_with_bodies = true
	
	var result = space_state.intersect_shape(query)
	for data in result:
		var collider = data["collider"]
		if collider.is_in_group("Enemy") and collider.has_method("take_damage"):
			collider.take_damage(25)

func use_ability(ability_name: String) -> void:
	# Placeholder
	# But grab table of abilities from PlayerState, and use ability
	return
	

func transfer_abilities(enemy_killed) -> void:
	# Placeholder
	# But grab table of abilities from enemy killed, and add to PlayerState
	return

	
	#restart concurrent states, boot up new
