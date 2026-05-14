extends Area2D

const BURN_DAMAGE := 15
const BURN_INTERVAL := 0.5
const RADIUS := 60.0

var source_node: Node2D
var _victims: Dictionary = {}

func _ready() -> void:
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = RADIUS
	collision_shape.shape = circle_shape
	add_child(collision_shape)

	collision_layer = 0


	if is_instance_valid(source_node) and source_node.is_in_group("Enemy"):
		collision_mask = 2 # Hit Player layer only
	else:
		collision_mask = 4 # Hit Enemy layer only

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.5, 0.0, 0.3))

func _is_valid_target(body: Node2D) -> bool:
	if not is_instance_valid(body):
		return false
	if body == source_node:
		return false
		
	if is_instance_valid(source_node):
		if source_node.is_in_group("Enemy") and body.is_in_group("Enemy"):
			return false
		if source_node.is_in_group("Player") and body.is_in_group("Player"):
			return false
	return body.has_method("take_damage")

func _physics_process(_delta: float) -> void:
	var now = Time.get_ticks_msec()

	var to_remove = []

	for id in _victims.keys():
		var data = _victims[id]
		var victim = data.body
		if not is_instance_valid(victim):
			to_remove.append(id)
			continue

		var next_tick = data.next_tick
		if now >= next_tick:
			var damage_pos = source_node.global_position if is_instance_valid(source_node) else global_position
			victim.take_damage(BURN_DAMAGE, damage_pos, source_node if is_instance_valid(source_node) else null)
			data.next_tick = now + int(BURN_INTERVAL * 1000)

	for invalid in to_remove:
		_victims.erase(invalid)

func _on_body_entered(body: Node2D) -> void:
	if not _is_valid_target(body):
		return

	var now = Time.get_ticks_msec()
	var damage_pos = source_node.global_position if is_instance_valid(source_node) else global_position
	body.take_damage(BURN_DAMAGE, damage_pos, source_node if is_instance_valid(source_node) else null)
	_victims[body.get_instance_id()] = { "body": body, "next_tick": now + int(BURN_INTERVAL * 1000) }

func _on_body_exited(body: Node2D) -> void:
	var id = body.get_instance_id()
	if _victims.has(id):
		_victims.erase(id)
