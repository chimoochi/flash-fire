extends Node

const OVERLAY_LAYER := 126

var _canvas_layer: CanvasLayer
var _overlay: ColorRect
var _material: ShaderMaterial
var _canvas_modulate: CanvasModulate
var _time := 0.0
var _mood := "normal"
var _screen_tween: Tween

func _ready() -> void:
	_setup_canvas_modulate()
	_setup_overlay()
	await get_tree().process_frame
	_resize_overlay()
	get_viewport().size_changed.connect(_resize_overlay)
	set_mood("normal")

func _process(delta: float) -> void:
	_time += delta
	if _material:
		_material.set_shader_parameter("time", _time)

func set_mood(mode: String) -> void:
	_mood = mode
	var mood_tint := Color(1.0, 1.0, 1.0, 0.0)
	var world_tint := Color(1.0, 1.0, 1.0, 1.0)
	var vignette := 0.12
	var grain := 0.13
	var contrast := 0.04
	var saturation_loss := 0.015

	match mode:
		"fire":
			mood_tint = Color(1.12, 0.82, 0.66, 0.12)
			world_tint = Color(0.99, 0.94, 0.9, 1.0)
			vignette = 0.16
			grain = 0.145
			contrast = 0.07
		"ice":
			mood_tint = Color(0.78, 0.94, 1.22, 0.13)
			world_tint = Color(0.96, 0.98, 1.0, 1.0)
			vignette = 0.16
			grain = 0.14
			contrast = 0.08
		"boss":
			mood_tint = Color(0.76, 0.9, 1.22, 0.16)
			world_tint = Color(0.93, 0.95, 1.0, 1.0)
			vignette = 0.22
			grain = 0.16
			contrast = 0.11
			saturation_loss = 0.04
		"low_health":
			mood_tint = Color(1.28, 0.32, 0.22, 0.18)
			world_tint = Color(1.0, 0.92, 0.92, 1.0)
			vignette = 0.28
			grain = 0.17
			contrast = 0.12
			saturation_loss = 0.08
		"minigame":
			mood_tint = Color(1.16, 0.76, 0.5, 0.14)
			world_tint = Color(0.98, 0.94, 0.9, 1.0)
			vignette = 0.18
			grain = 0.155
			contrast = 0.09
		_:
			mood_tint = Color(1.04, 0.96, 0.94, 0.045)
			world_tint = Color(1.0, 1.0, 1.0, 1.0)

	_set_shader_value("mood_tint", mood_tint)
	_set_shader_value("vignette_strength", vignette)
	_set_shader_value("grain_amount", grain)
	_set_shader_value("contrast_amount", contrast)
	_set_shader_value("desaturation", saturation_loss)
	if _canvas_modulate:
		_canvas_modulate.color = world_tint

func player_hurt(flavor: String = "normal") -> void:
	var tint := Color(1.0, 0.04, 0.0, 1.0)
	if flavor == "ice":
		tint = Color(0.45, 0.84, 1.0, 1.0)
	elif flavor == "poison":
		tint = Color(0.45, 1.0, 0.22, 1.0)
	elif flavor == "fire":
		tint = Color(1.0, 0.28, 0.02, 1.0)
	_pulse_post(tint, 0.86, 0.52, -0.18, 0.0, 0.46)
	_set_shader_value("desaturation", 0.22)
	_tween_shader_value("desaturation", 0.22, _mood_desaturation(), 0.46)
	if CameraService:
		CameraService.kick(Vector2(0.045, 0.045), 0.12)

func enemy_hit(world_pos: Vector2, strength: float = 1.0) -> void:
	_pulse_post(Color(1.0, 0.48, 0.08, 1.0), clampf(0.18 * strength, 0.0, 0.28), 0.05, 0.04, 0.0, 0.18)
	if ParticleService:
		ParticleService.hit_sparks(world_pos, Vector2.ZERO, strength)

func enemy_killed(world_pos: Vector2, flavor: String = "normal") -> void:
	var tint := Color(1.0, 0.45, 0.08, 1.0)
	if flavor == "ice":
		tint = Color(0.55, 0.9, 1.0, 1.0)
	elif flavor == "fire":
		tint = Color(1.0, 0.28, 0.02, 1.0)
	_pulse_post(tint, 0.36, 0.04, 0.3, 0.0, 0.38)
	if ParticleService:
		ParticleService.pulse_light(world_pos, tint, 1.4, 0.16, 1.1)

