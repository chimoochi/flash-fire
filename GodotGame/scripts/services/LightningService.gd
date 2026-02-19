class_name LightningService
extends Object

## Activates the chain lightning effect from the player
static func activate(player: Node2D, range_dist: float = 400.0, fov: float = 70.0, max_chain: float = 400.0, max_targets: int = 10) -> void:
	var tree = player.get_tree()
	
	var target_group = "Enemy"
	if player.is_in_group("Enemy"):
		target_group = "Player"
		
	var enemies = tree.get_nodes_in_group(target_group)
	
	if enemies.is_empty():
		return
		
	var hit_enemies = []
	var current_source = player
	var current_position = player.global_position
	
	for i in range(max_targets):
		var best_candidate = null
		var closest_dist = INF
		
		for enemy in enemies:
			if not is_instance_valid(enemy): continue
			if enemy in hit_enemies: continue
			
			var dist = current_position.distance_to(enemy.global_position)
			
			
			if i == 0:
				if dist > range_dist: continue
				var player_dir = Vector2.RIGHT.rotated(player.rotation)
				var dir_to_enemy = (enemy.global_position - player.global_position).normalized()
				var angle_to = player_dir.angle_to(dir_to_enemy)
				if abs(angle_to) > deg_to_rad(fov / 2.0): continue
			
			else:
				if dist > max_chain: continue
				
			if dist < closest_dist:
				closest_dist = dist
				best_candidate = enemy
		
		if best_candidate:
			var width = 4.0 if i == 0 else 2.0
			var parent = player.get_parent()
			_create_lightning(parent, current_position, best_candidate.global_position, width)
			
			if best_candidate.has_method("take_damage"):
				best_candidate.take_damage(20, current_position)
			
			if best_candidate.has_method("freeze"):
				best_candidate.freeze(0.5)
				
			hit_enemies.append(best_candidate)
			current_source = best_candidate
			current_position = best_candidate.global_position
		else:
			break

static func _create_lightning(parent: Node, start: Vector2, end: Vector2, width: float) -> void:
	var line = Line2D.new()
	line.width = width
	line.default_color = Color(0.4, 0.6, 1.0, 1.0) # Light blue
	line.add_point(start)
	line.add_point(end)
	
	parent.add_child(line)
	
	# Fade out animation
	var tween = parent.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)
