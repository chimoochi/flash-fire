extends CharacterBody2D


var MAX_SPEED = 300.0
var SPRINT_SPEED = 600.0
var ACCELERATION = 3000.0
var FRICTION = 4000.0

const STAMINA_PASSIVE_REGEN = 12.0
const STAMINA_CHARGE_REGEN = 35.0

const FIRE_BEAM_STAMINA_COST = 25.0
const FIRE_BEAM_COOLDOWN = 2.0
const FIRE_BEAM_RECOIL = 700.0

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
@onready var _sprite: TextureRect = $TextureRect
@onready var _camera: Camera2D = $Camera2D

var dash_service: DashService
var swing_melee: WaterPopper

var _fire_beam: Node = null
var _fire_beam_cooldown: float = 0.0
var _fire_beam_sound_id: int = -1
var _walk_particles: CPUParticles2D
var _normal_sprite_texture: Texture2D = null

# Attack PNGs
const FIREBALL_ATTACK_TEX := "res://gameassets/textures/playercharacter/attacks/fireball.png"
const FIRE_BEAM_ATTACK_TEX := "res://gameassets/textures/playercharacter/attacks/fire beam.png"
const SHOTGUN_ATTACK_TEX := "res://gameassets/textures/playercharacter/attacks/shotgun.png"
const STOMP_ATTACK_TEX := "res://gameassets/textures/playercharacter/attacks/stomp.png"

const EXECUTE_BLINK_RANGE := 220.0
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
var _spawning: bool = false

var debug_hitboxes: bool = false
var _selected_weapon: int = 0
var _rt_was_pressed: bool = false

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("Player")
	_lock_camera_to_player()
	swing_melee = WaterPopper.new()
	add_child(swing_melee)
	
	melee_pivot.visible = false
	
	dash_service = DashService.new()
	add_child(dash_service)
	
	kill_sound_player = AudioStreamPlayer.new()
	kill_sound_player.stream = load("res://audio/kill.mp3")
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
	
	_normal_sprite_texture = _sprite.texture
	_setup_walk_particles()
	get_tree().node_added.connect(_on_node_added)

	call_deferred("_connect_existing_enemies")

func _lock_camera_to_player() -> void:
	_camera.position = Vector2.ZERO
	_camera.offset = Vector2.ZERO
	_camera.position_smoothing_enabled = false
	_camera.drag_horizontal_enabled = false
	_camera.drag_vertical_enabled = false
	_camera.drag_horizontal_offset = 0.0
	_camera.drag_vertical_offset = 0.0
	_camera.make_current()
	CameraService.current_camera = _camera

func _connect_existing_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		_try_connect_enemy(enemy)

func _setup_walk_particles() -> void:
	_walk_particles = CPUParticles2D.new()
	_walk_particles.amount = 22
	_walk_particles.lifetime = 0.38
	_walk_particles.explosiveness = 0.1
	_walk_particles.direction = Vector2(0.0, 1.0)
	_walk_particles.spread = 65.0
	_walk_particles.gravity = Vector2(0.0, 30.0)
	_walk_particles.initial_velocity_min = 30.0
	_walk_particles.initial_velocity_max = 85.0
	_walk_particles.scale_amount_min = 2.5
	_walk_particles.scale_amount_max = 5.5
	_walk_particles.local_coords = false
	_walk_particles.emitting = false
	_walk_particles.angular_velocity_min = -90.0
	_walk_particles.angular_velocity_max = 90.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.82, 0.55, 0.75))
	ramp.set_color(1, Color(0.65, 0.52, 0.38, 0.0))
	_walk_particles.color_ramp = ramp
	_walk_particles.color = Color(0.90, 0.75, 0.50, 0.7)
	_walk_particles.z_index = -1
	add_child(_walk_particles)

func _setup_power_ui() -> void:
	_hud.set_selected_slot(_selected_weapon)
	_stamina_bar = $CanvasLayer/HUD/StaminaSection/StaminaBar
	_stamina_bar.max_value = PlayerState["max_stamina"]
	_stamina_bar.value = PlayerState["stamina"]

