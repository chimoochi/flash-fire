extends Node2D

const BEAM_RANGE := 640.0
const BEAM_DURATION := 1.2
const BEAM_DAMAGE_PER_TICK := 10
const BEAM_TICK_RATE := 0.09
const BEAM_SHAPE_WIDTH := 18.0

signal beam_ended

var _player: Node2D
var _duration_timer: float = BEAM_DURATION
var _damage_timer: float = 0.0
var _outer_line: Line2D
var _inner_line: Line2D
var _beam_end: Vector2 = Vector2.ZERO
var _beam_length: float = BEAM_RANGE
var _ember_particles: CPUParticles2D
var _tip_particles: CPUParticles2D
var _hit_sparks: CPUParticles2D
var _is_hitting: bool = false

func start(player: Node2D) -> void:
	_player = player
	_duration_timer = BEAM_DURATION
	_setup_visuals()

func _setup_visuals() -> void:
	_outer_line = Line2D.new()
	_outer_line.width = 16.0
	var outer_grad := Gradient.new()
	outer_grad.set_color(0, Color(1.0, 0.55, 0.1, 0.95))
	outer_grad.set_color(1, Color(1.0, 0.15, 0.0, 0.2))
	_outer_line.gradient = outer_grad
	_outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_outer_line.add_point(Vector2.ZERO)
	_outer_line.add_point(Vector2(BEAM_RANGE, 0.0))
	add_child(_outer_line)

	_inner_line = Line2D.new()
	_inner_line.width = 5.0
	_inner_line.default_color = Color(1.0, 0.97, 0.65, 1.0)
	_inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_inner_line.add_point(Vector2.ZERO)
	_inner_line.add_point(Vector2(BEAM_RANGE, 0.0))
	add_child(_inner_line)

	_ember_particles = CPUParticles2D.new()
	_ember_particles.amount = 30
	_ember_particles.lifetime = 0.45
	_ember_particles.explosiveness = 0.0
	_ember_particles.direction = Vector2(1.0, 0.0)
	_ember_particles.spread = 50.0
	_ember_particles.gravity = Vector2(0.0, -55.0)
	_ember_particles.initial_velocity_min = 60.0
	_ember_particles.initial_velocity_max = 190.0
	_ember_particles.scale_amount_min = 2.5
	_ember_particles.scale_amount_max = 6.0
	_ember_particles.angular_velocity_min = -120.0
	_ember_particles.angular_velocity_max = 120.0
	var ember_ramp := Gradient.new()
	ember_ramp.set_color(0, Color(1.0, 0.92, 0.3, 1.0))
	ember_ramp.set_color(1, Color(1.0, 0.15, 0.0, 0.0))
	_ember_particles.color_ramp = ember_ramp
	_ember_particles.color = Color(1.0, 0.6, 0.1, 0.9)
	add_child(_ember_particles)

	_tip_particles = CPUParticles2D.new()
	_tip_particles.amount = 20
	_tip_particles.lifetime = 0.25
	_tip_particles.explosiveness = 0.1
	_tip_particles.direction = Vector2(-1.0, 0.0)
	_tip_particles.spread = 75.0
	_tip_particles.gravity = Vector2.ZERO
	_tip_particles.initial_velocity_min = 45.0
	_tip_particles.initial_velocity_max = 130.0
	_tip_particles.scale_amount_min = 3.0
	_tip_particles.scale_amount_max = 7.0
	var tip_ramp := Gradient.new()
	tip_ramp.set_color(0, Color(1.0, 0.9, 0.25, 1.0))
	tip_ramp.set_color(1, Color(1.0, 0.05, 0.0, 0.0))
	_tip_particles.color_ramp = tip_ramp
	_tip_particles.color = Color(1.0, 0.45, 0.05, 0.95)
	add_child(_tip_particles)

	_hit_sparks = CPUParticles2D.new()
	_hit_sparks.amount = 28
	_hit_sparks.lifetime = 0.22
	_hit_sparks.explosiveness = 0.8
	_hit_sparks.direction = Vector2(-1.0, 0.0)
	_hit_sparks.spread = 95.0
	_hit_sparks.gravity = Vector2(0.0, 50.0)
	_hit_sparks.initial_velocity_min = 90.0
	_hit_sparks.initial_velocity_max = 260.0
	_hit_sparks.scale_amount_min = 2.0
	_hit_sparks.scale_amount_max = 5.0
	_hit_sparks.angular_velocity_min = -200.0
	_hit_sparks.angular_velocity_max = 200.0
	_hit_sparks.emitting = false
	var sparks_ramp := Gradient.new()
	sparks_ramp.set_color(0, Color(1.0, 0.98, 0.55, 1.0))
	sparks_ramp.set_color(1, Color(1.0, 0.1, 0.0, 0.0))
	_hit_sparks.color_ramp = sparks_ramp
	_hit_sparks.color = Color(1.0, 0.65, 0.1, 1.0)
	add_child(_hit_sparks)

func _physics_process(delta: float) -> void:
	_duration_timer -= delta
	if _duration_timer <= 0.0 or not is_instance_valid(_player):
		_finish()
		return

	_update_beam()

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = BEAM_TICK_RATE
		_deal_damage()

func _update_beam() -> void:
	global_position = _player.global_position
	var beam_dir := (_player.get_global_mouse_position() - global_position).normalized()
	rotation = beam_dir.angle()

	var world_end := global_position + beam_dir * BEAM_RANGE
	var space_state := _player.get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(global_position + beam_dir * 10.0, world_end, 5)
	ray.collide_with_areas = true
	ray.exclude = [_player.get_rid()]
	var hit := space_state.intersect_ray(ray)
	if hit:
		_beam_length = global_position.distance_to(hit.position)
		_is_hitting = true
	else:
		_beam_length = BEAM_RANGE
		_is_hitting = false
	_beam_end = global_position + beam_dir * _beam_length

	var end_local := Vector2(_beam_length, 0.0)
	_outer_line.set_point_position(1, end_local)
	_inner_line.set_point_position(1, end_local)
	_tip_particles.position = end_local
	_hit_sparks.position = end_local
	_hit_sparks.emitting = _is_hitting

	_outer_line.width = 18.0 + randf_range(-3.0, 4.0)
	_inner_line.width = 6.0 + randf_range(-1.5, 2.0)

func _deal_damage() -> void:
	if not is_instance_valid(_player) or _beam_length < 2.0:
		return

	var space_state := _player.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_beam_length, BEAM_SHAPE_WIDTH)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	var mid := (global_position + _beam_end) * 0.5
	query.transform = Transform2D(rotation, mid)
	query.collision_mask = 4

	var results := space_state.intersect_shape(query, 16)
	var hit_target := false
	for result in results:
		var collider = result["collider"]
		if collider != _player and collider.has_method("take_damage"):
			collider.take_damage(BEAM_DAMAGE_PER_TICK, global_position, _player)
			hit_target = true
	if hit_target:
		CameraService.shake(0.14)
		CameraService.kick(Vector2(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02)), 0.05)

func _finish() -> void:
	_ember_particles.emitting = false
	_tip_particles.emitting = false
	_hit_sparks.emitting = false
	beam_ended.emit()
	queue_free()
