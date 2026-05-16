extends Area2D

const SPEED := 580.0
const MAX_DISTANCE := 450.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 12
var owner_node: Node = null

var _start_pos: Vector2

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	_start_pos = global_position
	add_to_group("Projectiles")

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 6)
	col.shape = shape
	add_child(col)

	var rect := ColorRect.new()
	rect.size = Vector2(14, 6)
	rect.position = Vector2(-7.0, -3.0)
	rect.color = Color(0.5, 0.88, 1.0, 0.92)
	add_child(rect)

	rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	if global_position.distance_squared_to(_start_pos) > MAX_DISTANCE * MAX_DISTANCE:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == owner_node:
		return
	if body.is_in_group("Enemy"):
		return
	if body.is_in_group("Projectiles"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, _start_pos, owner_node if is_instance_valid(owner_node) else null)
	queue_free()
