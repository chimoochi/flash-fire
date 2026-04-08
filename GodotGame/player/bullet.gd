extends Area2D

var speed: float = 1500.0
var direction: Vector2 = Vector2.RIGHT
var max_distance: float = 2000.0
var start_position: Vector2
var owner_node: Node = null
var damage: int = 0

func _ready() -> void:
	start_position = global_position
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(start_position) > max_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == owner_node:
		return
	if body.is_in_group("Projectiles"):
		return
		
		
	if owner_node:
		var is_owner_player = owner_node.is_in_group("Player")
		var is_target_player = body.is_in_group("Player")
		var is_owner_enemy = owner_node.is_in_group("Enemy")
		var is_target_enemy = body.is_in_group("Enemy")
		
		
		if is_owner_player and is_target_player:
			return
		if is_owner_enemy and is_target_enemy:
			return
	
	if body.has_method("take_damage"):
		body.take_damage(damage, start_position, owner_node if is_instance_valid(owner_node) else null)
		
	print("Bullet hit: ", body.name, " at ", global_position)
	queue_free()