func _update_cooldown_ui() -> void:
	if not _hud:
		return
	_hud.set_slot_cooldown(0, _fireball_cooldown / FIREBALL_COOLDOWN if _fireball_cooldown > 0.0 else 0.0)
	_hud.set_slot_cooldown(1, _fire_beam_cooldown / FIRE_BEAM_COOLDOWN if _fire_beam_cooldown > 0.0 else 0.0)
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


func play_spawn_intro() -> void:
	_spawning = true
	var sleeping_tex := load("res://gameassets/textures/playercharacter/sleeping.png") as Texture2D
	var normal_tex := _sprite.texture
	var normal_rotation := _sprite.rotation
	var normal_scale := _sprite.scale
	_sprite.texture = sleeping_tex
	_sprite.rotation = normal_rotation + PI / 2.0
	_sprite.scale = normal_scale * 1.4
	await get_tree().create_timer(3.0).timeout
	_sprite.texture = normal_tex
	_sprite.rotation = normal_rotation
	_sprite.scale = normal_scale
	_spawning = false

func _physics_process(delta):
	if _spawning:
		return
	var direction = Vector2.ZERO

	if Input.is_action_pressed("MoveRight"): direction.x += 1
	if Input.is_action_pressed("MoveLeft"): direction.x -= 1
	if Input.is_action_pressed("MoveDown"): direction.y += 1
	if Input.is_action_pressed("MoveUp"): direction.y -= 1
	if direction.length() > 0:
		direction = direction.normalized()

	is_charging = Input.is_action_pressed("Sprint")
	_process_stamina(delta, is_charging)

	if _fireball_cooldown > 0: _fireball_cooldown -= delta
	if _shotgun_cooldown > 0: _shotgun_cooldown -= delta
	if _aoe_cooldown > 0: _aoe_cooldown -= delta
	if _fire_beam_cooldown > 0: _fire_beam_cooldown -= delta
	_update_cooldown_ui()

	if debug_hitboxes:
		melee_pivot.visible = true

	_handle_push_interaction(delta)
	push_velocity = push_velocity.move_toward(Vector2.ZERO, PUSH_DECAY * delta)

	if dash_service.is_dashing:
		dash_service.process_dash_physics(self, delta)
	else:
		_handle_movement_physics(direction, delta, MAX_SPEED)
		velocity += push_velocity
		velocity = velocity.limit_length(MAX_VELOCITY)
		move_and_slide()

	_move_mouse_with_stick(delta)
	look_at(get_global_mouse_position())

	# Execute-range blink: only blink enemies within range
	_update_execute_blink()

	var speed_len := velocity.length()
	var is_walking := speed_len > 55.0 and not dash_service.is_dashing
	_walk_particles.emitting = is_walking
	if is_walking:
		_walk_particles.direction = (-velocity / speed_len).rotated(-rotation)

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

	if Input.is_action_just_pressed("fire_bullet") and PlayerState["stamina"] >= FIRE_BEAM_STAMINA_COST and _fire_beam_cooldown <= 0 and _fire_beam == null:
		_activate_fire_beam()

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

			if true:
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


func _update_execute_blink() -> void:
	var enemies := get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.get("is_execution_ready"):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= EXECUTE_BLINK_RANGE:
			if enemy.has_method("resume_pulse"):
				enemy.resume_pulse()
		else:
			if enemy.has_method("pause_pulse"):
				enemy.pause_pulse()

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
		SoundService.toggle_music()
	if event.is_action_pressed("interact"):
		var target = _get_nearest_execution_enemy()
		if target:
			_perform_glory_kill(target)
	if event.is_action_pressed("dev_level_switch"):
		var current_scene = get_tree().current_scene.scene_file_path
		var next_scene = "res://levels/level2.tscn" if "workspace.tscn" in current_scene else "res://levels/workspace.tscn"
		MapService.change_map(next_scene)


