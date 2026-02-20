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
	

	pivot.visible = true
	pivot.rotation = start_angle
	visual.position.x = start_dist
	visual.visible = true
	
	var wind = WindSlashProjectile.new()
	wind.owner_node = owner_node
	wind.damage = current_damage
	wind.push_force = current_knockback
	
	var facing_dir = Vector2.RIGHT.rotated(owner_node.rotation)
	wind.direction = facing_dir
	wind.global_position = owner_node.global_position + (facing_dir * 20.0)
	wind.rotation = owner_node.rotation
	
	owner_node.get_tree().root.add_child(wind)
	
	var tween = create_tween()
	tween.tween_property(visual, "position:x", peak_dist, duration * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "rotation", end_angle, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	var return_tween = create_tween()
	return_tween.set_parallel(true)
	return_tween.tween_property(pivot, "rotation", default_rotation, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return_tween.tween_property(visual, "position:x", default_vis_pos.x, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	await return_tween.finished
	
	
	visual.visible = false
	pivot.visible = false
	
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
				collider.take_damage(current_damage, owner_node.global_position, owner_node if is_instance_valid(owner_node) else null)
				KnockbackService.apply_knockback(owner_node, collider, current_knockback)
				hit_targets.append(collider)
				CameraService.shake(0.1)
		else:
			if collider.is_in_group("Player"):
				if collider.has_method("take_damage"):
					collider.take_damage(current_damage, owner_node.global_position, owner_node if is_instance_valid(owner_node) else null)
				KnockbackService.apply_knockback(owner_node, collider, current_knockback)
				hit_targets.append(collider)
				CameraService.shake(0.1)
	
func chargedattack(charge_duration, begincharge, endcharge):
	pass

class WindSlashProjectile extends Area2D:
	var speed := 600.0
	var lifetime := 0.6
	var direction := Vector2.RIGHT
	var damage := 10
	var push_force := 500.0
	var owner_node: Node2D = null

	var hit_targets: Array = []
	var _timer := 0.0

	func _ready() -> void:
		var shape = RectangleShape2D.new()
		shape.size = Vector2(40, 60)
		var collision = CollisionShape2D.new()
		collision.shape = shape
		add_child(collision)
		
		var visual = Polygon2D.new()
		visual.color = Color(1.0, 1.0, 1.0, 0.4)
		visual.polygon = PackedVector2Array([
			Vector2(20, 0), Vector2(10, -30), Vector2(-10, -30),
			Vector2(-20, 0), Vector2(-10, 30), Vector2(10, 30)
		])
		add_child(visual)
		
		collision_layer = 0
		collision_mask = 6
		
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_SINE)

	func _physics_process(delta: float) -> void:
		_timer += delta
		if _timer >= lifetime:
			queue_free()
			return
			
		position += direction * speed * delta
		
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body == self or body == owner_node: continue
			if hit_targets.has(body): continue
			
			if is_instance_valid(owner_node):
				if owner_node.is_in_group("Player") and body.is_in_group("Player"): continue
				if owner_node.is_in_group("Enemy") and body.is_in_group("Enemy"): continue
			
			hit_targets.append(body)
			if body.has_method("take_damage"):
				body.take_damage(damage, global_position, owner_node if is_instance_valid(owner_node) else null)
			if body.has_method("push"):
				body.push(direction * push_force)
			elif owner_node and owner_node is Node2D and body is Node2D:
				KnockbackService.apply_knockback(owner_node, body, push_force)
