extends Node
class_name ThrowableService

func throwing(startpos: Vector2, endpos: Vector2, speed: float, scene: PackedScene = null, owner_node: Node = null, duration: float = 1.0, arc_height: float = 50.0):
	var direction = (endpos - startpos).normalized()
	
	if scene:
		# Create wrapper for physics and arc logic
		var projectile = ThrowableProjectile.new()
		projectile.global_position = startpos
		projectile.direction = direction
		projectile.speed = speed
		projectile.air_duration = duration
		projectile.height_arc = arc_height
		
		# Collision settings
		projectile.collision_layer = 0 # Don't get hit by others
		projectile.collision_mask = 1  # Only hit World (walls)
		
		if owner_node and owner_node is CollisionObject2D:
			projectile.add_collision_exception_with(owner_node)
		
		# Collision shape for ricochet
		var collider = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 5.0 
		collider.shape = shape
		projectile.add_child(collider)
		
		# Visual payload
		var visual = scene.instantiate()
		projectile.add_child(visual)
		
		# Add to scene tree
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
					var direction = (collider.global_position - position).normalized()
					if direction == Vector2.ZERO:
						direction = Vector2.RIGHT
					collider.push(direction * push_force)

func lingering(duration, radius, position):
	
	pass
	
	## Ricochet, Rotate Item in Air, Arc, Velocity (start fast slow near end), Duration
	
