extends StaticBody2D

@export var explosion_radius: float = 150.0
@export var explosion_damage: int = 50
@export var push_force: float = 2000.0

var _exploded: bool = false

func _ready() -> void:
	add_to_group("ExplosiveBarrel")
	add_to_group("Enemy")

func take_damage(_amount: int, _source_pos: Vector2 = Vector2.ZERO, _source: Node2D = null) -> void:
	if _exploded:
		return
	_exploded = true
	_explode()
	

func _explode() -> void:
	var pos = global_position

	var dummy = StaticBody2D.new()
	dummy.global_position = pos
	get_tree().root.add_child(dummy)

	ThrowableService.explode(explosion_radius, pos, explosion_damage, push_force, dummy)

	dummy.queue_free()
	queue_free()
