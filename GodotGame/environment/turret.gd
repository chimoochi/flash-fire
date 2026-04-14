extends StaticBody2D

@export var fire_interval: float = 2.0
@export var arrow_speed: float = 500.0
@export var arrow_distance: float = 600.0
@export var arrow_damage: int = 15

var _arrow_scene: PackedScene = preload("res://environment/turret_arrow.tscn")
var _timer: float = 0.0

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= fire_interval:
		_timer -= fire_interval
		_shoot()

func _shoot() -> void:
	var arrow = _arrow_scene.instantiate()
	arrow.direction = Vector2.RIGHT.rotated(rotation)
	arrow.speed = arrow_speed
	arrow.max_distance = arrow_distance
	arrow.damage = arrow_damage
	arrow.global_position = global_position + arrow.direction * 20.0
	arrow.rotation = rotation
	get_tree().current_scene.add_child(arrow)
