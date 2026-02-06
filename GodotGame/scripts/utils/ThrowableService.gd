class_name ThrowableService

const EXPLOSION_SCENE = preload("res://projectiles/HitboxVisualizer.tscn")

static func throwing(startpos: Vector2, endpos: Vector2, speed: float, scene: PackedScene = null, owner_node: Node = null, duration: float = 1.0, arc_height: float = 50.0):
	var direction = (endpos - startpos).normalized()
	
	if scene:
		var projectile = ThrowableProjectile.new()
		projectile.global_position = startpos
		projectile.direction = direction
		projectile.speed = speed
		projectile.air_duration = duration
		projectile.height_arc = arc_height
		
		
		projectile.collision_layer = 0
		projectile.collision_mask = 1
		
		if owner_node and owner_node is CollisionObject2D:
			projectile.add_collision_exception_with(owner_node)
		
		
		var collider = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 5.0
		collider.shape = shape
		projectile.add_child(collider)
		
		
		var visual = scene.instantiate()
		projectile.add_child(visual)
		
		
		if owner_node:
			var root = owner_node.get_tree().root
			root.add_child(projectile)
		
		return projectile
	
	return direction * speed

static func explode(radius: float, position: Vector2, damage: int = 0, push_force: float = 0.0, source_node: Node = null):
	if not source_node:
		return

	var tree = source_node.get_tree()
	if not tree:
		return
		
		
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.global_position = position
	explosion.radius = radius # Set the radius for visualization
	tree.root.add_child(explosion)

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
				if source_node and source_node is Node2D and collider is Node2D:
					KnockbackService.apply_knockback(source_node, collider, push_force)
				elif collider.has_method("push"):
					var direction = (collider.global_position - position).normalized()
					if direction == Vector2.ZERO:
						direction = Vector2.RIGHT
					collider.push(direction * push_force)

static func lingering(duration, radius, position):
	pass
	
	## Ricochet, Rotate Item in Air, Arc, Velocity (start fast slow near end), Duration
