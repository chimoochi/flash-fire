extends CharacterBody2D


var MAX_SPEED = 300.0
var SPRINT_SPEED = 600.0
var ACCELERATION = 3000.0
var FRICTION = 4000.0

const STAMINA_PASSIVE_REGEN = 12.0
const STAMINA_CHARGE_REGEN = 35.0

const FIRE_BULLET_STAMINA_COST = 20.0
const FIRE_BULLET_START_SPEED = 150.0
const FIRE_BULLET_SPEED = 1400.0
const FIRE_BULLET_ACCEL = 4000.0
const FIRE_BULLET_STEER = 0.05
const FIRE_BULLET_KNOCKBACK = 2000.0
const FIRE_BULLET_DAMAGE = 40
const FIRE_BULLET_SELF_DAMAGE = 12
const FIRE_BULLET_DURATION = 0.7

const SHOTGUN_STAMINA_COST = 15.0
const SHOTGUN_DAMAGE = 12
const SHOTGUN_SPEED = 700.0
const SHOTGUN_SPREAD = 40.0
const SHOTGUN_COOLDOWN = 0.7
const SHOTGUN_RECOIL = 650.0

const FIREBALL_STAMINA_COST = 10.0
const FIREBALL_DAMAGE = 25
const FIREBALL_SPEED = 550.0
const FIREBALL_RECOIL = 1100.0
const FIREBALL_COOLDOWN = 0.5

const AOE_STAMINA_COST = 15.0
const AOE_DAMAGE = 35
const AOE_RADIUS = 130.0
const AOE_PUSH_FORCE = 1500.0
const AOE_COOLDOWN = 1.5

const DASH_STAMINA_COST = 20.0
const DASH_DAMAGE = 30

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
@onready var health_bar = $CanvasLayer/HUD/HealthSection/HealthBar
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var _hud = $CanvasLayer/HUD

var dash_service: DashService
var swing_melee: WaterPopper

var is_fire_bullet: bool = false
var fire_bullet_timer: float = 0.0
var _fire_bullet_hit: Array = []
var is_charging: bool = false
var _fireball_cooldown: float = 0.0
var _shotgun_cooldown: float = 0.0
var _aoe_cooldown: float = 0.0

var equipped_power: Dictionary
var last_power_time: int = 0
var push_velocity: Vector2 = Vector2.ZERO
var lightning_stream: Node = null
var weapon_visual: WeaponVisual = null

var kill_sound_player: AudioStreamPlayer

var PlayerState: Dictionary = {
	"health": 100,
	"max_health": 100,
	"scrap": 0,
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
	"is_invincible": false,

	"stamina": 100.0,
	"max_stamina": 100.0,
}


var _stamina_bar: ProgressBar = null

var debug_hitboxes: bool = false
var _selected_weapon: int = 0
var _rt_was_pressed: bool = false

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("Player")
	swing_melee = WaterPopper.new()
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
	_equip_weapon_visual()
	_setup_power_ui()
	
	var random_passive = PassiveService.get_random_passive_name()
	if random_passive != "":
		PassiveService.add_passive(self , random_passive)
	
	
	if MapService:
		MapService.restore_player_status(self )
	
	get_tree().node_added.connect(_on_node_added)
	
	call_deferred("_connect_existing_enemies")

func _connect_existing_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		_try_connect_enemy(enemy)

func _setup_power_ui() -> void:
	_hud.set_selected_slot(_selected_weapon)
	_stamina_bar = $CanvasLayer/HUD/StaminaSection/StaminaBar
	_stamina_bar.max_value = PlayerState["max_stamina"]
	_stamina_bar.value = PlayerState["stamina"]

func _update_cooldown_ui() -> void:
	if not _hud:
		return
	_hud.set_slot_cooldown(0, _fireball_cooldown / FIREBALL_COOLDOWN if _fireball_cooldown > 0.0 else 0.0)
	_hud.set_slot_cooldown(1, fire_bullet_timer / FIRE_BULLET_DURATION if is_fire_bullet else 0.0)
	_hud.set_slot_cooldown(2, _aoe_cooldown / AOE_COOLDOWN if _aoe_cooldown > 0.0 else 0.0)
	_hud.set_slot_cooldown(3, _shotgun_cooldown / SHOTGUN_COOLDOWN if _shotgun_cooldown > 0.0 else 0.0)

func _update_scrap_ui() -> void:
	pass


func on_passive_added(passive_name: String) -> void:
	if not PlayerState["passives"].has(passive_name):
		PlayerState["passives"].append(passive_name)
		_update_passive_ui()

func on_passive_removed(passive_name: String) -> void:
	if PlayerState["passives"].has(passive_name):
		PlayerState["passives"].erase(passive_name)
		_update_passive_ui()

