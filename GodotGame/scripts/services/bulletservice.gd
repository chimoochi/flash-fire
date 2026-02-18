class_name BulletService
extends Node

const BULLET_SCENE = preload("res://player/bullet.tscn")

static func spawn_bullet(caller: Node2D, direction: Vector2, damage: int, speed: float = 1500.0) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = direction
	bullet.speed = speed
	bullet.damage = damage
	bullet.owner_node = caller
	
	caller.get_tree().root.add_child(bullet)
	
	bullet.global_position = caller.global_position
	bullet.rotation = direction.angle()

static func spawn_shotgun(caller: Node2D, direction: Vector2, damage: int, speed: float = 1500.0, spread_angle_deg: float = 45.0) -> void:
	var bullet_count = 5
	var angle_step = deg_to_rad(spread_angle_deg) / (bullet_count - 1)
	var start_angle = -deg_to_rad(spread_angle_deg) / 2.0
	
	for i in range(bullet_count):
		var angle = start_angle + (i * angle_step)
		var new_direction = direction.rotated(angle)
		spawn_bullet(caller, new_direction, damage, speed)
