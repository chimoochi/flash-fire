extends Node

const MAX_DYNAMIC_LIGHTS := 12
const LIGHT_TEXTURE_SIZE := 64

var _light_texture: Texture2D
var _active_lights: Array[WeakRef] = []

func _ready() -> void:
	_light_texture = _build_light_texture()

func hit_sparks(pos: Vector2, dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	var direction := dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
	var particles := _make_particles("HitSparks", pos)
	particles.amount = int(22 * strength)
	particles.lifetime = 0.24
	particles.explosiveness = 0.88
	particles.direction = direction
	particles.spread = 76.0
	particles.gravity = Vector2(0.0, 95.0)
	particles.initial_velocity_min = 130.0 * strength
	particles.initial_velocity_max = 330.0 * strength
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.2
	particles.angular_velocity_min = -260.0
	particles.angular_velocity_max = 260.0
	particles.color_ramp = _gradient(Color(1.0, 0.98, 0.48, 1.0), Color(1.0, 0.12, 0.0, 0.0))
	particles.color = Color(1.0, 0.58, 0.08, 1.0)
	_start_one_shot(particles)
	pulse_light(pos, Color(1.0, 0.45, 0.05), clampf(1.0 + strength * 0.45, 1.0, 2.0), 0.18)

func fire_burst(pos: Vector2, strength: float = 1.0) -> void:
	var particles := _make_particles("FireBurst", pos)
	particles.amount = int(38 * strength)
	particles.lifetime = 0.42
	particles.explosiveness = 0.76
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, -45.0)
	particles.initial_velocity_min = 80.0 * strength
	particles.initial_velocity_max = 245.0 * strength
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 9.0
	particles.angular_velocity_min = -220.0
	particles.angular_velocity_max = 220.0
	particles.color_ramp = _gradient(Color(1.0, 0.92, 0.18, 1.0), Color(0.75, 0.02, 0.0, 0.0))
	particles.color = Color(1.0, 0.35, 0.03, 0.95)
	_start_one_shot(particles)
	pulse_light(pos, Color(1.0, 0.35, 0.04), clampf(1.5 * strength, 1.0, 2.8), 0.28)

func ice_shatter(pos: Vector2, strength: float = 1.0) -> void:
	var particles := _make_particles("IceShatter", pos)
	particles.amount = int(34 * strength)
	particles.lifetime = 0.46
	particles.explosiveness = 0.82
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 190.0)
	particles.initial_velocity_min = 95.0 * strength
	particles.initial_velocity_max = 300.0 * strength
	particles.scale_amount_min = 2.4
	particles.scale_amount_max = 7.0
	particles.angular_velocity_min = -280.0
	particles.angular_velocity_max = 280.0
	particles.color_ramp = _gradient(Color(0.82, 0.98, 1.0, 1.0), Color(0.14, 0.58, 1.0, 0.0))
	particles.color = Color(0.55, 0.92, 1.0, 0.94)
	_start_one_shot(particles)
	pulse_light(pos, Color(0.52, 0.9, 1.0), clampf(1.3 * strength, 1.0, 3.0), 0.32)

func dust_puff(pos: Vector2, strength: float = 1.0) -> void:
	var particles := _make_particles("DustPuff", pos)
	particles.amount = int(28 * strength)
	particles.lifetime = 0.55
	particles.explosiveness = 0.42
	particles.direction = Vector2.UP
	particles.spread = 145.0
	particles.gravity = Vector2(0.0, 80.0)
	particles.initial_velocity_min = 45.0 * strength
	particles.initial_velocity_max = 170.0 * strength
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 12.0
	particles.color_ramp = _gradient(Color(0.72, 0.68, 0.62, 0.55), Color(0.2, 0.18, 0.16, 0.0))
	particles.color = Color(0.55, 0.52, 0.48, 0.6)
	_start_one_shot(particles)

func floor_sparks(pos: Vector2, strength: float = 1.0) -> void:
	var particles := _make_particles("FloorSparks", pos)
	particles.amount = int(24 * strength)
	particles.lifetime = 0.28
	particles.explosiveness = 0.5
	particles.direction = Vector2.UP
	particles.spread = 105.0
	particles.gravity = Vector2(0.0, 280.0)
	particles.initial_velocity_min = 65.0 * strength
	particles.initial_velocity_max = 180.0 * strength
	particles.scale_amount_min = 1.8
	particles.scale_amount_max = 4.8
	particles.color_ramp = _gradient(Color(1.0, 0.9, 0.35, 1.0), Color(1.0, 0.12, 0.0, 0.0))
	particles.color = Color(1.0, 0.45, 0.05, 0.9)
	_start_one_shot(particles)

