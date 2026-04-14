extends Area2D

var speed: float = 500.0
var direction: Vector2 = Vector2.RIGHT
var max_distance: float = 600.0
var start_position: Vector2
var damage: int = 15

func _ready() -> void:
	start_position = global_position
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(start_position) > max_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Projectiles"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, start_position, null)
	queue_free()
