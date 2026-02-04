extends CharacterBody2D

const MAX_SPEED = 600.0
const ACCELERATION = 3000.0
const FRICTION = 2000.0

const DASH_SPEED = 1000.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 0.8
const MELEE_DAMAGE = 25
const MELEE_KNOCKBACK = 800.0
const MELEE_ATTACK_DURATION = 0.25

const BULLET_SPEED = 1500.0
const PUSH_FORCE = 1500.0
const DASH_PUSH_FORCE = 4000.0
const PLAYER_PUSH_RESISTANCE = 50.0
const BULLET_SCENE = preload("res://player/bullet.tscn")
const THROWABLE_SCENE = preload("res://projectiles/throwable.tscn")
const THROW_SPEED = 600.0
@onready var melee_pivot: Node2D = $MeleePivot
@onready var weapon_visuals: Node2D = $MeleePivot/MeleeHitBox

var swing_melee: SwingMelee
var _dash_hit_entities: Array = []

var PlayerState: Dictionary = {
	"health": 100,
	"abilities": [],
	"passives": [],
	"is_alive": true,
	"is_swinging": false,
	"can_shoot": false,
	"is_dashing": false,
	"can_dash": true,
	"is_attacking": false
}

func _ready() -> void:
	add_to_group("Player")
	swing_melee = SwingMelee.new()
	add_child(swing_melee)


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
	
	_handle_push_interaction(delta)
	
	if PlayerState["is_attacking"]:
		pass # handled by SwingMelee
	
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

func _handle_push_interaction(delta: float) -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = global_transform
	query.collision_mask = 4
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_shape(query)
	for data in result:
		var collider = data["collider"]
		
		if PlayerState["is_dashing"] and collider.is_in_group("Enemy"):
			if collider in _dash_hit_entities:
				continue
			_dash_hit_entities.append(collider)
			print("Dash Impact Velocity: ", velocity)
			
		if collider.has_method("push"):
			var push_dir = (collider.global_position - global_position).normalized()
			
			var force_mag = PUSH_FORCE
			if PlayerState["is_dashing"]:
				force_mag = DASH_PUSH_FORCE
				
			collider.push(push_dir * force_mag * delta)
			
			if not PlayerState["is_dashing"]:
				velocity -= push_dir * PLAYER_PUSH_RESISTANCE
				velocity *= 0.9

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
	_dash_hit_entities.clear()
	
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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		throw_item()

func throw_item() -> void:
	var throwable = THROWABLE_SCENE.instantiate()
	get_tree().root.add_child(throwable)
	throwable.global_position = global_position
	var direction = (get_global_mouse_position() - global_position).normalized()
	throwable.velocity = direction * THROW_SPEED


func attack() -> void:
	var shoot_dir = Vector2.RIGHT.rotated(rotation)
	spawn_bullet(shoot_dir)
	
	swing()


func swing() -> void:
	if swing_melee.is_swinging:
		return
		
	PlayerState["is_swinging"] = true
	PlayerState["is_attacking"] = true
	
	swing_melee.swing(self, MELEE_DAMAGE, MELEE_KNOCKBACK, MELEE_ATTACK_DURATION)
	await swing_melee.attack_finished
	
	PlayerState["is_swinging"] = false
	PlayerState["is_attacking"] = false

			
func use_ability(ability_name: String) -> void:
	# Placeholder
	# But grab table of abilities from PlayerState, and use ability
	return
	

func transfer_abilities(enemy_killed) -> void:
	# Placeholder
	# But grab table of abilities from enemy killed, and add to PlayerState
	return

	
	#restart concurrent states, boot up new