func boss_shockwave(pos: Vector2, color: Color, radius: float = 180.0) -> void:
	var ring := Line2D.new()
	ring.name = "BossShockwave"
	ring.width = 10.0
	ring.default_color = color
	ring.z_index = 80
	for i in range(49):
		var angle := TAU * float(i) / 48.0
		ring.add_point(Vector2.RIGHT.rotated(angle) * 12.0)
	_add_to_world(ring)
	ring.global_position = pos

	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(radius / 12.0, radius / 12.0), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var ring_ref: WeakRef = weakref(ring)
	tween.finished.connect(func() -> void:
		var node: Object = ring_ref.get_ref()
		if is_instance_valid(node):
			node.queue_free()
	)
	dust_puff(pos, 1.6)

func ember_trail(parent: Node2D, offset: Vector2 = Vector2.ZERO, amount: int = 28) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "EmberTrail"
	particles.position = offset
	particles.amount = amount
	particles.lifetime = 0.42
	particles.explosiveness = 0.0
	particles.direction = Vector2.DOWN
	particles.spread = 38.0
	particles.gravity = Vector2(0.0, 160.0)
	particles.initial_velocity_min = 55.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 2.2
	particles.scale_amount_max = 6.0
	particles.angular_velocity_min = -160.0
	particles.angular_velocity_max = 160.0
	particles.local_coords = false
	particles.color_ramp = _gradient(Color(1.0, 0.95, 0.3, 1.0), Color(1.0, 0.08, 0.0, 0.0))
	particles.color = Color(1.0, 0.45, 0.05, 0.9)
	if is_instance_valid(parent):
		parent.add_child(particles)
	else:
		_add_to_world(particles)
	return particles

func pulse_light(pos: Vector2, color: Color, energy: float = 1.4, duration: float = 0.25, scale: float = 1.25) -> void:
	var light := PointLight2D.new()
	light.name = "PulseLight"
	light.texture = _light_texture
	light.color = color
	light.energy = energy
	light.texture_scale = scale
	light.z_index = 70
	_add_to_world(light)
	light.global_position = pos
	_register_light(light)

	var tween := light.create_tween()
	tween.tween_property(light, "energy", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var light_ref: WeakRef = weakref(light)
	tween.finished.connect(func() -> void:
		_prune_lights()
		var node: Object = light_ref.get_ref()
		if is_instance_valid(node):
			node.queue_free()
	)

func _make_particles(node_name: String, pos: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = node_name
	particles.global_position = pos
	particles.one_shot = true
	particles.local_coords = false
	particles.z_index = 90
	_add_to_world(particles)
	return particles

func _start_one_shot(particles: CPUParticles2D) -> void:
	particles.emitting = true
	var particles_ref: WeakRef = weakref(particles)
	particles.finished.connect(func() -> void:
		var node: Object = particles_ref.get_ref()
		if is_instance_valid(node):
			node.queue_free()
	)

func _gradient(start_color: Color, end_color: Color) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, start_color)
	ramp.set_color(1, end_color)
	return ramp

func _add_to_world(node: Node) -> void:
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(node)
	else:
		get_tree().root.add_child(node)

func _register_light(light: PointLight2D) -> void:
	_prune_lights()
	_active_lights.append(weakref(light))
	while _active_lights.size() > MAX_DYNAMIC_LIGHTS:
		var old_ref: WeakRef = _active_lights.pop_front()
		var old_light = old_ref.get_ref()
		if is_instance_valid(old_light):
			old_light.queue_free()

func _prune_lights() -> void:
	var live_refs: Array[WeakRef] = []
	for light_ref in _active_lights:
		if light_ref.get_ref() != null:
			live_refs.append(light_ref)
	_active_lights = live_refs

func _build_light_texture() -> Texture2D:
	var image := Image.create(LIGHT_TEXTURE_SIZE, LIGHT_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(LIGHT_TEXTURE_SIZE, LIGHT_TEXTURE_SIZE) * 0.5
	var radius := float(LIGHT_TEXTURE_SIZE) * 0.5
	for y in range(LIGHT_TEXTURE_SIZE):
		for x in range(LIGHT_TEXTURE_SIZE):
			var dist := Vector2(x, y).distance_to(center) / radius
			var alpha := pow(clampf(1.0 - dist, 0.0, 1.0), 2.2)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
