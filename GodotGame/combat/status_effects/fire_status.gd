extends Node2D

const TICK_INTERVAL := 0.5

var duration := 5.0
var damage_per_tick := 3
var source_node: Node2D = null

var _target: Node2D = null
var _tick_timer := 0.0
var _visual: CPUParticles2D = null

func _ready() -> void:
	_target = get_parent() as Node2D
	if not is_instance_valid(_target):
		queue_free()
		return
	_setup_visual()

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	duration -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		if _target.has_method("take_damage"):
			_target.take_damage(damage_per_tick, _target.global_position, source_node if is_instance_valid(source_node) else null)

	if duration <= 0.0:
		queue_free()

func refresh(new_duration: float) -> void:
	duration = max(duration, new_duration)

func _setup_visual() -> void:
	_visual = CPUParticles2D.new()
	_visual.name = "FireStatusVisual"
	_visual.amount = 22
	_visual.lifetime = 0.45
	_visual.explosiveness = 0.0
	_visual.direction = Vector2(0.0, -1.0)
	_visual.spread = 45.0
	_visual.gravity = Vector2(0.0, -80.0)
	_visual.initial_velocity_min = 22.0
	_visual.initial_velocity_max = 75.0
	_visual.scale_amount_min = 2.0
	_visual.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.25, 1.0))
	ramp.set_color(1, Color(1.0, 0.1, 0.0, 0.0))
	_visual.color_ramp = ramp
	_visual.color = Color(1.0, 0.45, 0.05, 0.95)
	add_child(_visual)
