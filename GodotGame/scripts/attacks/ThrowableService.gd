extends Node
class_name ThrowableService

func throwing(startpos: Vector2, endpos: Vector2, speed: float, scene: PackedScene = null, owner_node: Node = null):
	var direction = (endpos - startpos).normalized()
	
	if scene:
		var projectile = scene.instantiate()
		projectile.global_position = startpos
	
		if "direction" in projectile:
			projectile.direction = direction
		if "speed" in projectile:
			projectile.speed = speed
		if "owner_node" in projectile and owner_node:
			projectile.owner_node = owner_node
			
		var root = owner_node.get_tree().root if owner_node else get_tree().root
		root.add_child(projectile)
		return projectile
	
	return direction * speed

func explode(radius: float, position: Vector2, damage: int = 0, push_force: float = 0.0, source_node: Node = null):
	var tree = source_node.get_tree() if source_node else get_tree()
	if not tree:
		return

	var space_state = tree.root.get_world_2d().direct_space_state
	
	var shape = CircleShape2D.new()
	shape.radius = radius
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if source_node:
		query.exclude = [source_node.get_rid()]
	
	var result = space_state.intersect_shape(query)
	var hit_targets = []
	
	for data in result:
		var collider = data["collider"]
		
		if collider in hit_targets:
			continue
		hit_targets.append(collider)
		
		var is_friendly = false
		if source_node:
			if source_node.is_in_group("Player") and collider.is_in_group("Player"):
				is_friendly = true
			if source_node.is_in_group("Enemy") and collider.is_in_group("Enemy"):
				is_friendly = true
		
		if not is_friendly:
			if collider.has_method("take_damage") and damage > 0:
				collider.take_damage(damage)
			
			if push_force > 0:
				if source_node and source_node is Node2D:
					KnockbackService.apply_knockback(source_node, collider, push_force)
				elif collider.has_method("push"):
					# Manual knockback from explosion center
					var direction = (collider.global_position - position).normalized()
					if direction == Vector2.ZERO:
						direction = Vector2.RIGHT
					collider.push(direction * push_force)

func lingering(duration, radius, position):
	#DO NOT DO YET
	pass