func player_healed() -> void:
	_pulse_post(Color(0.22, 1.0, 0.34, 1.0), 0.46, 0.08, 0.12, 0.0, 0.42)

func boss_hit(world_pos: Vector2) -> void:
	_pulse_post(Color(0.55, 0.92, 1.0, 1.0), 0.34, 0.08, 0.2, 0.0, 0.3)
	if ParticleService:
		ParticleService.ice_shatter(world_pos, 1.35)
	if CameraService:
		CameraService.shake(0.22)

func death_flash() -> void:
	_pulse_screen(Color(1.0, 0.0, 0.0, 0.72), 0.9, 1.0, 0.55)

func boss_intro(world_pos: Vector2) -> void:
	set_mood("boss")
	_pulse_screen(Color(0.58, 0.88, 1.0, 0.42), 0.0, 0.28, 0.2)
	if ParticleService:
		ParticleService.ice_shatter(world_pos, 1.8)
		ParticleService.pulse_light(world_pos, Color(0.55, 0.9, 1.0), 2.4, 0.65)

func boss_death(world_pos: Vector2) -> void:
	_pulse_screen(Color(0.8, 0.95, 1.0, 0.58), 0.0, 0.82, 0.34)
	if ParticleService:
		ParticleService.ice_shatter(world_pos, 2.6)
		ParticleService.boss_shockwave(world_pos, Color(0.58, 0.92, 1.0, 0.86), 210.0)
		ParticleService.pulse_light(world_pos, Color(0.62, 0.92, 1.0), 3.2, 0.85)

func reset() -> void:
	if _screen_tween != null and _screen_tween.is_running():
		_screen_tween.kill()
	_set_shader_value("red_amount", 0.0)
	_set_shader_value("invert_amount", 0.0)
	_set_shader_value("flash_color", Color(0.0, 0.0, 0.0, 0.0))
	_set_shader_value("edge_amount", 0.0)
	_set_shader_value("vignette_pulse", 0.0)
	_set_shader_value("contrast_pulse", 0.0)
	set_mood("normal")

func _setup_canvas_modulate() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "GritCanvasModulate"
	add_child(_canvas_modulate)

func _setup_overlay() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "GritPostProcessLayer"
	_canvas_layer.layer = OVERLAY_LAYER
	add_child(_canvas_layer)

	_overlay = ColorRect.new()
	_overlay.name = "GritPostProcessOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.WHITE
	_canvas_layer.add_child(_overlay)

	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = _shader_code()
	_material.shader = shader
	_overlay.material = _material

	_set_shader_value("time", 0.0)
	_set_shader_value("red_amount", 0.0)
	_set_shader_value("invert_amount", 0.0)
	_set_shader_value("flash_color", Color(0.0, 0.0, 0.0, 0.0))
	_set_shader_value("edge_tint", Color(1.0, 0.0, 0.0, 1.0))
	_set_shader_value("edge_amount", 0.0)
	_set_shader_value("vignette_pulse", 0.0)
	_set_shader_value("contrast_pulse", 0.0)

func _resize_overlay() -> void:
	if _overlay and get_viewport():
		_overlay.position = Vector2.ZERO
		_overlay.size = get_viewport().get_visible_rect().size

