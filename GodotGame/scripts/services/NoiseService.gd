class_name NoiseService
extends Object


static func emit_noise(tree: SceneTree, position: Vector2, range_distance: float) -> void:
	#TODO: EMIT NOISES HERE
	tree.call_group("Enemy", "hear_noise", position, range_distance)
