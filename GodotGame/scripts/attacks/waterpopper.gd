extends Node
class_name WaterPopper

signal attack_finished

var is_swinging: bool = false
var _swing_instance: Node = null

func swing(caller: Node2D, damage: int, knockback: float, duration: float) -> void:
	if is_swinging: return
	
	is_swinging = true
	
	var pivot = caller.get_node("MeleePivot")
	var visual = pivot.get_node("MeleeHitBox")
	
	# Use the generic service for the swing motion and melee hit detection
	_swing_instance = SwingMeleeService.swing(
		caller,
		pivot,
		visual,
		damage,
		knockback,
		duration,
		90.0, # angle range (approx 45 to -45 degrees)
		10.0, # start dist
		50.0, # peak dist
		0.1   # shake amount
	)
	
	# Spawn the specific projectile for this weapon
	_spawn_projectile(caller, damage, knockback)
	
	if _swing_instance:
		await _swing_instance.finished
		_swing_instance = null
	
	# Small cooldown or cleanup buffer as in original script
	await get_tree().create_timer(0.1).timeout
	
	is_swinging = false
	attack_finished.emit()

func _spawn_projectile(caller: Node2D, damage: int, knockback: float) -> void:
	var projectile = WaterSlashProjectile.new()
	projectile.owner_node = caller
	projectile.damage = damage
	projectile.push_force = knockback
	
	var facing_dir = Vector2.RIGHT.rotated(caller.rotation)
	projectile.direction = facing_dir
	projectile.global_position = caller.global_position + (facing_dir * 20.0)
	projectile.rotation = caller.rotation
	
	caller.get_tree().root.add_child(projectile)

class WaterSlashProjectile extends Area2D:
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
		visual.color = Color(0.4, 0.6, 1.0, 0.6) # Water-like color
		visual.polygon = PackedVector2Array([
			Vector2(20, 0), Vector2(10, -30), Vector2(-10, -30),
			Vector2(-20, 0), Vector2(-10, 30), Vector2(10, 30)
		])
		add_child(visual)
		
		collision_layer = 0
		collision_mask = 6 # Player(2) + Enemy(4) usually
		
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
			
			# Use KnockbackService like original
			if is_instance_valid(owner_node) and is_instance_valid(body):
				KnockbackService.apply_knockback(owner_node, body, push_force)
			elif body.has_method("push"):
				body.push(direction * push_force)
