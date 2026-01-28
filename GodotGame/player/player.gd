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
@onready var weapon_visuals: Node2D = $MeleePivot/MeleeHitBox # Or whatever node holds the sprite/shape

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
var default_weapon_rotation: float = 0.0
var default_weapon_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("Player")
	default_weapon_rotation = melee_pivot.rotation
	default_weapon_position = weapon_visuals.position

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
	
	if PlayerState["is_swinging"]:
		return
		
	PlayerState["is_swinging"] = true
	
	# --- SETTINGS ---
	var duration = 0.25
	# Start "behind" the aim (-135 deg) and end "in front" (+45 deg)
	# This creates a wide overhead swing.
	var start_angle = deg_to_rad(-135) 
	var end_angle = deg_to_rad(45) 
	
	var start_dist = 10.0 # Close to body
	var peak_dist = 50.0  # Max reach (The "Throw")
	
	# --- RESET & PREPARE ---
	# Kill any running tweens to prevent conflicts if we interrupt
	if get_tree_string_pretty().contains("tween"): 
		# Note: In a real project, store the active tween in a variable and .kill() it.
		pass 
	
	# 1. Orient the pivot to the start angle immediately
	melee_pivot.rotation = start_angle
	
	# 2. Set the weapon distance close to body (windup feel)
	weapon_visuals.position.x = start_dist
	
	# 3. Make sure it's visible (if you hide it during idle)
	weapon_visuals.visible = true
	
	# --- THE ANIMATION ---
	var tween = create_tween()
	
	# We run the Rotation and Extension in parallel
	tween.set_parallel(true)
	
	# A: ROTATION (The Arc)
	# TRANS_EXPO + EASE_OUT makes it start FAST (explosive) and slow down at the end
	tween.tween_property(melee_pivot, "rotation", end_angle, duration)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)
		
	# B: EXTENSION (The "Thrown" feel)
	# We move the sprite OUT and then slightly IN.
	# Using TRANS_BACK + EASE_OUT creates an "overshoot" effect, 
	# effectively throwing it out and pulling it back slightly.
	tween.tween_property(weapon_visuals, "position:x", peak_dist, duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	
	# --- HIT DETECTION ---
	# Check for hits specifically during the fastest part of the swing
	tween.set_parallel(false)
	tween.tween_callback(check_melee_hit).set_delay(duration * 0.2)
	
	# --- RESET ---
	await tween.finished
	
	var return_tween = create_tween()
	return_tween.set_parallel(true)
	# Rotate back to original idle rotation
	return_tween.tween_property(melee_pivot, "rotation", default_weapon_rotation, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return_tween.tween_property(weapon_visuals, "position:x", default_weapon_position.x, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await return_tween.finished
	
	# Hiding the weapon prevents the "stuck" feeling. 
	# It essentially tells the player "Action over".
	weapon_visuals.visible = true 
	
	# Optional: Small cooldown before allowing next swing logic
	await get_tree().create_timer(0.1).timeout
	PlayerState["is_swinging"] = false

func check_melee_hit() -> void:
	# Keep your existing logic, but maybe add a visual cue here
	var space_state = get_world_2d().direct_space_state
	var shape_node = $MeleePivot/MeleeHitBox
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_shape(query)
	for data in result:
		var collider = data["collider"]
		if collider.is_in_group("Enemy") and collider.has_method("take_damage"):
			collider.take_damage(25)
			# Add hitstop or shake here for impact
			CameraService.shake(0.1)
			
func use_ability(ability_name: String) -> void:
	# Placeholder
	# But grab table of abilities from PlayerState, and use ability
	return
	

func transfer_abilities(enemy_killed) -> void:
	# Placeholder
	# But grab table of abilities from enemy killed, and add to PlayerState
	return

	
	#restart concurrent states, boot up new
