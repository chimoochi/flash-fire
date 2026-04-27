extends Node


var trauma: float = 0.0
var target_zoom: Vector2 = Vector2(2.0, 2.0)
var current_camera: Camera2D

var decay: float = 1.5
var shake_intensity: float = 20.0

func _process(delta: float) -> void:
	if trauma > 0:
		trauma = clamp(trauma - delta * decay, 0.0, 1.0)
	
	if not current_camera:
		current_camera = get_viewport().get_camera_2d()
	
	if current_camera:
		if trauma > 0:
			current_camera.offset = CameraUtils.get_shake_offset(trauma, shake_intensity)
		else:
			current_camera.offset = Vector2.ZERO
		
		CameraUtils.smooth_zoom(current_camera, target_zoom, delta, 8.0)

func shake(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)
func kick(amount: Vector2, recovery: float = 0.15) -> void:
	if current_camera:
		CameraUtils.apply_zoom_kick(current_camera, amount, recovery)
func set_zoom(fov: float) -> void:
	target_zoom = CameraUtils.fov_to_zoom(fov)