func _update_passive_ui() -> void:
	pass


func _physics_process(delta):
	var direction = Vector2.ZERO

	if not is_fire_bullet:
		if Input.is_action_pressed("MoveRight"): direction.x += 1
		if Input.is_action_pressed("MoveLeft"): direction.x -= 1
		if Input.is_action_pressed("MoveDown"): direction.y += 1
		if Input.is_action_pressed("MoveUp"): direction.y -= 1
		if direction.length() > 0:
			direction = direction.normalized()

	is_charging = Input.is_action_pressed("Sprint") and not is_fire_bullet
	_process_stamina(delta, is_charging)

	if _fireball_cooldown > 0: _fireball_cooldown -= delta
	if _shotgun_cooldown > 0: _shotgun_cooldown -= delta
	if _aoe_cooldown > 0: _aoe_cooldown -= delta
	_update_cooldown_ui()

	if debug_hitboxes:
		melee_pivot.visible = true

	_handle_push_interaction(delta)
	push_velocity = push_velocity.move_toward(Vector2.ZERO, PUSH_DECAY * delta)

	if is_fire_bullet:
		_process_fire_bullet(delta)
	elif dash_service.is_dashing:
		dash_service.process_dash_physics(self, delta)
	else:
		_handle_movement_physics(direction, delta, MAX_SPEED)
		velocity += push_velocity
		velocity = velocity.limit_length(MAX_VELOCITY)
		move_and_slide()

	_move_mouse_with_stick(delta)
	look_at(get_global_mouse_position())



	var rt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	if rt > 0.5 and not _rt_was_pressed:
		_fire_selected_weapon()
	_rt_was_pressed = rt > 0.5

	if not dash_service.is_dashing:
		if Input.is_action_just_pressed("Dash") and dash_service.can_dash and PlayerState["stamina"] >= DASH_STAMINA_COST:
			PlayerState["stamina"] -= DASH_STAMINA_COST
			dash_service.start_dash(self, direction, PlayerState["dash_speed"], PlayerState["dash_duration"], PlayerState["dash_cooldown"], PlayerState["dash_push_force"])

	if Input.is_action_just_pressed("shoot") and PlayerState["stamina"] >= FIREBALL_STAMINA_COST and _fireball_cooldown <= 0:
		_activate_fireball()

	if Input.is_action_just_pressed("fire_bullet") and PlayerState["stamina"] >= FIRE_BULLET_STAMINA_COST and not is_fire_bullet:
		_activate_fire_bullet()

	if Input.is_action_just_pressed("shotgun") and PlayerState["stamina"] >= SHOTGUN_STAMINA_COST and _shotgun_cooldown <= 0:
		_activate_shotgun()

	if Input.is_action_just_pressed("aoe") and PlayerState["stamina"] >= AOE_STAMINA_COST and _aoe_cooldown <= 0:
		_activate_aoe()

func _process_stamina(delta: float, charging: bool) -> void:
	var regen = STAMINA_CHARGE_REGEN if charging else STAMINA_PASSIVE_REGEN
	PlayerState["stamina"] = min(PlayerState["max_stamina"], PlayerState["stamina"] + regen * delta)
	if _stamina_bar:
		_stamina_bar.value = PlayerState["stamina"]
		
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

			if is_fire_bullet and collider.is_in_group("Enemy"):
				collider.push(push_dir * FIRE_BULLET_KNOCKBACK)
				if not _fire_bullet_hit.has(collider) and collider.has_method("take_damage"):
					_fire_bullet_hit.append(collider)
					collider.take_damage(FIRE_BULLET_DAMAGE, global_position, self)
			else:
				var force_mag = PUSH_FORCE
				if dash_service.is_dashing:
					force_mag = dash_service.dash_push_force
				collider.push(push_dir * force_mag * delta)
				if dash_service.is_dashing and collider.is_in_group("Enemy") and collider.has_method("take_damage"):
					if not dash_service._hit_entities.has(collider):
						collider.take_damage(DASH_DAMAGE, global_position, self)
					dash_service.handle_impact(collider)
				elif not dash_service.is_dashing:
					velocity -= push_dir * PLAYER_PUSH_RESISTANCE
					velocity *= 0.9

func _move_mouse_with_stick(delta: float) -> void:
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() <= 0.15:
		return
	var vp := get_viewport()
	var new_pos := vp.get_mouse_position() + stick * 2000.0 * delta
	new_pos = new_pos.clamp(Vector2.ZERO, vp.get_visible_rect().size)
	vp.warp_mouse(new_pos)

func _handle_movement_physics(direction: Vector2, delta: float, max_speed: float = MAX_SPEED) -> void:
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * max_speed, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)


