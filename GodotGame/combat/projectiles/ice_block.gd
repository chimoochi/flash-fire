extends CharacterBody2D

const IceShardScript = preload("res://combat/projectiles/ice_shard.gd")

enum BlockState { MOVING, DORMANT }

const THROW_SPEED := 520.0
const FRICTION := 300.0
const DORMANT_SPEED_THRESHOLD := 30.0
const SHATTER_SHARD_COUNT := 8

var direction: Vector2 = Vector2.RIGHT
var owner_node: Node = null
var throw_damage: int = 18
var shatter_damage: int = 8

var _state := BlockState.MOVING
var _speed := THROW_SPEED
var _visual: ColorRect
var _player_detector: Area2D
var _pulse_tween: Tween
var _shattering := false

func _ready() -> void:
	# Layer 4 (Enemy) — player bullets (mask=7) can detect us via body_entered
	collision_layer = 4
	# Only stop on World layer walls; player collision handled by detector area
	collision_mask = 1

	_visual = ColorRect.new()
	_visual.size = Vector2(22.0, 22.0)
	_visual.position = Vector2(-11.0, -11.0)
	_visual.color = Color(0.55, 0.88, 1.0, 0.88)
	add_child(_visual)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22.0, 22.0)
	col.shape = shape
	add_child(col)

	# Separate area so we can detect the player body and projectile areas
	_player_detector = Area2D.new()
	_player_detector.collision_layer = 0
	_player_detector.collision_mask = 2  # Player layer
	var det_col := CollisionShape2D.new()
	var det_shape := RectangleShape2D.new()
	det_shape.size = Vector2(26.0, 26.0)
	det_col.shape = det_shape
	_player_detector.add_child(det_col)
	add_child(_player_detector)

	_player_detector.body_entered.connect(_on_detector_body_entered)
	_player_detector.area_entered.connect(_on_detector_area_entered)

func _physics_process(delta: float) -> void:
	if _state != BlockState.MOVING:
		return

	velocity = direction * _speed
	move_and_slide()
	_speed = max(0.0, _speed - FRICTION * delta)

	# Any wall collision → go dormant
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if is_instance_valid(collider) and collider != owner_node:
			_become_dormant()
			return

	if _speed <= DORMANT_SPEED_THRESHOLD:
		_become_dormant()

func _become_dormant() -> void:
	_state = BlockState.DORMANT
	velocity = Vector2.ZERO
	_speed = 0.0
	_visual.color = Color(0.7, 0.95, 1.0, 1.0)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_visual, "color", Color(0.35, 0.75, 1.0, 1.0), 0.6)
	_pulse_tween.tween_property(_visual, "color", Color(0.7, 0.95, 1.0, 1.0), 0.6)

func _on_detector_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return
	if _state == BlockState.MOVING:
		if body.has_method("take_damage"):
			body.take_damage(throw_damage, global_position, owner_node if is_instance_valid(owner_node) else null)
		shatter()

func _on_detector_area_entered(area: Area2D) -> void:
	if _state != BlockState.DORMANT:
		return
	# Shatter when any projectile area touches the dormant block
	if area.is_in_group("Projectiles"):
		shatter()

# Called by bullets (body_entered → take_damage) when they hit this CharacterBody2D
func take_damage(_amount: int, _source_pos: Vector2 = Vector2.ZERO, _source: Node2D = null) -> void:
	if _state == BlockState.DORMANT:
		shatter()

func shatter() -> void:
	if _shattering:
		return
	_shattering = true

	if _pulse_tween:
		_pulse_tween.kill()

	for i in SHATTER_SHARD_COUNT:
		var angle := (TAU / SHATTER_SHARD_COUNT) * i
		var shard := IceShardScript.new()
		shard.global_position = global_position
		shard.direction = Vector2.RIGHT.rotated(angle)
		shard.damage = shatter_damage
		shard.owner_node = owner_node if is_instance_valid(owner_node) else null
		get_tree().root.add_child(shard)

	queue_free()
