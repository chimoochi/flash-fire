class_name CameraUtils


#random math/cam utils lib from the open web

static func get_shake_offset(trauma: float, intensity: float = 15.0) -> Vector2:
	if trauma <= 0:
		return Vector2.ZERO
		
	var amount = pow(trauma, 2)
	return Vector2(
		randf_range(-1.0, 1.0) * intensity * amount,
		randf_range(-1.0, 1.0) * intensity * amount
	)

static func apply_zoom_kick(camera: Camera2D, kick_amount: Vector2, recovery_speed: float = 0.1) -> void:
	if camera:
		var tween = camera.get_tree().create_tween()
		var original_zoom = camera.zoom
		camera.zoom += kick_amount
		tween.tween_property(camera, "zoom", original_zoom, recovery_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func smooth_zoom(camera: Camera2D, target_zoom: Vector2, delta: float, weight: float = 5.0) -> void:
	if camera:
		camera.zoom = camera.zoom.lerp(target_zoom, weight * delta)

static func fov_to_zoom(fov_value: float) -> Vector2:
	var zoom_factor = 90.0 / clamp(fov_value, 10.0, 150.0)
	return Vector2(zoom_factor, zoom_factor)
