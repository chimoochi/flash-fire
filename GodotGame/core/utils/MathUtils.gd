class_name MathUtils


static func saturate(value: float) -> float:
	return clamp(value, 0.0, 1.0)

static func remap(value: float, istart: float, istop: float, ostart: float, ostop: float) -> float:
	return ostart + (ostop - ostart) * ((value - istart) / (istop - istart))

static func random_choice(array: Array):
	if array.is_empty():
		return null
	return array[randi() % array.size()]

static func chance(probability: float) -> bool:
	return randf() < probability

static func damp(current: float, target: float, lambda: float, delta: float) -> float:
	return lerp(current, target, 1.0 - exp(-lambda * delta))

static func damp_vec2(current: Vector2, target: Vector2, lambda: float, delta: float) -> Vector2:
	return current.lerp(target, 1.0 - exp(-lambda * delta))
