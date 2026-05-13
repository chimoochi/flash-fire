extends Area2D

const CannonBall = preload("res://levels/cannonball.tscn")

var speed := 450.0
var fire_timer := 1.5
var fire_interval := 3.5

func _process(delta: float) -> void:
	position.y += speed * delta
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_interval
		_fire_cannonball()
	if position.y > 1200.0:
		queue_free()

func _fire_cannonball() -> void:
	var ball = CannonBall.instantiate()
	get_parent().add_child(ball)
	ball.global_position = Vector2(global_position.x, -50.0)
