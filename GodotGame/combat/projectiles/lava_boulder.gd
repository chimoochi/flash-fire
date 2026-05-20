extends Area2D

const MAX_LIFETIME := 4.5

var direction: Vector2 = Vector2.RIGHT
var owner_node: Node = null
var target: Node2D = null
var speed := 360.0
var turn_rate := 1.7
var damage := 26
var push_force := 900.0
var health := 35
var damageable := true

var _life := 0.0

func _ready() -> void:
	add_to_group("Projectiles")
	collision_layer = 4
	collision_mask = 7
	if is_instance_valid(owner_node) and owner_node.is_in_group("Player"):
		collision_layer = 2
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= MAX_LIFETIME:
		_burst_and_free()
		return

	if is_instance_valid(target):
		var target_dir := global_position.direction_to(target.global_position)
		if target_dir != Vector2.ZERO:
			direction = direction.slerp(target_dir, clampf(turn_rate * delta, 0.0, 1.0)).normalized()

	global_position += direction * speed * delta
	rotation += 5.0 * delta

func _on_body_entered(body: Node) -> void:
	if body == owner_node:
		return
	if body.is_in_group("Projectiles"):
		return
	if owner_node and owner_node.is_in_group("Enemy") and body.is_in_group("Enemy"):
		return
	if owner_node and owner_node.is_in_group("Player") and body.is_in_group("Player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position, owner_node if is_instance_valid(owner_node) else null)
	if body is Node2D and body.has_method("push"):
		var away := global_position.direction_to(body.global_position)
		if away == Vector2.ZERO:
			away = direction
		body.push(away * push_force)
	_burst_and_free()

func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO, source: Node2D = null) -> void:
	if not damageable:
		return
	if is_instance_valid(owner_node) and is_instance_valid(source):
		if owner_node.is_in_group("Player") and source.is_in_group("Player"):
			return
		if owner_node.is_in_group("Enemy") and source.is_in_group("Enemy"):
			return
	health -= amount
	ParticleService.hit_sparks(global_position, Vector2.ZERO, 0.8)
	if health <= 0:
		_burst_and_free()

func _burst_and_free() -> void:
	ParticleService.fire_burst(global_position, 1.1)
	SoundService.play_sound_at("explode", global_position, -6.0)
	queue_free()
