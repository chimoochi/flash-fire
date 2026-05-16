extends Area2D

@export var accel_multiplier: float = 0.1
@export var friction_multiplier: float = 0.05

var _affected: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	tree_exiting.connect(_restore_all)

func _on_body_entered(body: Node2D) -> void:
	var id = body.get_instance_id()
	if _affected.has(id):
		return
	if body.is_in_group("Player"):
		_affected[id] = {
			"body": body,
			"accel": body.ACCELERATION,
			"friction": body.FRICTION,
		}
		body.ACCELERATION *= accel_multiplier
		body.FRICTION *= friction_multiplier
	elif body.is_in_group("Enemy") and body.get("turn_speed") != null:
		_affected[id] = {
			"body": body,
			"turn_speed": body.turn_speed,
			"move_speed": body.move_speed,
		}
		body.turn_speed *= 0.15
		body.move_speed *= 0.6

func _on_body_exited(body: Node2D) -> void:
	_restore(body.get_instance_id())

func _restore(id: int) -> void:
	if not _affected.has(id):
		return
	var body = _affected[id]["body"]
	if is_instance_valid(body):
		if body.is_in_group("Player"):
			body.ACCELERATION = _affected[id]["accel"]
			body.FRICTION = _affected[id]["friction"]
		elif body.is_in_group("Enemy"):
			body.turn_speed = _affected[id]["turn_speed"]
			body.move_speed = _affected[id]["move_speed"]
	_affected.erase(id)

func _restore_all() -> void:
	for id in _affected.keys():
		_restore(id)
