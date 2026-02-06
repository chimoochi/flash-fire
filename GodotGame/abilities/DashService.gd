extends Node
class_name DashService

@export var dash_speed: float = 1000.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8
@export var dash_push_force: float = 4000.0

var is_dashing: bool = false
var can_dash: bool = true

signal dash_started
signal dash_ended
signal cooldown_finished

var _hit_entities: Array = []

func start_dash(body: CharacterBody2D, direction: Vector2, speed: float, duration: float, cooldown: float = 0.8, push_force: float = 4000.0) -> void:
	if not can_dash:
		return

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(body.rotation)
	
	# Update internal params with passed values
	dash_speed = speed
	dash_duration = duration
	dash_cooldown = cooldown
	dash_push_force = push_force
	
	is_dashing = true
	can_dash = false
	
	body.velocity = direction * dash_speed
	
	dash_started.emit()
	
	await get_tree().create_timer(dash_duration).timeout
	
	stop_dash()
	
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true
	cooldown_finished.emit()

func stop_dash() -> void:
	is_dashing = false
	_hit_entities.clear()
	dash_ended.emit()

func process_dash_physics(body: CharacterBody2D, delta: float) -> void:
	if is_dashing:
		var collision = body.move_and_collide(body.velocity * delta)
		if collision:
			_handle_ricochet(body, collision)

func _handle_ricochet(body: CharacterBody2D, collision: KinematicCollision2D) -> void:
	var normal = collision.get_normal()
	body.velocity = body.velocity.bounce(normal)
	body.rotation = body.velocity.angle()

func handle_impact(collider: Node) -> void:
	if is_dashing and collider.is_in_group("Enemy"):
		if collider in _hit_entities:
			return
		_hit_entities.append(collider)
		# print("Dash Impact Velocity") - Optional debug
