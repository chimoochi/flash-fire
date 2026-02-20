extends CharacterBody2D


var MAX_SPEED = 600.0
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
const MAX_VELOCITY = 1200.0

const GLORY_KILL_DAMAGE = 20
const GLORY_KILL_RADIUS = 75.0
const GLORY_KILL_PUSH_FORCE = 2000.0

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
var passive_label: Label
var push_velocity: Vector2 = Vector2.ZERO
var lightning_stream: Node = null

var kill_sound_player: AudioStreamPlayer

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
	
	melee_pivot.visible = false
	
	dash_service = DashService.new()
	add_child(dash_service)
	
	kill_sound_player = AudioStreamPlayer.new()
	kill_sound_player.stream = load("res://gameassets/kill.mp3")
	add_child(kill_sound_player)
	
	health_bar.max_value = PlayerState["max_health"]
	health_bar.value = PlayerState["health"]
	
	equipped_power = PowerModule.get_random_power()
	_setup_power_ui()
	
	var random_passive = PassiveService.get_random_passive_name()
	if random_passive != "":
		PassiveService.add_passive(self, random_passive)
	
	get_tree().node_added.connect(_on_node_added)
	
	call_deferred("_connect_existing_enemies")

func _connect_existing_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		_try_connect_enemy(enemy)

func _setup_power_ui() -> void:
	power_label = Label.new()
	power_label.text = "Power: " + equipped_power.name
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	power_label.position = Vector2(41, 115)
	$CanvasLayer.add_child(power_label)
	
	passive_label = Label.new()
	passive_label.text = "Active Passives: None"
	passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	passive_label.position = Vector2(41, 140)
	$CanvasLayer.add_child(passive_label)

func on_passive_added(passive_name: String) -> void:
	if not PlayerState["passives"].has(passive_name):
		PlayerState["passives"].append(passive_name)
		_update_passive_ui()

func on_passive_removed(passive_name: String) -> void:
	if PlayerState["passives"].has(passive_name):
		PlayerState["passives"].erase(passive_name)
		_update_passive_ui()

func _update_passive_ui() -> void:
	if PlayerState["passives"].is_empty():
		passive_label.text = "Active Passives: None"
	else:
		passive_label.text = "Active Passives: " + ", ".join(PlayerState["passives"])


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
		velocity = velocity.limit_length(MAX_VELOCITY)
		move_and_slide()

	
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
	if dash_service.is_dashing:
		return
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
		if event.keycode == KEY_E:
			var target = _get_nearest_execution_enemy()
			if target:
				_perform_glory_kill(target)
	
	if event is InputEventKey and not event.pressed:
		if event.keycode == KEY_SPACE:
			_stop_stream()

func _stop_stream() -> void:
	if lightning_stream:
		lightning_stream.stop()
		lightning_stream.queue_free()
		lightning_stream = null

func use_equipped_power() -> void:
	if not PlayerState["is_alive"]:
		return
		
	var now = Time.get_ticks_msec()
	var cooldown_ms = equipped_power.settings.get("cooldown", 0.5) * 1000
	
	if now - last_power_time < cooldown_ms:
		return
		
	if equipped_power.name == "Lightning":
		if not lightning_stream:
			last_power_time = now
			var stream_script = load("res://scripts/attacks/lightning_stream.gd")
			lightning_stream = stream_script.new()
			add_child(lightning_stream)
			lightning_stream.start(self)
		return
	
	last_power_time = now
	PowerModule.execute_power(equipped_power, self, get_global_mouse_position())



			
func absorb_loadout(power: Dictionary, passive_name: String) -> void:
	if kill_sound_player:
		kill_sound_player.play()
	_stop_stream()
	equipped_power = power
	last_power_time = 0
	if power_label:
		power_label.text = "Power: " + power.name
	
	PassiveService.remove_all_passives(self)
	if passive_name != "":
		PassiveService.add_passive(self, passive_name)

func _on_node_added(node: Node) -> void:
	call_deferred("_try_connect_enemy", node)

func _try_connect_enemy(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.is_in_group("Enemy") and node.has_signal("killed_by_player"):
		if not node.killed_by_player.is_connected(absorb_loadout):
			node.killed_by_player.connect(absorb_loadout)

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, source: Node2D = null) -> void:
	if not PlayerState["is_alive"] or PlayerState.get("is_invincible", false):
		return

	var reduced = int(amount * 0.6)
	PlayerState["health"] -= reduced
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

func _get_nearest_execution_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var closest = null
	var closest_dist = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.get("is_execution_ready"):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	return closest

func _perform_glory_kill(target: Node2D) -> void:
	if not PlayerState["is_alive"]:
		return
	PlayerState["is_invincible"] = true
	
	var dash_dir = (target.global_position - global_position).normalized()
	var dist = global_position.distance_to(target.global_position)
	var max_dash_dist = 300.0
	var capped_pos = target.global_position if dist <= max_dash_dist else global_position + dash_dir * max_dash_dist
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", capped_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) > 80.0:
		await get_tree().create_timer(1).timeout
		PlayerState["is_invincible"] = false
		return
	
	ThrowableService.explode(GLORY_KILL_RADIUS, global_position, GLORY_KILL_DAMAGE, GLORY_KILL_PUSH_FORCE, self)
	
	if target.has_method("take_damage"):
		target.take_damage(9999, global_position, self)
	elif target.has_method("die"):
		target.die()
	
	push_velocity = dash_dir * 800.0
	await get_tree().create_timer(1).timeout
	PlayerState["is_invincible"] = false
