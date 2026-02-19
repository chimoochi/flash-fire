extends Node
class_name SwingMelee # makes it global variable, so leik other scripts can acess. similar to _G. or getgenv()

signal attack_finished

var pivot: Node2D
var visual: Node2D
var owner_node: Node2D
var is_player: bool = false

var is_swinging: bool = false
var hit_targets: Array = []

var default_rotation: float = 0.0
var default_vis_pos: Vector2 = Vector2.ZERO

var current_damage: int = 0
var current_knockback: float = 0.0

func swing(caller: Node2D, damage: int, knockback: float, duration: float) -> void:
	if is_swinging: return
	
	owner_node = caller
	current_damage = damage
	current_knockback = knockback
	
	is_player = owner_node.is_in_group("Player")
	pivot = owner_node.get_node("MeleePivot")
	visual = pivot.get_node("MeleeHitBox")
	
	default_rotation = pivot.rotation
	default_vis_pos = visual.position
	
	is_swinging = true
	hit_targets.clear()
	
	var start_angle = deg_to_rad(45)
	var end_angle = deg_to_rad(-45)
	var start_dist = 10.0
	var peak_dist = 50.0
	

	pivot.rotation = start_angle
	visual.position.x = start_dist
	visual.visible = true
	
	var tween = create_tween()
	tween.tween_property(visual, "position:x", peak_dist, duration * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "rotation", end_angle, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	var return_tween = create_tween()
	return_tween.set_parallel(true)
	return_tween.tween_property(pivot, "rotation", default_rotation, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return_tween.tween_property(visual, "position:x", default_vis_pos.x, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	await return_tween.finished
	
	
	visual.visible = true
	
	await get_tree().create_timer(0.1).timeout
	is_swinging = false
	attack_finished.emit()

func _physics_process(_delta: float) -> void:
	if is_swinging:
		_check_hit()

func _check_hit() -> void:
	var space_state = owner_node.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	
	if visual is CollisionShape2D:
		query.shape = visual.shape
	else:
		if "shape" in visual:
			query.shape = visual.shape
		else:
			return

	query.transform = visual.global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [owner_node.get_rid()]
	
	var result = space_state.intersect_shape(query)
	for data in result:
		var collider = data["collider"]
		
		if hit_targets.has(collider):
			continue
			
		if is_player:
			if collider.is_in_group("Enemy") and collider.has_method("take_damage"):
				collider.take_damage(current_damage, owner_node.global_position)
				KnockbackService.apply_knockback(owner_node, collider, current_knockback)
				hit_targets.append(collider)
				CameraService.shake(0.1)
		else:
			if collider.is_in_group("Player"):
				if collider.has_method("take_damage"):
					collider.take_damage(current_damage, owner_node.global_position)
				KnockbackService.apply_knockback(owner_node, collider, current_knockback)
				hit_targets.append(collider)
				CameraService.shake(0.1)
	
func chargedattack(charge_duration, begincharge, endcharge):
	pass