func _pulse_screen(flash: Color, red: float, invert: float, duration: float) -> void:
	if _screen_tween != null and _screen_tween.is_running():
		_screen_tween.kill()
	_set_shader_value("edge_amount", 0.0)
	_set_shader_value("vignette_pulse", 0.0)
	_set_shader_value("contrast_pulse", 0.0)
	_set_shader_value("flash_color", flash)
	_set_shader_value("red_amount", red)
	_set_shader_value("invert_amount", invert)
	_screen_tween = create_tween().set_parallel(true)
	_screen_tween.tween_method(Callable(self, "_set_flash_color"), flash, Color(0.0, 0.0, 0.0, 0.0), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_screen_tween.tween_method(Callable(self, "_set_red_amount"), red, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_screen_tween.tween_method(Callable(self, "_set_invert_amount"), invert, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _pulse_post(edge_tint: Color, edge_amount: float, vignette_boost: float, contrast_boost: float, invert: float, duration: float) -> void:
	if _screen_tween != null and _screen_tween.is_running():
		_screen_tween.kill()
	_set_shader_value("flash_color", Color(0.0, 0.0, 0.0, 0.0))
	_set_shader_value("red_amount", 0.0)
	_set_shader_value("edge_tint", edge_tint)
	_set_shader_value("edge_amount", edge_amount)
	_set_shader_value("vignette_pulse", vignette_boost)
	_set_shader_value("contrast_pulse", contrast_boost)
	_set_shader_value("invert_amount", invert)
	_screen_tween = create_tween().set_parallel(true)
	_screen_tween.tween_method(Callable(self, "_set_edge_amount"), edge_amount, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_screen_tween.tween_method(Callable(self, "_set_vignette_pulse"), vignette_boost, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_screen_tween.tween_method(Callable(self, "_set_contrast_pulse"), contrast_boost, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_screen_tween.tween_method(Callable(self, "_set_invert_amount"), invert, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _tween_shader_value(name: StringName, from_value: float, to_value: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		_set_shader_value(name, value)
	, from_value, to_value, duration)

func _set_flash_color(value: Color) -> void:
	_set_shader_value("flash_color", value)

func _set_red_amount(value: float) -> void:
	_set_shader_value("red_amount", value)

func _set_invert_amount(value: float) -> void:
	_set_shader_value("invert_amount", value)

func _set_edge_amount(value: float) -> void:
	_set_shader_value("edge_amount", value)

func _set_vignette_pulse(value: float) -> void:
	_set_shader_value("vignette_pulse", value)

func _set_contrast_pulse(value: float) -> void:
	_set_shader_value("contrast_pulse", value)

func _set_shader_value(name: StringName, value) -> void:
	if _material:
		_material.set_shader_parameter(name, value)

func _mood_desaturation() -> float:
	match _mood:
		"boss":
			return 0.11
		"low_health":
			return 0.22
		_:
			return 0.03

func _shader_code() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float time = 0.0;
uniform float grain_amount = 0.12;
uniform float vignette_strength = 0.45;
uniform float contrast_amount = 0.22;
uniform float contrast_pulse = 0.0;
uniform float desaturation = 0.04;
uniform float red_amount = 0.0;
uniform float invert_amount = 0.0;
uniform float edge_amount = 0.0;
uniform float vignette_pulse = 0.0;
uniform vec4 flash_color : source_color = vec4(0.0);
uniform vec4 edge_tint : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 mood_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 screen = texture(screen_texture, uv);
	vec3 color = screen.rgb;

	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray), desaturation);
	color = (color - vec3(0.5)) * (1.0 + contrast_amount + contrast_pulse) + vec3(0.5);

	vec2 pixel = floor(FRAGCOORD.xy);
	float frame = floor(time * 24.0);
	float fine_grain = hash(pixel + vec2(frame * 47.0, frame * 113.0));
	float coarse_grain = hash(floor(pixel / 2.0) + vec2(frame * 19.0, frame * 71.0));
	float grain = mix(fine_grain, coarse_grain, 0.28) - 0.5;
	color += grain * grain_amount;
	color += vec3(hash(pixel + vec2(frame * 7.0, frame * 149.0)) - 0.5) * grain_amount * 0.18;

	float dist = distance(uv, vec2(0.5));
	float vignette = smoothstep(0.4, 0.92, dist);
	float edge = smoothstep(0.26, 0.86, dist);
	color *= 1.0 - vignette * (vignette_strength + vignette_pulse);
	color = mix(color, edge_tint.rgb, edge_amount * edge);

	color = mix(color, color * mood_tint.rgb, mood_tint.a);
	color = mix(color, vec3(1.0, 0.02, 0.0), red_amount * 0.48);
	color = mix(color, vec3(1.0) - color, invert_amount);
	color += flash_color.rgb * flash_color.a;

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.25)), 1.0);
}
"""
