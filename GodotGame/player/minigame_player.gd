extends CharacterBody2D

var MAX_SPEED = 500.0
var SPRINT_SPEED = 600.0
var ACCELERATION = 3000.0
var FRICTION = 3000.0

const SPRINT_STAMINA_DRAIN = 15.0
const STAMINA_REGEN_RATE = 20.0
const STAMINA_REGEN_DELAY = 1.5

const PUSH_DECAY = 3000.0
const MAX_PUSH_VELOCITY = 400.0
const MAX_VELOCITY = 1200.0

var dash_speed := 1000.0
var dash_duration := 0.15
var dash_cooldown := 0.8

var stamina := 100.0
var max_stamina := 100.0
var _stamina_regen_timer := 0.0

var push_velocity := Vector2.ZERO

var _dash_service: DashService
var _canvas_layer: CanvasLayer
var _stamina_bar: ProgressBar

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("Player")

	_dash_service = DashService.new()
	add_child(_dash_service)

	_setup_ui()

func _setup_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	add_child(_canvas_layer)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.1, 0.2)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.65, 1.0)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(200, 12)
	_stamina_bar.max_value = max_stamina
	_stamina_bar.value = stamina
	_stamina_bar.show_percentage = false
	_stamina_bar.position = Vector2(41, 87)
	_stamina_bar.add_theme_stylebox_override("background", bg_style)
	_stamina_bar.add_theme_stylebox_override("fill", fill_style)
	_canvas_layer.add_child(_stamina_bar)

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("MoveRight"): direction.x += 1
	if Input.is_action_pressed("MoveLeft"):  direction.x -= 1
	if Input.is_action_pressed("MoveDown"):  direction.y += 1
	if Input.is_action_pressed("MoveUp"):    direction.y -= 1
	if direction.length() > 0:
		direction = direction.normalized()

	var is_sprinting := Input.is_action_pressed("Sprint") and direction != Vector2.ZERO and stamina > 0.0
	_process_stamina(delta, is_sprinting)
	var top_speed: float = SPRINT_SPEED if is_sprinting else MAX_SPEED

	push_velocity = push_velocity.move_toward(Vector2.ZERO, PUSH_DECAY * delta)

	if _dash_service.is_dashing:
		_dash_service.process_dash_physics(self, delta)
	else:
		if direction != Vector2.ZERO:
			velocity = velocity.move_toward(direction * top_speed, ACCELERATION * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		velocity += push_velocity
		velocity = velocity.limit_length(MAX_VELOCITY)
		move_and_slide()

	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("Dash") and _dash_service.can_dash:
		_dash_service.start_dash(self, direction, dash_speed, dash_duration, dash_cooldown, 0.0)

func _process_stamina(delta: float, is_sprinting: bool) -> void:
	if is_sprinting:
		stamina = max(0.0, stamina - SPRINT_STAMINA_DRAIN * delta)
		_stamina_regen_timer = STAMINA_REGEN_DELAY
	else:
		if _stamina_regen_timer > 0.0:
			_stamina_regen_timer -= delta
		else:
			stamina = min(max_stamina, stamina + STAMINA_REGEN_RATE * delta)
	if _stamina_bar:
		_stamina_bar.value = stamina

func push(force: Vector2) -> void:
	if _dash_service.is_dashing:
		return
	push_velocity += force
	if push_velocity.length() > MAX_PUSH_VELOCITY:
		push_velocity = push_velocity.limit_length(MAX_PUSH_VELOCITY)
