extends CharacterBody2D


const MAX_SPEED = 600.0
const ACCELERATION = 3000.0
const FRICTION = 2000.0

const DASH_COOLDOWN = 0.8
const MELEE_DAMAGE = 25
const MELEE_KNOCKBACK = 800.0
const MELEE_ATTACK_DURATION = 0.25

const BULLET_SPEED = 1500.0
const BULLET_DAMAGE = 20
const PUSH_FORCE = 1500.0
const PLAYER_PUSH_RESISTANCE = 50.0
const BULLET_SCENE = preload("res://player/bullet.tscn")
const THROWABLE_SCENE = preload("res://projectiles/throwable.tscn")
#const WALL_PUSH_SCENE = preload("res://abilities/wall_push.tscn") 
const THROW_SPEED = 600.0
@onready var melee_pivot: Node2D = $MeleePivot
@onready var weapon_visuals: Node2D = $MeleePivot/MeleeHitBox
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar

var dash_service: DashService

var swing_melee: SwingMelee

var PlayerState: Dictionary = {
	"health": 100,
	"max_health": 100,
	"abilities": [],
	"passives": [],
	"is_alive": true,
	"is_swinging": false,


	"can_shoot": true,
	"can_throw": true,
	"can_lightning": true,


	"is_dashing": false,
	"can_dash": true,
	"dash_speed": 1000.0,
	"dash_duration": 0.15,
	"dash_cooldown": 0.8,
	"dash_push_force": 4000.0,
	"is_attacking": false
}

func _ready() -> void:
	add_to_group("Player")
	swing_melee = SwingMelee.new()
	add_child(swing_melee)
	
	dash_service = DashService.new()
	add_child(dash_service)
	
	health_bar.max_value = PlayerState["max_health"]
	health_bar.value = PlayerState["health"]

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
	
	
	if dash_service.is_dashing:
		dash_service.process_dash_physics(self, delta)
	else:
		_handle_movement_physics(direction, delta)
		move_and_slide()
	
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot"):
		attack()
	
	if Input.is_action_just_pressed("Dash") and dash_service.can_dash:
		dash_service.start_dash(
			self,
			direction,
			PlayerState["dash_speed"],
			PlayerState["dash_duration"],
			PlayerState["dash_cooldown"],
			PlayerState["dash_push_force"]
		)

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
		
		if dash_service.is_dashing and collider.is_in_group("Enemy"):
			dash_service.handle_impact(collider)
			
			
		if collider.has_method("push"):
			var push_dir = (collider.global_position - global_position).normalized()
			
			var force_mag = PUSH_FORCE
			if dash_service.is_dashing:
				force_mag = dash_service.dash_push_force
				
			collider.push(push_dir * force_mag * delta)
			
			if not dash_service.is_dashing:
				velocity -= push_dir * PLAYER_PUSH_RESISTANCE
				velocity *= 0.9

func _handle_movement_physics(direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)


func spawn_bullet(direction: Vector2) -> void:
	if not PlayerState["can_shoot"]:
		return
		
	BulletService.spawn_bullet(self, direction, BULLET_DAMAGE, BULLET_SPEED)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if PlayerState["can_throw"]:
				throw_item()
			if PlayerState.get("can_lightning", false):
				LightningService.activate(self)
		elif event.keycode == KEY_R:
			spawn_wall()

func spawn_wall() -> void:
	var dir = Vector2.RIGHT.rotated(rotation)
	WallPushService.spawn_wall(self, dir)

func throw_item() -> void:
	if not PlayerState["can_throw"]: # disable for debug
		return
	var throwable = THROWABLE_SCENE.instantiate()
	get_tree().root.add_child(throwable)
	var dir = (get_global_mouse_position() - global_position).normalized()
	throwable.direction = dir
	throwable.speed = THROW_SPEED
	
	throwable.add_collision_exception_with(self)
	
	throwable.global_position = global_position + (dir * 20.0)
	
	var land_pos = await throwable.landed
	ThrowableService.explode(100.0, land_pos, 30, 1000.0, self)


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

func take_damage(amount: int) -> void:
	if not PlayerState["is_alive"]:
		return

	PlayerState["health"] -= amount
	if health_bar:
		health_bar.set_health(PlayerState["health"])
	
	if PlayerState["health"] <= 0:
		die()

func die() -> void:
	PlayerState["is_alive"] = false
	visible = false
	set_physics_process(false)
	
	call_deferred("respawn")

func respawn() -> void:
	await get_tree().create_timer(2.0).timeout
	
	PlayerState["health"] = PlayerState["max_health"]
	PlayerState["is_alive"] = true
	
	if health_bar:
		health_bar.set_health(PlayerState["health"])
	
	global_position = Vector2.ZERO
	velocity = Vector2.ZERO
	
	visible = true
	set_physics_process(true)
