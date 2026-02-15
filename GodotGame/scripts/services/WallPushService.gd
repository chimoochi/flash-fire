class_name WallPushService

const WALL_PUSH_SCENE = preload("res://abilities/wall_push.tscn")

static func spawn_wall(caller: Node2D, direction: Vector2, offset: float = 40.0) -> void:
	var wall = WALL_PUSH_SCENE.instantiate()
	
	# Add to root to be independent of caller
	caller.get_tree().root.add_child(wall)
	
	wall.rotation = direction.angle()
	wall.global_position = caller.global_position + (direction * offset)
	
	# If we want to pass specific params to the wall instance, we can do it here
	# e.g. wall.setup(...) if we add a setup method
