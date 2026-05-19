extends CharacterBody2D

const OIL_PUDDLE_SCENE = preload("res://environment/oil_puddle.tscn")

enum BarrelState { MOVING, DORMANT }

const THROW_SPEED := 520.0
const FRICTION := 260.0
const DORMANT_SPEED_THRESHOLD := 35.0

var direction: Vector2 = Vector2.RIGHT
var owner_node: Node = null
var explosion_radius := 145.0
var explosion_damage := 22
var push_force := 1500.0

var _state := BarrelState.MOVING
var _speed := THROW_SPEED
var _exploded := false

func _ready() -> void:
	add_to_group("Enemy")
	collision_layer = 4
	collision_mask = 1

	var detector := get_node_or_null("Detector") as Area2D
	if detector:
		detector.body_entered.connect(_on_detector_body_entered)
		detector.area_entered.connect(_on_detector_area_entered)

func _physics_process(delta: float) -> void:
	if _state != BarrelState.MOVING:
		return
	velocity = direction * _speed
	move_and_slide()
	rotation += _speed * delta * 0.02
	_speed = max(0.0, _speed - FRICTION * delta)

	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if is_instance_valid(collider) and collider != owner_node:
			_become_dormant()
			return

	if _speed <= DORMANT_SPEED_THRESHOLD:
		_become_dormant()

func take_damage(_amount: int, _source_pos: Vector2 = Vector2.ZERO, _source: Node2D = null) -> void:
	_explode()

func _become_dormant() -> void:
	_state = BarrelState.DORMANT
	velocity = Vector2.ZERO
	_speed = 0.0

func _on_detector_body_entered(body: Node) -> void:
	if body == self or body == owner_node:
		return
	if body.is_in_group("Player") or body.is_in_group("Enemy"):
		_explode()

func _on_detector_area_entered(area: Area2D) -> void:
	if area.is_in_group("Projectiles") or area.get("is_player_bullet") == true:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_spawn_oil_puddle()
	ThrowableService.explode(explosion_radius, global_position, explosion_damage, push_force, owner_node if is_instance_valid(owner_node) else self)
	queue_free()

func _spawn_oil_puddle() -> void:
	var puddle := OIL_PUDDLE_SCENE.instantiate()
	puddle.lit = true
	get_tree().current_scene.add_child(puddle)
	puddle.global_position = global_position