func _cycle_weapon(dir: int) -> void:
	_selected_weapon = (_selected_weapon + dir + 4) % 4
	if _hud:
		_hud.set_selected_slot(_selected_weapon)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_cycle_weapon(1)
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_cycle_weapon(-1)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(-1)

	if event.is_action_pressed("debug_toggle"):
		debug_hitboxes = not debug_hitboxes
	if event.is_action_pressed("music_toggle"):
		music_player.playing = not music_player.playing
	if event.is_action_pressed("interact"):
		var target = _get_nearest_execution_enemy()
		if target:
			_perform_glory_kill(target)
	if event.is_action_pressed("dev_level_switch"):
		var current_scene = get_tree().current_scene.scene_file_path
		var next_scene = "res://level2.tscn" if "workspace.tscn" in current_scene else "res://workspace.tscn"
		MapService.change_map(next_scene)


func _fire_selected_weapon() -> void:
	match _selected_weapon:
		0:
			if PlayerState["stamina"] >= FIREBALL_STAMINA_COST and _fireball_cooldown <= 0:
				_activate_fireball()
		1:
			if PlayerState["stamina"] >= FIRE_BULLET_STAMINA_COST and not is_fire_bullet:
				_activate_fire_bullet()
		2:
			if PlayerState["stamina"] >= AOE_STAMINA_COST and _aoe_cooldown <= 0:
				_activate_aoe()
		3:
			if PlayerState["stamina"] >= SHOTGUN_STAMINA_COST and _shotgun_cooldown <= 0:
				_activate_shotgun()


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
			var stream_script = load("res://combat/attacks/lightning_stream.gd")
			lightning_stream = stream_script.new()
			add_child(lightning_stream)
			lightning_stream.start(self )
		return

	last_power_time = now
	PowerModule.execute_power(equipped_power, self , get_global_mouse_position())


func _activate_fireball() -> void:
	PlayerState["stamina"] -= FIREBALL_STAMINA_COST
	_fireball_cooldown = FIREBALL_COOLDOWN
	var dir = (get_global_mouse_position() - global_position).normalized()
	BulletService.spawn_bullet(self, dir, FIREBALL_DAMAGE, FIREBALL_SPEED)
	velocity += -dir * FIREBALL_RECOIL
	velocity = velocity.limit_length(MAX_VELOCITY)
	CameraService.shake(0.15)


func _activate_aoe() -> void:
	PlayerState["stamina"] -= AOE_STAMINA_COST
	_aoe_cooldown = AOE_COOLDOWN
	ThrowableService.explode(AOE_RADIUS, global_position, AOE_DAMAGE, AOE_PUSH_FORCE, self, 15)
	CameraService.shake(0.5)
	CameraService.kick(Vector2(0.1, 0.1), 0.2)


func _activate_shotgun() -> void:
	PlayerState["stamina"] -= SHOTGUN_STAMINA_COST
	_shotgun_cooldown = SHOTGUN_COOLDOWN
	var dir = (get_global_mouse_position() - global_position).normalized()
	BulletService.spawn_shotgun(self, dir, SHOTGUN_DAMAGE, SHOTGUN_SPEED, SHOTGUN_SPREAD)
	velocity += -dir * SHOTGUN_RECOIL
	velocity = velocity.limit_length(MAX_VELOCITY)
	CameraService.shake(0.2)


func _activate_fire_bullet() -> void:
	if is_fire_bullet or PlayerState["stamina"] < FIRE_BULLET_STAMINA_COST:
		return
	PlayerState["stamina"] -= FIRE_BULLET_STAMINA_COST
	is_fire_bullet = true
	fire_bullet_timer = FIRE_BULLET_DURATION
	_fire_bullet_hit.clear()
	set_collision_mask_value(3, false)
	push_velocity = Vector2.ZERO
	var dir = (get_global_mouse_position() - global_position).normalized()
	velocity = dir * FIRE_BULLET_START_SPEED
	CameraService.shake(0.15)


func _process_fire_bullet(delta: float) -> void:
	fire_bullet_timer -= delta
	var current_speed = velocity.length()
	current_speed = min(current_speed + FIRE_BULLET_ACCEL * delta, FIRE_BULLET_SPEED)
	var target_dir = (get_global_mouse_position() - global_position).normalized()
	var steered_dir = velocity.normalized().lerp(target_dir, FIRE_BULLET_STEER).normalized()
	velocity = steered_dir * current_speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		_on_fire_bullet_wall_hit()
		return
	if fire_bullet_timer <= 0:
		_end_fire_bullet()

