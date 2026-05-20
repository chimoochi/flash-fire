extends Area2D

var speed := 700.0
var state := "warning"

const WARNING_DURATION := 1.2
const BLINK_DURATION := 0.8
const BLINK_INTERVAL := 0.07

var elapsed := 0.0
var blink_elapsed := 0.0
var _smoke: CPUParticles2D
var _fire_trail: CPUParticles2D

@onready var beam: ColorRect = $WarningBeam
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	sprite.visible = false
	beam.visible = true
	body_entered.connect(_on_body_entered)
	_setup_smoke()
	_setup_fire_trail()

func _setup_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.emitting = false
	_smoke.amount = 14
	_smoke.lifetime = 0.55
	_smoke.explosiveness = 0.0
	_smoke.direction = Vector2(0.0, -1.0)
	_smoke.spread = 22.0
	_smoke.gravity = Vector2.ZERO
	_smoke.initial_velocity_min = 35.0
	_smoke.initial_velocity_max = 90.0
	_smoke.scale_amount_min = 3.0
	_smoke.scale_amount_max = 7.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.82, 0.78, 0.7))
	ramp.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	_smoke.color_ramp = ramp
	_smoke.color = Color(0.8, 0.78, 0.74, 0.6)
	add_child(_smoke)

func _setup_fire_trail() -> void:
	_fire_trail = ParticleService.ember_trail(self, Vector2(0.0, -12.0), 42)
	_fire_trail.emitting = false
	_fire_trail.lifetime = 0.48
	_fire_trail.spread = 54.0
	_fire_trail.initial_velocity_min = 90.0
	_fire_trail.initial_velocity_max = 260.0
	_fire_trail.scale_amount_min = 3.0
	_fire_trail.scale_amount_max = 8.0

func _process(delta: float) -> void:
	elapsed += delta
	match state:
		"warning":
			if elapsed >= WARNING_DURATION:
				state = "blinking"
				elapsed = 0.0
				blink_elapsed = 0.0
		"blinking":
			blink_elapsed += delta
			if blink_elapsed >= BLINK_INTERVAL:
				blink_elapsed -= BLINK_INTERVAL
				beam.visible = !beam.visible
			if elapsed >= BLINK_DURATION:
				beam.visible = false
				sprite.visible = true
				sprite.z_index = 20
				state = "firing"
				elapsed = 0.0
				_smoke.emitting = true
				_fire_trail.emitting = true
				SoundService.play_sound_at("throw", global_position, -4.0)
				ParticleService.fire_burst(global_position, 0.75)
				ParticleService.pulse_light(global_position, Color(1.0, 0.36, 0.05), 2.0, 0.34, 1.7)
		"firing":
			position.y += speed * delta
			if position.y > 1400.0:
				queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(9999, global_position)
	else:
		get_tree().reload_current_scene()
	SoundService.play_sound_at("explode", global_position, -1.0)
	ParticleService.fire_burst(global_position, 1.8)
	ParticleService.boss_shockwave(global_position, Color(1.0, 0.35, 0.04, 0.78), 95.0)
	queue_free()