func _fire_selected_weapon() -> void:
	match _selected_weapon:
		0:
			if PlayerState["stamina"] >= FIREBALL_STAMINA_COST and _fireball_cooldown <= 0:
				_activate_fireball()
		1:
			if PlayerState["stamina"] >= FIRE_BEAM_STAMINA_COST and _fire_beam_cooldown <= 0 and _fire_beam == null:
				_activate_fire_beam()
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
	_stop_fire_beam_sound()

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


var _attack_sprite_timer: SceneTreeTimer = null

func _show_attack_sprite(tex_path: String, duration: float = 2.0) -> void:
	# Cancel any in-progress sprite timer so the new attack overrides immediately
	if _attack_sprite_timer != null:
		# Disconnect old timeout so it doesn't reset texture prematurely
		if _attack_sprite_timer.timeout.get_connections().size() > 0:
			for conn in _attack_sprite_timer.timeout.get_connections():
				_attack_sprite_timer.timeout.disconnect(conn["callable"])
		_attack_sprite_timer = null
	var tex := load(tex_path) as Texture2D
	if tex:
		_sprite.texture = tex
	var t := get_tree().create_timer(duration)
	_attack_sprite_timer = t
	t.timeout.connect(func():
		if _attack_sprite_timer == t:
			_sprite.texture = _normal_sprite_texture
			_attack_sprite_timer = null
	)

func _activate_fireball() -> void:
	PlayerState["stamina"] -= FIREBALL_STAMINA_COST
	_fireball_cooldown = FIREBALL_COOLDOWN
	var dir = (get_global_mouse_position() - global_position).normalized()
	BulletService.spawn_bullet(self, dir, FIREBALL_DAMAGE, FIREBALL_SPEED)
	SoundService.play_sound_at("fireball", global_position, -3.0, 0.5)
	velocity += -dir * FIREBALL_RECOIL
	velocity = velocity.limit_length(MAX_VELOCITY)
	CameraService.shake(0.15)
	_spawn_muzzle_particles(global_position + dir * 22.0, dir)
	_show_attack_sprite(FIREBALL_ATTACK_TEX, 1.0)


func _activate_aoe() -> void:
	PlayerState["stamina"] -= AOE_STAMINA_COST
	_aoe_cooldown = AOE_COOLDOWN
	SoundService.play_sound_at("stomp", global_position, -1.5)
	CameraService.shake(0.5)
	CameraService.kick(Vector2(0.1, 0.1), 0.2)
	_show_attack_sprite(STOMP_ATTACK_TEX, 1.0)
	_spawn_stomp_chain()


func _activate_shotgun() -> void:
	PlayerState["stamina"] -= SHOTGUN_STAMINA_COST
	_shotgun_cooldown = SHOTGUN_COOLDOWN
	var dir = (get_global_mouse_position() - global_position).normalized()
	BulletService.spawn_shotgun(self, dir, SHOTGUN_DAMAGE, SHOTGUN_SPEED, SHOTGUN_SPREAD)
	SoundService.play_sound_at("shotgun", global_position, -2.0)
	velocity += -dir * SHOTGUN_RECOIL
	velocity = velocity.limit_length(MAX_VELOCITY)
	CameraService.shake(0.2)
	_spawn_muzzle_particles(global_position + dir * 22.0, dir)
	_show_attack_sprite(SHOTGUN_ATTACK_TEX, 1.0)