func _on_fire_bullet_wall_hit() -> void:
	ThrowableService.explode(80.0, global_position, 0, 900.0, self)
	take_damage(FIRE_BULLET_SELF_DAMAGE, global_position)
	velocity = -velocity.normalized() * 400.0
	CameraService.shake(0.4)
	_end_fire_bullet()

func _end_fire_bullet() -> void:
	is_fire_bullet = false
	fire_bullet_timer = 0.0
	_fire_bullet_hit.clear()
	set_collision_mask_value(3, true)

func absorb_loadout(power: Dictionary, passive_name: String) -> void:
	if kill_sound_player:
		kill_sound_player.play()
	_stop_stream()
	equipped_power = power
	last_power_time = 0
	_equip_weapon_visual()
	
	PassiveService.remove_all_passives(self )
	if passive_name != "":
		PassiveService.add_passive(self , passive_name)

func _equip_weapon_visual() -> void:
	if weapon_visual:
		weapon_visual.remove()
		weapon_visual = null
	if equipped_power.has("image"):
		weapon_visual = WeaponVisual.attach_from_config(weapon_visuals, equipped_power["image"])
	_equip_weapon_hitbox()

func _equip_weapon_hitbox() -> void:
	if not equipped_power.has("hitbox"):
		return
	var collision_shape := weapon_visuals as CollisionShape2D
	if not collision_shape:
		return
	var hb: Dictionary = equipped_power["hitbox"]
	var shape_type: String = hb.get("shape", "rectangle")
	var new_shape: Shape2D
	var hb_size: Vector2
	if shape_type == "circle":
		var r: float = hb.get("radius", 20.0)
		new_shape = CircleShape2D.new()
		(new_shape as CircleShape2D).radius = r
		hb_size = Vector2(r * 2, r * 2)
	else:
		hb_size = hb.get("size", Vector2(40, 10))
		new_shape = RectangleShape2D.new()
		(new_shape as RectangleShape2D).size = hb_size
	collision_shape.shape = new_shape
	collision_shape.position = hb.get("offset", Vector2(20.5, 0))
	for child in collision_shape.get_children():
		if child is ColorRect:
			child.size = hb_size
			child.position = - hb_size / 2

func _on_node_added(node: Node) -> void:
	call_deferred("_try_connect_enemy", node)

func _try_connect_enemy(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.is_in_group("Enemy"):
		if node.has_signal("killed_by_player") and not node.killed_by_player.is_connected(absorb_loadout):
			node.killed_by_player.connect(absorb_loadout)
		if node.has_signal("died") and not node.died.is_connected(_on_enemy_died):
			node.died.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	pass

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, source: Node2D = null) -> void:
	if not PlayerState["is_alive"] or PlayerState.get("is_invincible", false):
		return

	var reduced = max(int(amount * 0.6), 1)
	PlayerState["health"] -= reduced
	if health_bar:
		health_bar.set_health(PlayerState["health"])
	DamageNumber.spawn(get_tree(), global_position + Vector2(randf_range(-8, 8), -20), reduced, Color(1.0, 0.25, 0.25))
	CameraService.shake(0.35)

	if PlayerState["health"] <= 0:
		die()

func heal(amount: int) -> void:
	PlayerState["health"] = min(PlayerState["health"] + amount, PlayerState["max_health"])
	if health_bar:
		health_bar.set_health(PlayerState["health"])
	DamageNumber.spawn(get_tree(), global_position + Vector2(randf_range(-8, 8), -20), amount, Color(0.25, 1.0, 0.25))


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
	
	var spawn_points := get_tree().get_nodes_in_group("SpawnPoint")
	if spawn_points.size() > 0:
		global_position = spawn_points[0].global_position
	else:
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
	tween.tween_property(self , "global_position", capped_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) > 80.0:
		await get_tree().create_timer(1).timeout
		PlayerState["is_invincible"] = false
		return
	
	ThrowableService.explode(GLORY_KILL_RADIUS, global_position, GLORY_KILL_DAMAGE, GLORY_KILL_PUSH_FORCE, self )
	CameraService.shake(0.7)
	CameraService.kick(Vector2(0.08, 0.08), 0.2)

	var missing_health = PlayerState.get("max_health", 100) - PlayerState["health"]
	var heal_amount = ceil(missing_health * 0.15)
	PlayerState["health"] = min(PlayerState["health"] + heal_amount, PlayerState.get("max_health", 100))
	if health_bar:
		health_bar.set_health(PlayerState["health"])
	
	if target.has_method("take_damage"):
		target.take_damage(9999, global_position, self )
	elif target.has_method("die"):
		target.die()
	
	push_velocity = dash_dir * 800.0
	await get_tree().create_timer(1).timeout
	PlayerState["is_invincible"] = false
