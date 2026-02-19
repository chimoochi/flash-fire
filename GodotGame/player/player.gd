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
const PUSH_DECAY = 3000.0
const MAX_PUSH_VELOCITY = 400.0

const THROW_SPEED = 600.0

@onready var melee_pivot: Node2D = $MeleePivot
@onready var weapon_visuals: Node2D = $MeleePivot/MeleeHitBox
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var dash_service: DashService
var swing_melee: SwingMelee

var equipped_power: Dictionary
var last_power_time: int = 0
var power_label: Label
var push_velocity: Vector2 = Vector2.ZERO

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
	"is_attacking": false,
	"is_invincible": false
}

func _ready() -> void:
	add_to_group("Player")
	swing_melee = SwingMelee.new()
	add_child(swing_melee)
	
	dash_service = DashService.new()
	add_child(dash_service)
	
	health_bar.max_value = PlayerState["max_health"]
	health_bar.value = PlayerState["health"]
	
	equipped_power = PowerModule.get_random_power()
	_setup_power_ui()

func _setup_power_ui() -> void:
	power_label = Label.new()
	power_label.text = "Power: " + equipped_power.name
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Position it somewhere visible. 
	# CanvasLayer coordinates. HealthBar is likely top left.
	power_label.position = Vector2(20, 60) 
	$CanvasLayer.add_child(power_label)


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
	
	
	push_velocity = push_velocity.move_toward(Vector2.ZERO, PUSH_DECAY * delta)
	
	if dash_service.is_dashing:
		dash_service.process_dash_physics(self, delta)
	else:
		_handle_movement_physics(direction, delta)
		velocity += push_velocity
		move_and_slide()
		# Zero out push after applying — don't let it persist
		# The decay above handles the gradual fade
	
	look_at(get_global_mouse_position())

	
	if Input.is_action_just_pressed("Dash") and dash_service.can_dash:
		dash_service.start_dash(
			self,
			direction,
			PlayerState["dash_speed"],
			PlayerState["dash_duration"],
			PlayerState["dash_cooldown"],
			PlayerState["dash_push_force"]
		)
		
func push(force: Vector2) -> void:
	push_velocity += force
	if push_velocity.length() > MAX_PUSH_VELOCITY:
		push_velocity = push_velocity.limit_length(MAX_PUSH_VELOCITY)

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


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			use_equipped_power()
		if event.keycode == KEY_M:
			music_player.playing = not music_player.playing
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target = _get_enemy_under_mouse()
		if target and target.get("is_execution_ready"):
			_perform_glory_kill(target)

func use_equipped_power() -> void:
	if not PlayerState["is_alive"]:
		return
		
	var now = Time.get_ticks_msec()
	var cooldown_ms = equipped_power.settings.get("cooldown", 0.5) * 1000
	
	if now - last_power_time < cooldown_ms:
		return
		
	last_power_time = now
	PowerModule.execute_power(equipped_power, self, get_global_mouse_position())



			
func use_ability(ability_name: String) -> void:
	# Placeholder
	# But grab table of abilities from PlayerState, and use ability
	return
	
	
func transfer_abilities(enemy_killed) -> void:
	# Placeholder
	# But grab table of abilities from enemy killed, and add to PlayerState
	return

	
	#restart concurrent states, boot up new

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> void:
	if not PlayerState["is_alive"] or PlayerState.get("is_invincible", false):
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

func _get_enemy_under_mouse() -> Node2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 4 # Layer 3 (Enemies) if following standard
	
	# Actually standard mask might be different. Let's check collision mask of enemies.
	# Enemy usually on Layer 3 (value 4).
	
	var result = space_state.intersect_point(query)
	for data in result:
		var collider = data["collider"]
		if collider.is_in_group("Enemy"):
			return collider
	return null

func _perform_glory_kill(target: Node2D) -> void:
	PlayerState["is_invincible"] = true
	
	# Tween to target
	var tween = create_tween()
	tween.tween_property(self, "global_position", target.global_position, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	# Explosion
	# Radius 250, Damage 150 (huge), Push 2000
	ThrowableService.explode(250.0, global_position, 150, 2000.0, self)
	
	# Ensure target is dead specifically
	if is_instance_valid(target) and target.has_method("die"):
		target.die()
		
	PlayerState["is_invincible"] = false
