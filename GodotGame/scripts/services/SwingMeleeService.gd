class_name SwingMeleeService

## Starts a melee swing attack.
## Returns the SwingInstance node that manages the attack, or null if invalid.
## The caller is responsible for ensuring the pivot and visual nodes are valid.
static func swing(
	owner_node: Node2D,
	pivot: Node2D,
	visual: Node2D,
	damage: int,
	knockback_force: float,
	duration: float = 0.4,
	angle_range_deg: float = 90.0,
	start_dist: float = 10.0,
	peak_dist: float = 50.0,
	shake_amount: float = 0.1
) -> SwingInstance:
	
	if not is_instance_valid(owner_node) or not is_instance_valid(pivot) or not is_instance_valid(visual):
		return null
		
	var instance = SwingInstance.new()
	instance.owner_node = owner_node
	instance.pivot = pivot
	instance.visual = visual
	instance.damage = damage
	instance.knockback_force = knockback_force
	instance.duration = duration
	instance.angle_range_deg = angle_range_deg
	instance.start_dist = start_dist
	instance.peak_dist = peak_dist
	instance.shake_amount = shake_amount
	
	owner_node.add_child(instance)
	return instance

class SwingInstance extends Node:
	signal hit(target: Node2D)
	signal finished
	
	var owner_node: Node2D
	var pivot: Node2D
	var visual: Node2D
	
	var damage: int
	var knockback_force: float
	var duration: float
	var angle_range_deg: float
	var start_dist: float
	var peak_dist: float
	var shake_amount: float
	
	var _is_swinging: bool = false
	var _hit_targets: Array = []
	var _default_rotation: float
	var _default_vis_pos: Vector2
	
	func _ready() -> void:
		_start_swing()
		
	func _start_swing() -> void:
		_default_rotation = pivot.rotation
		_default_vis_pos = visual.position
		
		_hit_targets.clear()
		_is_swinging = true
		
		var half_angle = deg_to_rad(angle_range_deg / 2.0)
		var start_angle = half_angle
		var end_angle = -half_angle
		
		pivot.visible = true
		pivot.rotation = start_angle
		visual.position.x = start_dist
		visual.visible = true
		
		var tween = create_tween()
		tween.tween_property(visual, "position:x", peak_dist, duration * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(pivot, "rotation", end_angle, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
		await tween.finished
		
		var return_tween = create_tween()
		return_tween.set_parallel(true)
		return_tween.tween_property(pivot, "rotation", _default_rotation, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		return_tween.tween_property(visual, "position:x", _default_vis_pos.x, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
		await return_tween.finished
		
		visual.visible = false
		pivot.visible = false
		
		_is_swinging = false
		finished.emit()
		queue_free()

	func _physics_process(_delta: float) -> void:
		if _is_swinging:
			_check_hit()
			
	func _check_hit() -> void:
		if not is_instance_valid(owner_node) or not is_instance_valid(visual):
			return
			
		var space_state = owner_node.get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		
		if visual is CollisionShape2D:
			query.shape = visual.shape
		elif visual is Area2D:
			# Area2D doesn't have a single 'shape' property, we'd need to iterate children
			# For now, let's assume visual has a shape or is a shape. 
			# The original code handled "shape in visual".
			for child in visual.get_children():
				if child is CollisionShape2D:
					query.shape = child.shape
					break
		elif "shape" in visual:
			query.shape = visual.shape
		
		if not query.shape:
			return

		query.transform = visual.global_transform
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = [owner_node.get_rid()]
		
		var result = space_state.intersect_shape(query)
		for data in result:
			var collider = data["collider"]
			
			if collider in _hit_targets:
				continue
				
			var valid_hit = false
			
			if owner_node.is_in_group("Player"):
				if collider.is_in_group("Enemy"):
					valid_hit = true
			elif owner_node.is_in_group("Enemy"):
				if collider.is_in_group("Player"):
					valid_hit = true
					
			if valid_hit:
				_apply_hit(collider)
				_hit_targets.append(collider)
				hit.emit(collider)

	func _apply_hit(target: Node2D) -> void:
		if target.has_method("take_damage"):
			target.take_damage(damage, owner_node.global_position, owner_node)
			
		KnockbackService.apply_knockback(owner_node, target, knockback_force)
		
		if shake_amount > 0:
			CameraService.shake(shake_amount)