func _activate_fire_beam() -> void:
	PlayerState["stamina"] -= FIRE_BEAM_STAMINA_COST
	_fire_beam_cooldown = FIRE_BEAM_COOLDOWN
	var dir := (get_global_mouse_position() - global_position).normalized()
	_stop_fire_beam_sound()
	_fire_beam_sound_id = SoundService.play_sound_at("fire_beam", global_position, -4.0, 1.0)
	velocity += -dir * FIRE_BEAM_RECOIL
	velocity = velocity.limit_length(MAX_VELOCITY)
	CameraService.shake(0.2)
	var beam_script := load("res://combat/attacks/fire_beam.gd")
	_fire_beam = beam_script.new()
	get_tree().root.add_child(_fire_beam)
	_fire_beam.start(self)
	# Show beam sprite for the full beam duration — clear when beam ends
	var beam_tex := load(FIRE_BEAM_ATTACK_TEX) as Texture2D
	if beam_tex:
		_sprite.texture = beam_tex
		if _attack_sprite_timer != null:
			for conn in _attack_sprite_timer.timeout.get_connections():
				_attack_sprite_timer.timeout.disconnect(conn["callable"])
			_attack_sprite_timer = null
	_fire_beam.beam_ended.connect(func():
		_fire_beam = null
		_stop_fire_beam_sound()
		_sprite.texture = _normal_sprite_texture
		_attack_sprite_timer = null
	)

func _stop_fire_beam_sound() -> void:
	if _fire_beam_sound_id == -1:
		return
	SoundService.stop_sound(_fire_beam_sound_id)
	_fire_beam_sound_id = -1


func _spawn_muzzle_particles(pos: Vector2, dir: Vector2) -> void:
	# Core flash burst
	var particles := CPUParticles2D.new()
	particles.global_position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 22
	particles.lifetime = 0.28
	particles.direction = Vector2(dir.x, dir.y)
	particles.spread = 32.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 320.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.98, 0.7, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.0, 0.0))
	particles.color_ramp = ramp
	particles.color = Color(1.0, 0.65, 0.1, 1.0)
	get_tree().root.add_child(particles)
	particles.finished.connect(particles.queue_free)
	# Back-scatter sparks
	var back := CPUParticles2D.new()
	back.global_position = pos
	back.emitting = true
	back.one_shot = true
	back.explosiveness = 0.85
	back.amount = 8
	back.lifetime = 0.18
	back.direction = -dir
	back.spread = 55.0
	back.gravity = Vector2.ZERO
	back.initial_velocity_min = 40.0
	back.initial_velocity_max = 100.0
	back.scale_amount_min = 1.5
	back.scale_amount_max = 3.5
	var back_ramp := Gradient.new()
	back_ramp.set_color(0, Color(1.0, 0.85, 0.3, 0.9))
	back_ramp.set_color(1, Color(1.0, 0.1, 0.0, 0.0))
	back.color_ramp = back_ramp
	back.color = Color(1.0, 0.5, 0.05, 0.8)
	get_tree().root.add_child(back)
	back.finished.connect(back.queue_free)

func _spawn_stomp_chain() -> void:
	var dir := (get_global_mouse_position() - global_position).normalized()

	# Step 1: full explosion at player feet (immediate)
	ThrowableService.explode(AOE_RADIUS, global_position, AOE_DAMAGE, AOE_PUSH_FORCE, self, 15)
	_spawn_stomp_burst(global_position, AOE_RADIUS, 5, 10)

	# Step 2: medium explosion 90px forward
	var pos2 := global_position + dir * 90.0
	var timer2 := get_tree().create_timer(0.18)
	timer2.timeout.connect(func():
		if not is_instance_valid(self): return
		SoundService.play_sound_at("stomp", pos2, -4.0)
		ThrowableService.explode(80.0, pos2, int(AOE_DAMAGE * 0.7), AOE_PUSH_FORCE * 0.7, self, 10)
		_spawn_stomp_burst(pos2, 80.0, 4, 7)
		CameraService.shake(0.3)
	)

	# Step 3: small explosion 165px forward
	var pos3 := global_position + dir * 165.0
	var timer3 := get_tree().create_timer(0.34)
	timer3.timeout.connect(func():
		if not is_instance_valid(self): return
		SoundService.play_sound_at("stomp", pos3, -7.0)
		ThrowableService.explode(55.0, pos3, int(AOE_DAMAGE * 0.45), AOE_PUSH_FORCE * 0.45, self, 6)
		_spawn_stomp_burst(pos3, 55.0, 3, 5)
		CameraService.shake(0.18)
	)

