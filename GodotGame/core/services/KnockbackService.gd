class_name KnockbackService

static func apply_knockback(source: Node2D, target: Node2D, power: float = 1000.0, multiplier: float = 1.0) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
		
	var direction = source.global_position.direction_to(target.global_position)

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
		
	var final_force = direction * power * multiplier
	
	if target.has_method("push"):
		target.push(final_force)
	elif target is CharacterBody2D:
		target.velocity += final_force
