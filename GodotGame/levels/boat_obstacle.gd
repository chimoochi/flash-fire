extends Area2D

var speed := 450.0

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > 1200.0:
		queue_free()