func _spawn_stomp_burst(pos: Vector2, radius: float, ray_count: int, particles_per_ray: int) -> void:
	for i in range(ray_count):
		var angle := (TAU / ray_count) * i
		var burst_dir := Vector2.RIGHT.rotated(angle)
		var p := CPUParticles2D.new()
		p.global_position = pos
		p.emitting = true
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = particles_per_ray
		p.lifetime = 0.38 + (radius / AOE_RADIUS) * 0.15
		p.direction = burst_dir
		p.spread = 28.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 80.0 + radius * 0.6
		p.initial_velocity_max = 200.0 + radius * 0.8
		p.scale_amount_min = 2.0 * (radius / AOE_RADIUS)
		p.scale_amount_max = 6.0 * (radius / AOE_RADIUS)
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.80, 0.15, 1.0))
		ramp.set_color(1, Color(1.0, 0.12, 0.0, 0.0))
		p.color_ramp = ramp
		p.color = Color(1.0, 0.55, 0.05, 0.95)
		get_tree().root.add_child(p)
		p.finished.connect(p.queue_free)

func absorb_loadout(power: Dictionary, passive_name: String) -> void:
	SoundService.play_sound_at("kill", global_position, -2.0)
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

	var damage_to_apply = max(amount, 1)
	PlayerState["health"] -= damage_to_apply
	if health_bar:
		health_bar.set_health(PlayerState["health"])
	DamageNumber.spawn(get_tree(), global_position + Vector2(randf_range(-8, 8), -20), damage_to_apply, Color(1.0, 0.25, 0.25))
	CameraService.shake(0.35)
	var flavor := _damage_flavor(source)
	VisualEffectsService.player_hurt(flavor)
	_play_hurt_sound(flavor)
	if PlayerState["health"] <= PlayerState["max_health"] * 0.3:
		VisualEffectsService.set_mood("low_health")

	if PlayerState["health"] <= 0:
		die()

func heal(amount: int) -> void:
	PlayerState["health"] = min(PlayerState["health"] + amount, PlayerState["max_health"])
	if health_bar:
		health_bar.set_health(PlayerState["health"])
	DamageNumber.spawn(get_tree(), global_position + Vector2(randf_range(-8, 8), -20), amount, Color(0.25, 1.0, 0.25))
	VisualEffectsService.player_healed()
	if PlayerState["health"] > PlayerState["max_health"] * 0.3:
		VisualEffectsService.set_mood("normal")

func _play_hurt_sound(flavor: String) -> void:
	if flavor == "fire":
		SoundService.play_sound_at("fire_hurt", global_position, -2.0)
	elif flavor == "ice":
		SoundService.play_sound_at("ice_crack", global_position, -8.0)


func die() -> void:
	PlayerState["is_alive"] = false
	VisualEffectsService.death_flash()
	visible = false
	set_physics_process(false)
	
	call_deferred("respawn")

func respawn() -> void:
	await get_tree().create_timer(2.0).timeout
	
	PlayerState["health"] = PlayerState["max_health"]
	PlayerState["is_alive"] = true
	VisualEffectsService.set_mood("normal")
	
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

func _damage_flavor(source: Node2D) -> String:
	if not is_instance_valid(source):
		return "normal"
	var source_level = source.get("enemy_level")
	if source_level is String and source_level.contains("ice"):
		return "ice"
	if source_level is String and source_level.contains("fire"):
		return "fire"
	var source_script: Script = source.get_script()
	var source_path: String = source_script.resource_path if source_script else ""
	if "ice" in source_path:
		return "ice"
	if "fire" in source_path:
		return "fire"
	return "normal"

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
	SoundService.play_sound_at("kill", global_position, -1.0)
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
