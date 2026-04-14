class_name LightningService
extends Object

static func activate(player: Node2D, range_dist: float = 400.0, fov: float = 70.0, max_chain: float = 400.0, max_targets: int = 3) -> void:
	var tree = player.get_tree()
	
	var target_group = "Enemy"
	if player.is_in_group("Enemy"):
		target_group = "Player"
		
	var enemies = tree.get_nodes_in_group(target_group)
	
	if enemies.is_empty():
		return
		
	var hit_enemies = []
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
			var width = 3.0 if i == 0 else 2.0
			var parent = player.get_parent()
			create_bolt(parent, current_position, best_candidate.global_position, width)
			
			if best_candidate.has_method("take_damage"):
				best_candidate.take_damage(8, current_position)
			
			if best_candidate.has_method("stun"):
				best_candidate.stun(0.2)
				
			hit_enemies.append(best_candidate)
			current_position = best_candidate.global_position
		else:
			break

static func create_bolt(parent: Node, start: Vector2, end: Vector2, width: float, segments: int = 8, jitter: float = 20.0, fade_time: float = 0.12) -> void:
	var dir = (end - start)
	var length = dir.length()
	var norm = dir.normalized()
	var perp = Vector2(-norm.y, norm.x)
	
	var points: PackedVector2Array = PackedVector2Array()
	points.append(start)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = start + dir * t
		var offset = perp * randf_range(-jitter, jitter)
		points.append(base_pos + offset)
	
	points.append(end)
	
	var core = Line2D.new()
	core.width = width
	core.default_color = Color(0.85, 0.9, 1.0, 1.0)
	core.joint_mode = Line2D.LINE_JOINT_ROUND
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	for p in points:
		core.add_point(p)
	parent.add_child(core)
	
	var glow = Line2D.new()
	glow.width = width * 3.0
	glow.default_color = Color(0.3, 0.5, 1.0, 0.35)
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	for p in points:
		glow.add_point(p)
	parent.add_child(glow)
	
	var tween = parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "modulate:a", 0.0, fade_time)
	tween.tween_property(glow, "modulate:a", 0.0, fade_time)
	tween.set_parallel(false)
	tween.tween_callback(core.queue_free)
	tween.tween_callback(glow.queue_free)

## Helper
static func _create_lightning(parent: Node, start: Vector2, end: Vector2, width: float) -> void:
	create_bolt(parent, start, end, width)
