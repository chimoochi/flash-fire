extends Area2D

@export var player_damage_per_tick: int = 5
@export var enemy_damage_per_tick: int = 3
@export var tick_interval: float = 0.3
@export var speed_multiplier: float = 0.2
@export var player_entry_damage: int = 8
@export var enemy_entry_damage: int = 2

var _affected: Dictionary = {}
var _tick_timer: Dictionary = {}

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
			"max_speed": body.MAX_SPEED,
			"accel": body.ACCELERATION if "ACCELERATION" in body else 0.0
		}
		body.MAX_SPEED = _affected[id]["max_speed"] * speed_multiplier
		if "ACCELERATION" in body:
			body.ACCELERATION = _affected[id]["accel"] * speed_multiplier
		var capped = body.MAX_SPEED
		if body.velocity.length() > capped:
			body.velocity = body.velocity.normalized() * capped
		_tick_timer[id] = 0.0
		body.take_damage(player_entry_damage, global_position)
	elif body.is_in_group("Enemy") and body.get("move_speed") != null:
		_affected[id] = { "body": body, "move_speed": body.move_speed }
		body.move_speed = _affected[id]["move_speed"] * speed_multiplier
		_tick_timer[id] = 0.0
		if body.has_method("take_damage"):
			body.take_damage(enemy_entry_damage, global_position)

func _on_body_exited(body: Node2D) -> void:
	_restore(body.get_instance_id())

func _restore(id: int) -> void:
	if not _affected.has(id):
		return
	var body = _affected[id]["body"]
	if is_instance_valid(body):
		if body.is_in_group("Player"):
			body.MAX_SPEED = _affected[id]["max_speed"]
			if _affected[id].get("accel", 0.0) > 0:
				body.ACCELERATION = _affected[id]["accel"]
		elif body.get("move_speed") != null:
			body.move_speed = _affected[id]["move_speed"]
	_affected.erase(id)
	_tick_timer.erase(id)

func _restore_all() -> void:
	for id in _affected.keys():
		_restore(id)

func _process(delta: float) -> void:
	for id in _affected.keys():
		var body = _affected[id]["body"]
		if not is_instance_valid(body):
			_affected.erase(id)
			_tick_timer.erase(id)
			continue
		if body.is_in_group("Player"):
			var capped = body.MAX_SPEED
			if body.velocity.length() > capped:
				body.velocity = body.velocity.normalized() * capped
		if body.velocity.length() > 10.0:
			_tick_timer[id] += delta
			if _tick_timer[id] >= tick_interval:
				_tick_timer[id] -= tick_interval
				var dmg = player_damage_per_tick if body.is_in_group("Player") else enemy_damage_per_tick
				body.take_damage(dmg, global_position)
		else:
			_tick_timer[id] = 0.0
