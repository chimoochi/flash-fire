extends Area2D

const FireStatus = preload("res://combat/status_effects/fire_status.gd")
const OIL_TEXTURE = preload("res://gameassets/runtime/sprites/oil puddle.png")
const OIL_FIRE_TEXTURE = preload("res://gameassets/runtime/sprites/oil fire.png")

@export var lit: bool = false
@export var lit_lifetime: float = 5.0
@export var damage_per_tick: int = 4
@export var tick_interval: float = 0.2
@export var speed_multiplier: float = 0.55
@export var burn_duration: float = 5.0

var _affected: Dictionary = {}
var _tick_timer: Dictionary = {}
var _life_timer := 0.0
@onready var _sprite: Sprite2D = $Sprite2D
var _fade_started := false

func _ready() -> void:
	add_to_group("OilPuddle")
	collision_layer = 0
	collision_mask = 6

	if _sprite:
		_sprite.texture = OIL_FIRE_TEXTURE if lit else OIL_TEXTURE

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	tree_exiting.connect(_restore_all)

	if lit:
		_life_timer = lit_lifetime

func _process(delta: float) -> void:
	for id in _affected.keys():
		var body: Node2D = _affected[id]["body"]
		if not is_instance_valid(body):
			_affected.erase(id)
			_tick_timer.erase(id)
			continue
		if lit:
			_tick_timer[id] += delta
			if _tick_timer[id] >= tick_interval:
				_tick_timer[id] -= tick_interval
				if body.has_method("take_damage"):
					body.take_damage(damage_per_tick, global_position)
				_ignite_body(body)

	if not lit:
		return

	_life_timer -= delta
	if _life_timer <= 0.0 and not _fade_started:
		_fade_started = true
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.65)
		tween.finished.connect(queue_free)

func ignite() -> void:
	if lit:
		return
	lit = true
	_life_timer = lit_lifetime
	if _sprite:
		_sprite.texture = OIL_FIRE_TEXTURE
	for data in _affected.values():
		var body: Node2D = data["body"]
		if is_instance_valid(body):
			_ignite_body(body)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player") and not body.is_in_group("Enemy"):
		return
	var id := body.get_instance_id()
	if _affected.has(id):
		return
	_affected[id] = _make_slow_data(body)
	_tick_timer[id] = 0.0
	_apply_slow(body, _affected[id])
	if lit:
		_ignite_body(body)

func _on_body_exited(body: Node2D) -> void:
	_restore(body.get_instance_id())

func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return
	if area.is_in_group("Projectiles") or area.get("is_player_bullet") == true or "fire" in area.name.to_lower():
		ignite()

func _make_slow_data(body: Node2D) -> Dictionary:
	var data := {"body": body}
	if body.is_in_group("Player") and body.get("MAX_SPEED") != null:
		data["max_speed"] = body.MAX_SPEED
		if body.get("ACCELERATION") != null:
			data["accel"] = body.ACCELERATION
	elif body.get("move_speed") != null:
		data["move_speed"] = body.move_speed
	return data

func _apply_slow(body: Node2D, data: Dictionary) -> void:
	if data.has("max_speed"):
		body.MAX_SPEED = data["max_speed"] * speed_multiplier
		if data.has("accel"):
			body.ACCELERATION = data["accel"] * speed_multiplier
		if body.get("velocity") != null and body.velocity.length() > body.MAX_SPEED:
			body.velocity = body.velocity.normalized() * body.MAX_SPEED
	elif data.has("move_speed"):
		body.move_speed = data["move_speed"] * speed_multiplier

func _restore(id: int) -> void:
	if not _affected.has(id):
		return
	var data: Dictionary = _affected[id]
	var body: Node2D = data["body"]
	if is_instance_valid(body):
		if data.has("max_speed"):
			body.MAX_SPEED = data["max_speed"]
			if data.has("accel"):
				body.ACCELERATION = data["accel"]
		elif data.has("move_speed"):
			body.move_speed = data["move_speed"]
	_affected.erase(id)
	_tick_timer.erase(id)

func _restore_all() -> void:
	for id in _affected.keys():
		_restore(id)

func _ignite_body(body: Node2D) -> void:
	var existing := body.get_node_or_null("FireStatus")
	if existing and existing.has_method("refresh"):
		existing.refresh(burn_duration)
		return
	var status := FireStatus.new()
	status.name = "FireStatus"
	status.duration = burn_duration
	status.source_node = self
	body.add_child(status)
